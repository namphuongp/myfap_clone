import { fail } from "../utils/api-error.js";
import { same } from "../utils/identity.js";
import { clean } from "../utils/serialize.js";
import { checkVersion } from "../utils/version.js";
import { get, saveDocument } from "../repositories/base.repository.js";
import { transaction } from "../repositories/transaction.js";
import { audit } from "./audit.service.js";
import {
  sectionFilter,
  authorizeSection,
  authorizeLesson,
} from "./access.service.js";
import { recordSession, ensureSlot, reschedule } from "./scheduling.service.js";
import { cancelRequests } from "./request-state.service.js";
import { slotTimes } from "../utils/slots.js";
import {
  courseRepository,
  roomRepository,
  sectionRepository,
  enrollmentPeriodRepository,
  classSessionRepository,
  sessionHistoryRepository,
} from "../repositories/index.js";
export async function personalSchedule(user, q) {
  if (q.to <= q.from || q.to - q.from > 93 * 86400000)
    fail(400, "Khoảng xem lịch tối đa 93 ngày");
  const sections = await sectionRepository.find(await sectionFilter(user));
  let rows = await classSessionRepository.find(
    {
      section_id: { $in: sections.map((s) => s._id) },
      start_at: { $lt: q.to },
      end_at: { $gt: q.from },
    },
    { sort: { start_at: 1 }, limit: 1000 },
  );
  if (user.role === "STUDENT") {
    const periods = await enrollmentPeriodRepository.find({
      student_id: user._id,
    });
    rows = rows.filter((s) =>
      periods.some(
        (p) =>
          same(p.section_id, s.section_id) &&
          p.starts_at <= s.start_at &&
          (!p.ends_at || p.ends_at > s.start_at),
      ),
    );
  }
  const courses = await courseRepository.find({
    _id: { $in: sections.map((s) => s.course_id) },
  });
  const rooms = await roomRepository.find({
    _id: { $in: rows.map((s) => s.room_id) },
  });
  return rows.map((s) => {
    const section = sections.find((c) => same(c._id, s.section_id));
    const dto = clean(s);
    delete dto.attendance;
    return {
      ...dto,
      section_code: section.code,
      course_id: String(section.course_id),
      semester_id: String(section.semester_id),
      course: courses.find((c) => same(c._id, section.course_id))?.name,
      course_code: courses.find((c) => same(c._id, section.course_id))?.code,
      room_name: rooms.find((r) => same(r._id, s.room_id))?.name,
    };
  });
}
export async function sectionSessions(user, sectionId) {
  const section = await get(sectionRepository, sectionId);
  if (user.role !== "STUDENT") await authorizeSection(section, user);
  const rows = clean(
    await classSessionRepository.find(
      { section_id: section._id },
      { sort: { start_at: 1 }, limit: 1000 },
    ),
  );
  for (const row of rows) delete row.attendance;
  return rows;
}
export async function createSession(user, data) {
  const row = await transaction(async (session) => {
    const section = await get(sectionRepository, data.section_id, session);
    const timing = slotTimes(data.session_date, data.slot_id);
    if (timing.start_at <= new Date()) fail(409, "Chỉ tạo buổi học tương lai");
    await ensureSlot(
      session,
      section,
      data.room_id,
      timing.start_at,
      timing.end_at,
    );
    const [row] = await classSessionRepository.create(
      [
        {
          ...timing,
          section_id: section._id,
          lecturer_id: section.lecturer_id,
          room_id: data.room_id,
        },
      ],
      { session },
    );
    await recordSession(session, user, "CREATE_SESSION", null, row);
    const dto = clean(row);
    delete dto.attendance;
    return dto;
  });
  return row;
}
export async function changeSchedule(user, sessionId, data) {
  const row = await transaction(async (session) => {
    const lesson = await get(classSessionRepository, sessionId, session);
    checkVersion(lesson, data.version);
    const row = await reschedule(session, user, lesson, data);
    await audit(
      session,
      user,
      "SCHEDULE_REASON",
      "ClassSession",
      row._id,
      null,
      { reason: data.reason },
    );
    return clean(row);
  });
  return row;
}
export async function setSessionStatus(user, sessionId, data) {
  const result = await transaction(async (session) => {
    const row = await get(classSessionRepository, sessionId, session);
    checkVersion(row, data.version);
    if (row.status !== "SCHEDULED") fail(409, "Buổi đã kết thúc hoặc hủy");
    if (data.status === "COMPLETED" && row.end_at > new Date())
      fail(409, "Buổi học chưa kết thúc");
    if (
      data.status === "CANCELLED" &&
      (row.start_at <= new Date() || row.attendance_saved)
    )
      fail(409, "Không hủy buổi đã bắt đầu hoặc có điểm danh");
    const before = clean(row);
    row.status = data.status;
    await saveDocument(row, { session });
    if (data.status === "CANCELLED") await cancelRequests(session, user, row);
    await recordSession(session, user, "SET_SESSION_STATUS", before, row);
    await audit(session, user, "STATUS_REASON", "ClassSession", row._id, null, {
      reason: data.reason,
    });
    return clean(row);
  });
  return result;
}
export async function sessionHistory(user, sessionId) {
  const lesson = await get(classSessionRepository, sessionId);
  await authorizeLesson(lesson, user);
  return clean(
    await sessionHistoryRepository.find(
      { session_id: lesson._id },
      { sort: { created_at: -1, _id: -1 }, limit: 200 },
    ),
  );
}
