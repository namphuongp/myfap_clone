import bcrypt from "bcryptjs";
import { seed } from "./seed.service.js";
import { seedStudentAffairsDemo } from "./student-affairs-demo.service.js";
import {
  currentTerm,
  nextTerm,
  semesterData,
} from "../utils/academic-calendar.js";
import { localDate, slotTimes } from "../utils/slots.js";
import { same } from "../utils/identity.js";
import { get, saveDocument } from "../repositories/base.repository.js";
import { transaction } from "../repositories/transaction.js";
import { audit } from "./audit.service.js";
import { ensureSlot, recordSession } from "./scheduling.service.js";
import { rosterIds } from "./access.service.js";
import { majorRepository } from "../repositories/major.repository.js";
import {
  userRepository,
  courseRepository,
  semesterRepository,
  sectionRepository,
  roomRepository,
  classMembershipRepository,
  classSessionRepository,
} from "../repositories/index.js";

const students = [
  { user_code: "SE180001", name: "Nguyễn Văn An", email: "an.nv@myfap.local" },
  {
    user_code: "SE180002",
    name: "Trần Thị Bình",
    email: "binh.tt@myfap.local",
  },
  {
    user_code: "SE180003",
    name: "Lê Hoàng Cường",
    email: "cuong.lh@myfap.local",
  },
  {
    user_code: "SE180004",
    name: "Phạm Thu Dung",
    email: "dung.pt@myfap.local",
  },
];

async function demoContext(session) {
  const users = await userRepository.find({}, { session });
  if (!users.length) return null;
  const context = {};
  for (const role of ["STUDENT", "LECTURER", "HEAD", "STAFF"]) {
    const actor = users.find(
      (user) => user.email === `${role.toLowerCase()}@myfap.local`,
    );
    if (
      !actor ||
      actor.role !== role ||
      actor.name !== `Demo ${role}` ||
      !actor.active
    )
      throw new Error(
        "Seed tổng chỉ dùng cho DB trống hoặc tài khoản demo gốc; không thay đổi dữ liệu thật",
      );
    context[role] = actor;
  }
  for (const user of users) {
    if (Object.values(context).some((actor) => same(actor._id, user._id)))
      continue;
    const expected = students.find((row) => row.email === user.email);
    if (
      !expected ||
      user.role !== "STUDENT" ||
      user.name !== expected.name ||
      user.user_code !== expected.user_code
    )
      throw new Error(
        "DB có tài khoản ngoài bộ demo; seed đã dừng để bảo vệ dữ liệu hiện tại",
      );
  }
  return context;
}

async function ensureCalendar(session, now) {
  const year = Number(localDate(now).slice(0, 4));
  for (const y of [year - 1, year, year + 1]) {
    for (const term of ["SPRING", "SUMMER", "FALL"]) {
      const fields = semesterData(term, y);
      const row = await semesterRepository.findOne(
        { code: fields.code },
        { session },
      );
      if (!row) await semesterRepository.create(fields, { session });
      else if (
        +row.start_at !== +fields.start_at ||
        +row.end_at !== +fields.end_at ||
        row.legacy
      )
        throw new Error(
          `Học kỳ ${fields.code} không khớp lịch chuẩn; seed không tự sửa lịch cũ`,
        );
    }
  }
  return semesterRepository.findOne(
    { code: (currentTerm(now) ?? nextTerm(now)).code },
    { session },
  );
}

async function ensureCourse(session, context, code, name) {
  let row = await courseRepository.findOne({ code }, { session });
  // Dữ liệu import có thể dùng mã LEGACY; giữ ID/mã cũ khi tên và bộ môn trùng.
  if (!row)
    row = await courseRepository.findOne(
      { department_id: context.LECTURER.department_id, name },
      { session },
    );
  if (!row)
    row = await courseRepository.create(
      { code, name, department_id: context.LECTURER.department_id },
      { session },
    );
  if (
    !same(row.department_id, context.LECTURER.department_id) ||
    row.active === false
  )
    throw new Error(
      `Môn ${code} khác bộ môn hoặc đã ngừng hoạt động; seed không ghi đè`,
    );
  return row;
}

