import {
  User,
  Semester,
  Room,
  Section,
  Enrollment,
  EnrollmentPeriod,
  ClassSession,
  Leave,
  Change,
  SessionHistory,
} from "./models.js";
import {
  fail,
  get,
  same,
  clean,
  checkVersion,
  audit,
  authorizeSection,
} from "./core.js";
import { slotTimes } from "./slots.js";
export const sessionSnapshot = (s) =>
  clean({
    room_id: s.room_id,
    session_date: s.session_date,
    slot_id: s.slot_id,
    start_at: s.start_at,
    end_at: s.end_at,
    status: s.status,
    version: s.version,
  });
export async function recordSession(
  session,
  user,
  action,
  before,
  after,
  requestId = null,
) {
  await SessionHistory.create(
    [
      {
        session_id: after._id,
        actor_id: user._id,
        request_id: requestId,
        action,
        before_data: before ? sessionSnapshot(before) : null,
        after_data: sessionSnapshot(after),
      },
    ],
    { session },
  );
  await audit(
    session,
    user,
    action,
    "ClassSession",
    after._id,
    before ? sessionSnapshot(before) : null,
    sessionSnapshot(after),
  );
}
export async function rosterIds(lesson, session) {
  return EnrollmentPeriod.distinct("student_id", {
    section_id: lesson.section_id,
    starts_at: { $lte: lesson.start_at },
    $or: [{ ends_at: null }, { ends_at: { $gt: lesson.start_at } }],
  }).session(session ?? null);
}
export async function authorizeLesson(lesson, user, session) {
  const section = await get(Section, lesson.section_id, session);
  await authorizeSection(section, user, session);
  if (
    user.role === "STUDENT" &&
    !(await rosterIds(lesson, session)).some((key) => same(key, user._id))
  )
    fail(403, "Không đăng ký ở thời điểm buổi học");
  return section;
}
export async function ensureSlot(
  session,
  section,
  roomId,
  start,
  end,
  exclude,
) {
  const semester = await get(Semester, section.semester_id, session);
  if (end <= start || start < semester.start_at || end > semester.end_at)
    fail(409, "Buổi học phải nằm trong học kỳ");
  const room = await get(Room, roomId, session);
  if (room.capacity < section.capacity)
    fail(409, "Phòng phải đủ 30 chỗ của lớp");
  const filter = {
    status: { $ne: "CANCELLED" },
    start_at: { $lt: end },
    end_at: { $gt: start },
  };
  if (exclude) filter._id = { $ne: exclude };
  const conflict = await ClassSession.findOne({
    ...filter,
    $or: [
      { room_id: roomId },
      { lecturer_id: section.lecturer_id },
      { section_id: section._id },
    ],
  }).session(session);
  if (conflict) fail(409, "Trùng phòng, giảng viên hoặc lớp");
  const students = await Enrollment.distinct("student_id", {
    section_id: section._id,
    status: "ACTIVE",
  }).session(session);
  if (students.length) {
    const sections = await Enrollment.distinct("section_id", {
      student_id: { $in: students },
      status: "ACTIVE",
      section_id: { $ne: section._id },
    }).session(session);
    if (
      await ClassSession.findOne({
        ...filter,
        section_id: { $in: sections },
      }).session(session)
    )
      fail(409, "Sinh viên bị trùng lịch");
  }
}
export async function enroll(session, user, sectionId, studentId) {
  const section = await get(Section, sectionId, session);
  const student = await get(User, studentId, session);
  const now = new Date();
  if (student.role !== "STUDENT" || !student.active)
    fail(400, "Sinh viên không hợp lệ");
  if (section.status !== "OPEN") fail(409, "Lớp đã đóng đăng ký");
  const semester = await get(Semester, section.semester_id, session);
  if (semester.end_at <= now) fail(409, "Học kỳ đã kết thúc");
  const existing = await Enrollment.findOne({
    section_id: sectionId,
    student_id: studentId,
  }).session(session);
  if (existing?.status === "ACTIVE") fail(409, "Sinh viên đã đăng ký lớp");
  if (
    await Enrollment.exists({
      student_id: studentId,
      course_id: section.course_id,
      semester_id: section.semester_id,
      status: "ACTIVE",
      section_id: { $ne: sectionId },
    }).session(session)
  )
    fail(409, "Đã đăng ký lớp khác của môn này trong học kỳ");
  const lessons = await ClassSession.find({
    section_id: sectionId,
    status: "SCHEDULED",
    start_at: { $gt: now },
  }).session(session);
  if (!lessons.length)
    fail(409, "Lớp phải có lịch học tương lai trước khi đăng ký");
  if (lessons.some((s) => !s.slot_id))
    fail(409, "Lịch cũ cần được chuẩn hóa theo slot");
  const count = await Enrollment.countDocuments({
    section_id: sectionId,
    status: "ACTIVE",
  }).session(session);
  if (count >= 30) fail(409, "Lớp đã đủ 30 sinh viên; hãy chọn lớp khác");
  const rooms = await Room.find({
    _id: { $in: lessons.map((s) => s.room_id) },
  }).session(session);
  if (rooms.some((r) => r.capacity < count + 1))
    fail(409, "Phòng không đủ chỗ");
  const sectionIds = await Enrollment.distinct("section_id", {
    student_id: studentId,
    status: "ACTIVE",
  }).session(session);
  if (sectionIds.length) {
    const occupied = await ClassSession.find({
      section_id: { $in: sectionIds },
      status: { $ne: "CANCELLED" },
      end_at: { $gt: now },
    }).session(session);
    if (
      lessons.some((a) =>
        occupied.some((b) => a.start_at < b.end_at && a.end_at > b.start_at),
      )
    )
      fail(409, "Lịch lớp trùng lịch đã đăng ký");
  }
  const before = existing ? clean(existing) : null;
  const row =
    existing ??
    new Enrollment({
      section_id: sectionId,
      student_id: studentId,
      course_id: section.course_id,
      semester_id: section.semester_id,
    });
  row.status = "ACTIVE";
  row.enrolled_at = now;
  row.withdrawn_at = null;
  await row.save({ session });
  await EnrollmentPeriod.create(
    [{ section_id: sectionId, student_id: studentId, starts_at: now }],
    { session },
  );
  await audit(
    session,
    user,
    "ENROLL_STUDENT",
    "Section",
    sectionId,
    before,
    row,
  );
  return clean(row);
}
export async function withdraw(session, user, sectionId, studentId, expected) {
  const row = await Enrollment.findOne({
    section_id: sectionId,
    student_id: studentId,
  }).session(session);
  if (!row) fail(404, "Không có đăng ký");
  checkVersion(row, expected);
  if (row.status !== "ACTIVE") fail(409, "Đăng ký đã được rút");
  const before = clean(row);
  const now = new Date();
  row.status = "WITHDRAWN";
  row.withdrawn_at = now;
  await row.save({ session });
  await EnrollmentPeriod.updateOne(
    { section_id: sectionId, student_id: studentId, ends_at: null },
    { $set: { ends_at: now } },
    { session, runValidators: true },
  );
  const lessons = await ClassSession.distinct("_id", {
    section_id: sectionId,
    start_at: { $gt: now },
  }).session(session);
  const leaves = await Leave.find({
    requester_id: studentId,
    session_id: { $in: lessons },
    status: { $in: ["PENDING", "APPROVED"] },
  }).session(session);
  for (const leave of leaves) {
    const old = clean(leave);
    leave.status = "CANCELLED";
    await leave.save({ session });
    await audit(
      session,
      user,
      "CANCEL_LEAVE_WITHDRAWAL",
      "Leave",
      leave._id,
      old,
      leave,
    );
  }
  await audit(
    session,
    user,
    "WITHDRAW_STUDENT",
    "Section",
    sectionId,
    before,
    row,
  );
  return clean(row);
}
export async function reschedule(
  session,
  user,
  lesson,
  data,
  requestId = null,
) {
  if (
    lesson.status !== "SCHEDULED" ||
    lesson.start_at <= new Date() ||
    lesson.attendance_saved
  )
    fail(409, "Chỉ đổi buổi tương lai chưa điểm danh");
  const timing = slotTimes(data.session_date, data.slot_id);
  if (timing.start_at <= new Date()) fail(409, "Lịch mới phải trong tương lai");
  if (
    same(lesson.room_id, data.room_id) &&
    timing.start_at.getTime() === lesson.start_at.getTime() &&
    timing.end_at.getTime() === lesson.end_at.getTime()
  )
    fail(400, "Lịch mới không thay đổi");
  const section = await get(Section, lesson.section_id, session);
  await ensureSlot(
    session,
    section,
    data.room_id,
    timing.start_at,
    timing.end_at,
    lesson._id,
  );
  const before = clean(lesson);
  const oldSnapshot = sessionSnapshot(lesson);
  const changed =
    timing.start_at.getTime() !== lesson.start_at.getTime() ||
    timing.end_at.getTime() !== lesson.end_at.getTime();
  Object.assign(lesson, {
    ...timing,
    room_id: data.room_id,
    legacy_unaligned: false,
  });
  await lesson.save({ session });
  if (changed) {
    const leaves = await Leave.find({
      session_id: lesson._id,
      status: { $in: ["PENDING", "APPROVED"] },
    }).session(session);
    for (const row of leaves) {
      const old = clean(row);
      row.status = "INVALIDATED";
      await row.save({ session });
      await audit(
        session,
        user,
        "INVALIDATE_LEAVE_SLOT_CHANGE",
        "Leave",
        row._id,
        old,
        row,
      );
    }
  }
  await SessionHistory.create(
    [
      {
        session_id: lesson._id,
        actor_id: user._id,
        request_id: requestId,
        action: "RESCHEDULE_SESSION",
        before_data: oldSnapshot,
        after_data: sessionSnapshot(lesson),
      },
    ],
    { session },
  );
  await audit(
    session,
    user,
    "RESCHEDULE_SESSION",
    "ClassSession",
    lesson._id,
    before,
    lesson,
  );
  return lesson;
}
export async function cancelRequests(session, user, lesson) {
  for (const Model of [Leave, Change]) {
    const rows = await Model.find({
      session_id: lesson._id,
      status: { $in: Model === Leave ? ["PENDING", "APPROVED"] : ["PENDING"] },
    }).session(session);
    for (const row of rows) {
      const before = clean(row);
      row.status = "CANCELLED";
      await row.save({ session });
      await audit(
        session,
        user,
        "CANCEL_SESSION_REQUEST",
        Model.modelName,
        row._id,
        before,
        row,
      );
    }
  }
}
