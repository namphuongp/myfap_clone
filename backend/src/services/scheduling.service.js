import { fail } from "../utils/api-error.js";
import { same } from "../utils/identity.js";
import { clean } from "../utils/serialize.js";
import { get, saveDocument } from "../repositories/base.repository.js";
import { audit } from "./audit.service.js";
import { slotTimes } from "../utils/slots.js";
import {
  semesterRepository,
  roomRepository,
  sectionRepository,
  classMembershipRepository,
  classSessionRepository,
  leaveRepository,
} from "../repositories/index.js";
export const sessionSnapshot = (s) =>
  clean({
    lecturer_id: s.lecturer_id ?? null,
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
  await audit(
    session,
    user,
    action,
    "ClassSession",
    after._id,
    before ? sessionSnapshot(before) : null,
    sessionSnapshot(after),
    requestId,
  );
}
export async function ensureSlot(
  session,
  section,
  roomId,
  start,
  end,
  exclude,
  lecturerId = null,
) {
  const semester = await get(semesterRepository, section.semester_id, session);
  if (end <= start || start < semester.start_at || end > semester.end_at)
    fail(409, "Buổi học phải nằm trong học kỳ");
  const room = await get(roomRepository, roomId, session);
  if (room.capacity < section.capacity)
    fail(409, "Phòng phải đủ 30 chỗ của lớp");
  const filter = {
    status: { $ne: "CANCELLED" },
    start_at: { $lt: end },
    end_at: { $gt: start },
  };
  if (exclude) filter._id = { $ne: exclude };
  const conflict = await classSessionRepository.findOne(
    {
      ...filter,
      $or: [
        { room_id: roomId },
        ...(lecturerId ? [{ lecturer_id: lecturerId }] : []),
        { section_id: section._id },
      ],
    },
    { session: session },
  );
  if (conflict) fail(409, "Trùng phòng, giảng viên hoặc lớp");
  const students = await classMembershipRepository.distinct(
    "student_id",
    {
      section_id: section._id,
      ends_at: null,
    },
    { session: session },
  );
  if (students.length) {
    const sections = await classMembershipRepository.distinct(
      "section_id",
      {
        student_id: { $in: students },
        ends_at: null,
        section_id: { $ne: section._id },
      },
      { session: session },
    );
    if (
      await classSessionRepository.findOne(
        {
          ...filter,
          section_id: { $in: sections },
        },
        { session: session },
      )
    )
      fail(409, "Sinh viên bị trùng lịch");
  }
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
  const section = await get(sectionRepository, lesson.section_id, session);
  await ensureSlot(
    session,
    section,
    data.room_id,
    timing.start_at,
    timing.end_at,
    lesson._id,
    lesson.lecturer_id,
  );
  const before = clean(lesson);
  const changed =
    timing.start_at.getTime() !== lesson.start_at.getTime() ||
    timing.end_at.getTime() !== lesson.end_at.getTime();
  Object.assign(lesson, {
    ...timing,
    room_id: data.room_id,
    legacy_unaligned: false,
  });
  await saveDocument(lesson, { session });
  if (changed) {
    const leaves = await leaveRepository.find(
      {
        session_id: lesson._id,
        status: { $in: ["PENDING", "APPROVED"] },
      },
      { session: session },
    );
    for (const row of leaves) {
      const old = clean(row);
      row.status = "INVALIDATED";
      await saveDocument(row, { session });
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
  await audit(
    session,
    user,
    "RESCHEDULE_SESSION",
    "ClassSession",
    lesson._id,
    before,
    lesson,
    requestId,
  );
  return lesson;
}