async function ensureMembership(session, student, section, startsAt) {
  const existing = await classMembershipRepository.findOne(
    { section_id: section._id, student_id: student._id },
    { session },
  );
  if (existing) return;
  if (
    await classMembershipRepository.exists(
      {
        student_id: student._id,
        course_id: section.course_id,
        semester_id: section.semester_id,
        ends_at: null,
      },
      { session },
    )
  )
    return;
  if (
    (await classMembershipRepository.countDocuments(
      { section_id: section._id, ends_at: null },
      { session },
    )) >= 30
  )
    throw new Error(`Lớp ${section.code} đã đủ 30 sinh viên`);
  await classMembershipRepository.create(
    {
      section_id: section._id,
      student_id: student._id,
      course_id: section.course_id,
      semester_id: section.semester_id,
      starts_at: startsAt,
      ends_at: null,
    },
    { session },
  );
}

async function ensureLesson(
  session,
  context,
  section,
  room,
  date,
  slot,
  now,
  fresh,
) {
  const existing = await classSessionRepository.findOne(
    { section_id: section._id, session_date: date, slot_id: slot },
    { session },
  );
  if (existing) {
    // Chỉ điền điểm danh mẫu của DB vừa tạo, không sửa buổi hoặc roster đã tồn tại trước seed.
    if (
      fresh &&
      date < localDate(now) &&
      !existing.attendance_saved &&
      !existing.attendance.length
    ) {
      existing.attendance = (await rosterIds(existing, session)).map(
        (student_id, index) => ({
          student_id,
          status: index % 4 === 3 ? "ABSENT" : "PRESENT",
          updated_by: context.LECTURER._id,
          updated_at: now,
        }),
      );
      existing.attendance_saved = true;
      await saveDocument(existing, { session });
    }
    return false;
  }
  const timing = slotTimes(date, slot);
  await ensureSlot(
    session,
    section,
    room._id,
    timing.start_at,
    timing.end_at,
    undefined,
    context.LECTURER._id,
  );
  const row = classSessionRepository.instantiate({
    ...timing,
    section_id: section._id,
    lecturer_id: context.LECTURER._id,
    room_id: room._id,
    status: timing.end_at <= now ? "COMPLETED" : "SCHEDULED",
  });
  if (date < localDate(now)) {
    row.attendance = (await rosterIds(row, session)).map(
      (student_id, index) => ({
        student_id,
        status: index % 4 === 3 ? "ABSENT" : "PRESENT",
        updated_by: context.LECTURER._id,
        updated_at: now,
      }),
    );
    row.attendance_saved = true;
  }
  await saveDocument(row, { session });
  await recordSession(session, context.STAFF, "SEED_DEMO_SESSION", null, row);
  return true;
}

