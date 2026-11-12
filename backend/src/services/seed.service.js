import { currentTerm, nextTerm } from "../utils/academic-calendar.js";
import { majorRepository } from "../repositories/student-affairs.repositories.js";
import { saveDocument } from "../repositories/base.repository.js";
import { transaction } from "../repositories/transaction.js";
import { slotTimes, localDate } from "../utils/slots.js";
import bcrypt from "bcryptjs";
import {
  departmentRepository,
  courseRepository,
  semesterRepository,
  userRepository,
  roomRepository,
  sectionRepository,
  classMembershipRepository,
  classSessionRepository,
} from "../repositories/index.js";
export async function seed({ now = new Date() } = {}) {
  const password = process.env.SEED_PASSWORD;
  if (!password || password.length < 12 || Buffer.byteLength(password) > 72)
    throw new Error("SEED_PASSWORD cần >=12 ký tự và <=72 byte");
  const password_hash = await bcrypt.hash(password, 12);
  return transaction(async (session) => {
    if (await userRepository.exists({}, { session: session }))
      throw new Error(
        "Seed chỉ chạy khi chưa có người dùng; không xóa dữ liệu",
      );
    const [department] = await departmentRepository.create(
      [{ code: "SE", name: "Kỹ thuật phần mềm" }],
      { session, ordered: true },
    );
    const users = {};
    for (const role of ["STUDENT", "LECTURER", "HEAD", "STAFF"]) {
      const [row] = await userRepository.create(
        [
          {
            user_code: `DEMO-${role}`,
            name: `Demo ${role}`,
            email: `${role.toLowerCase()}@myfap.local`,
            password_hash,
            role,
            department_id: department._id,
          },
        ],
        { session, ordered: true },
      );
      users[role] = row;
    }
    const [course] = await courseRepository.create(
      [
        {
          code: "PRM393",
          name: "Flutter Mobile",
          department_id: department._id,
        },
      ],
      { session, ordered: true },
    );

    const [semester] = await semesterRepository.create(
      [currentTerm(now) ?? nextTerm(now)],
      { session },
    );
    const major = await majorRepository.create(
      {
        code: "SE",
        name: "Kỹ thuật phần mềm",
        department_id: department._id,
        course_ids: [course._id],
      },
      { session },
    );
    users.STUDENT.major_id = major._id;
    await saveDocument(users.STUDENT, { session });
    const [room] = await roomRepository.create(
      [{ name: "BE-301", capacity: 30 }],
      {
        session,
      },
    );
    await roomRepository.create([{ name: "BE-302", capacity: 30 }], {
      session,
      ordered: true,
    });
    const [section] = await sectionRepository.create(
      [
        {
          code: "SE20A-PRM393",
          course_id: course._id,
          semester_id: semester._id,
          department_id: department._id,
          lecturer_id: users.LECTURER._id,
          capacity: 30,
        },
      ],
      { session, ordered: true },
    );
    const membershipStart = new Date(now.getTime() - 7 * 86400000);
    await classMembershipRepository.create(
      {
        section_id: section._id,
        student_id: users.STUDENT._id,
        course_id: course._id,
        semester_id: semester._id,
        starts_at: membershipStart,
      },
      { session },
    );
    const pastDay = new Date(
      Math.max(
        +semester.start_at,
        Math.min(+semester.end_at - 86400000, +now - 86400000),
      ),
    );
    let futureDay = new Date(
      Math.max(
        +semester.start_at,
        Math.min(+semester.end_at - 86400000, +now + 86400000),
      ),
    );
    if (localDate(pastDay) === localDate(futureDay))
      futureDay = new Date(+pastDay + 86400000);
    await classSessionRepository.create(
      [
        {
          section_id: section._id,
          lecturer_id: users.LECTURER._id,
          room_id: room._id,
          ...slotTimes(localDate(pastDay), 1),
          status:
            slotTimes(localDate(pastDay), 1).end_at <= now
              ? "COMPLETED"
              : "SCHEDULED",
        },
        {
          section_id: section._id,
          lecturer_id: users.LECTURER._id,
          room_id: room._id,
          ...slotTimes(localDate(futureDay), 1),
        },
      ],
      { session, ordered: true },
    );
  });
}
