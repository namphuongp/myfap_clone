import { courseRepository } from "../repositories/index.js";
import { majorRepository } from "../repositories/student-affairs.repositories.js";
import { fail } from "../utils/api-error.js";
import { same } from "../utils/identity.js";
import { clean } from "../utils/serialize.js";
import { checkVersion } from "../utils/version.js";
import { get, saveDocument } from "../repositories/base.repository.js";
import { transaction } from "../repositories/transaction.js";
import { audit } from "./audit.service.js";
import {
  semesterRepository,
  userRepository,
  roomRepository,
  sectionRepository,
  enrollmentRepository,
  enrollmentPeriodRepository,
  classSessionRepository,
  leaveRepository,
} from "../repositories/index.js";
export async function enroll(session, user, sectionId, studentId) {
  const section = await get(sectionRepository, sectionId, session);
  const student = await get(userRepository, studentId, session);
  const course = await get(courseRepository, section.course_id, session);
  if (course.active === false) fail(409, "Môn đã ngừng sử dụng");
  const now = new Date();
  if (!student.major_id)
    fail(409, "Cán bộ cần cập nhật ngành học trước khi đăng ký môn");
  const major = await get(majorRepository, student.major_id, session);
  if (
    !major.active ||
    !major.course_ids.some((key) => same(key, section.course_id))
  )
    fail(409, "Môn học không thuộc ngành hiện tại");
  if (student.role !== "STUDENT" || !student.active)
    fail(400, "Sinh viên không hợp lệ");
  if (section.status !== "OPEN") fail(409, "Lớp đã đóng đăng ký");
  const semester = await get(semesterRepository, section.semester_id, session);
  if (semester.end_at <= now) fail(409, "Học kỳ đã kết thúc");
  const existing = await enrollmentRepository.findOne(
    {
      section_id: sectionId,
      student_id: studentId,
    },
    { session: session },
  );
  if (existing?.status === "ACTIVE") fail(409, "Sinh viên đã đăng ký lớp");
  if (
    await enrollmentRepository.exists(
      {
        student_id: studentId,
        course_id: section.course_id,
        semester_id: section.semester_id,
        status: "ACTIVE",
        section_id: { $ne: sectionId },
      },
      { session: session },
    )
  )
    fail(409, "Đã đăng ký lớp khác của môn này trong học kỳ");
  const lessons = await classSessionRepository.find(
    {
      section_id: sectionId,
      status: "SCHEDULED",
      start_at: { $gt: now },
    },
    { session: session },
  );
  if (!lessons.length)
    fail(409, "Lớp phải có lịch học tương lai trước khi đăng ký");
  if (lessons.some((s) => !s.slot_id))
    fail(409, "Lịch cũ cần được chuẩn hóa theo slot");
  const count = await enrollmentRepository.countDocuments(
    {
      section_id: sectionId,
      status: "ACTIVE",
    },
    { session: session },
  );
  if (count >= 30) fail(409, "Lớp đã đủ 30 sinh viên; hãy chọn lớp khác");
  const rooms = await roomRepository.find(
    {
      _id: { $in: lessons.map((s) => s.room_id) },
    },
    { session: session },
  );
  if (rooms.some((r) => r.capacity < count + 1))
    fail(409, "Phòng không đủ chỗ");
  const sectionIds = await enrollmentRepository.distinct(
    "section_id",
    {
      student_id: studentId,
      status: "ACTIVE",
    },
    { session: session },
  );
  if (sectionIds.length) {
    const occupied = await classSessionRepository.find(
      {
        section_id: { $in: sectionIds },
        status: { $ne: "CANCELLED" },
        end_at: { $gt: now },
      },
      { session: session },
    );
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
    enrollmentRepository.instantiate({
      section_id: sectionId,
      student_id: studentId,
      course_id: section.course_id,
      semester_id: section.semester_id,
    });
  row.status = "ACTIVE";
  row.enrolled_at = now;
  row.withdrawn_at = null;
  await saveDocument(row, { session });
  await enrollmentPeriodRepository.create(
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
export async function withdraw(
  session,
  user,
  sectionId,
  studentId,
  expected,
  effectiveAt = new Date(),
) {
  const row = await enrollmentRepository.findOne(
    {
      section_id: sectionId,
      student_id: studentId,
    },
    { session: session },
  );
  if (!row) fail(404, "Không có đăng ký");
  checkVersion(row, expected);
  if (row.status !== "ACTIVE") fail(409, "Đăng ký đã được rút");
  const before = clean(row);
  const now = effectiveAt;
  row.status = "WITHDRAWN";
  row.withdrawn_at = now;
  await saveDocument(row, { session });
  await enrollmentPeriodRepository.updateOne(
    { section_id: sectionId, student_id: studentId, ends_at: null },
    { $set: { ends_at: now } },
    { session, runValidators: true },
  );
  const lessons = await classSessionRepository.distinct(
    "_id",
    {
      section_id: sectionId,
      start_at: { $gt: now },
    },
    { session: session },
  );
  const leaves = await leaveRepository.find(
    {
      requester_id: studentId,
      session_id: { $in: lessons },
      status: { $in: ["PENDING", "APPROVED"] },
    },
    { session: session },
  );
  for (const leave of leaves) {
    const old = clean(leave);
    leave.status = "CANCELLED";
    await saveDocument(leave, { session });
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
export async function myEnrollments(user) {
  return clean(
    await enrollmentRepository.find(
      { student_id: user._id },
      { sort: { enrolled_at: -1 }, limit: 200 },
    ),
  );
}
export async function registerStudent(user, sectionId, data) {
  const key = user.role === "STUDENT" ? user._id : data.student_id;
  return await transaction((session) => enroll(session, user, sectionId, key));
}
export async function withdrawStudent(user, sectionId, data, studentId) {
  if (user.role === "STUDENT" && !same(studentId, user._id))
    fail(403, "Chỉ được rút đăng ký của mình");

  return await transaction((session) =>
    withdraw(session, user, sectionId, studentId, data.version),
  );
}