async function seedTeachingDemo({ now, fresh, passwordHash }) {
  return transaction(async (session) => {
    const context = await demoContext(session);
    const semester = await ensureCalendar(session, now);
    const major = await get(majorRepository, context.STUDENT.major_id, session);
    if (
      !same(major.department_id, context.STUDENT.department_id) ||
      !major.active
    )
      throw new Error("Ngành của sinh viên demo không hợp lệ");
    const courseSpecs = [
      { code: "PRM393", name: "Flutter Mobile" },
      { code: "DBI202", name: "Cơ sở dữ liệu" },
    ];
    const courses = [];
    for (const spec of courseSpecs)
      courses.push(await ensureCourse(session, context, spec.code, spec.name));
    // Chỉ bổ sung chương trình demo đã biết, không thay thế ngành hoặc bỏ môn hiện có.
    const missingCourses = courses.filter(
      (course) => !major.course_ids.some((key) => same(key, course._id)),
    );
    if (missingCourses.length) {
      if (!["SE", "SE-DEMO"].includes(major.code))
        throw new Error(
          "Ngành hiện tại ngoài chương trình demo; không tự sửa chương trình",
        );
      major.course_ids.push(...missingCourses.map((course) => course._id));
      await saveDocument(major, { session });
    }
    const classStudents = [context.STUDENT];
    for (const fields of students) {
      let student = await userRepository.findOne(
        { email: fields.email },
        { session },
      );
      if (!student)
        student = await userRepository.create(
          {
            ...fields,
            password_hash: passwordHash,
            role: "STUDENT",
            department_id: context.STUDENT.department_id,
            major_id: major._id,
          },
          { session },
        );
      if (
        !same(student.department_id, context.STUDENT.department_id) ||
        !same(student.major_id, major._id) ||
        !student.active
      )
        throw new Error(
          `Sinh viên demo ${fields.user_code} đã thay đổi; seed không ghi đè`,
        );
      classStudents.push(student);
    }
    const rooms = [];
    for (const name of ["BE-301", "BE-302"]) {
      let room = await roomRepository.findOne({ name }, { session });
      if (!room)
        room = await roomRepository.create({ name, capacity: 30 }, { session });
      if (room.capacity < 30) throw new Error(`Phòng ${name} không đủ 30 chỗ`);
      rooms.push(room);
    }
    const anchor = currentTerm(now)
      ? new Date(`${localDate(now)}T00:00:00+07:00`)
      : new Date(semester.start_at);
    const dates = [
      ...new Set(
        [-1, 0, 1, 7]
          .map((offset) => new Date(+anchor + offset * 86400000))
          .filter((date) => date >= semester.start_at && date < semester.end_at)
          .map(localDate),
      ),
    ];
    const startsAt = fresh ? new Date(+anchor - 14 * 86400000) : now;
    let sessionsCreated = 0;
    const result = [];
    for (let index = 0; index < courses.length; index++) {
      const course = courses[index],
        // Mã lớp demo ổn định, không phụ thuộc mã môn import LEGACY.
        code = `SE20A-${courseSpecs[index].code}`;
      let section = await sectionRepository.findOne(
        { semester_id: semester._id, code },
        { session },
      );
      const created = !section;
      if (!section)
        section = await sectionRepository.create(
          {
            code,
            course_id: course._id,
            semester_id: semester._id,
            department_id: course.department_id,
            capacity: 30,
            status: "CLOSED",
          },
          { session },
        );
      if (
        !same(section.course_id, course._id) ||
        !same(section.department_id, course.department_id)
      )
        throw new Error(`Lớp ${code} đã được sử dụng cho môn/bộ môn khác`);
      for (const student of classStudents)
        await ensureMembership(session, student, section, startsAt);
      for (const date of dates)
        if (
          await ensureLesson(
            session,
            context,
            section,
            rooms[index],
            date,
            index + 1,
            now,
            fresh,
          )
        )
          sessionsCreated++;
      if (created) {
        section.status = "OPEN";
        await saveDocument(section, { session });
      }
      result.push({
        code,
        active_students: await classMembershipRepository.countDocuments(
          { section_id: section._id, ends_at: null },
          { session },
        ),
      });
    }
    await audit(
      session,
      context.STAFF,
      "SEED_DEMO_DATA",
      "User",
      context.STUDENT._id,
      null,
      { semester: semester.code, sessions_created: sessionsCreated },
    );
    return {
      semester: semester.code,
      students: classStudents.length,
      sections: result,
      sessions_created: sessionsCreated,
      in_term_break: !currentTerm(now),
    };
  });
}

export async function seedAllDemo({ now = new Date() } = {}) {
  if (!(now instanceof Date) || Number.isNaN(+now))
    throw new Error("Ngày seed không hợp lệ");
  const password = process.env.SEED_PASSWORD;
  if (
    !password ||
    password.length < 12 ||
    Buffer.byteLength(password, "utf8") > 72
  )
    throw new Error("SEED_PASSWORD cần >=12 ký tự và <=72 byte");
  const context = await demoContext();
  if (
    context &&
    Object.values(context).some(
      (user) => !same(user.department_id, context.STUDENT.department_id),
    )
  )
    throw new Error("Tài khoản demo khác bộ môn; seed không thay đổi dữ liệu");
  const fresh = !context;
  if (fresh) await seed({ now });
  await seedStudentAffairsDemo();
  const result = await seedTeachingDemo({
    now,
    fresh,
    passwordHash: await bcrypt.hash(password, 12),
  });
  return {
    ...result,
    initialized: fresh,
    note: "Giữ mật khẩu, các khoảng thuộc lớp đã kết thúc, lịch và điểm danh cũ. Ngoài học kỳ, tạo lịch cho kỳ kế tiếp.",
  };
}
