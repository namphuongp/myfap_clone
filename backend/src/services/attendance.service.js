import { fail } from "../utils/api-error.js";
import { same } from "../utils/identity.js";
import { clean } from "../utils/serialize.js";
import { checkVersion } from "../utils/version.js";
import { get, saveDocument } from "../repositories/base.repository.js";
import { transaction } from "../repositories/transaction.js";
import { audit } from "./audit.service.js";
import { rosterIds, authorizeLesson } from "./access.service.js";
import { localDate } from "../utils/slots.js";
import {
  userRepository,
  classSessionRepository,
  leaveRepository,
} from "../repositories/index.js";
export async function getAttendance(user, sessionId) {
  const lesson = await get(classSessionRepository, sessionId);
  await authorizeLesson(lesson, user);
  let ids = await rosterIds(lesson);
  if (user.role === "STUDENT") ids = ids.filter((s) => same(s, user._id));
  const students = await userRepository.find(
    { _id: { $in: ids } },
    { sort: { _id: 1 } },
  );
  const leaves = await leaveRepository.find({
    session_id: lesson._id,
    status: "APPROVED",
    requested_start: lesson.start_at,
    requested_end: lesson.end_at,
  });
  return {
    version: lesson.version,
    saved: lesson.attendance_saved,
    session_status: lesson.status,
    rows: students.map((s) => {
      const a = lesson.attendance.find((a) => same(a.student_id, s._id));
      const l = leaves.find((l) => same(l.requester_id, s._id));
      return {
        student_id: String(s._id),
        user_code: s.user_code,
        name: s.name,
        status: a?.status ?? "NOT_RECORDED",
        approved_leave_id: l ? String(l._id) : null,
        note: l ? "Nghỉ có phép" : null,
      };
    }),
  };
}
export async function saveAttendance(user, sessionId, data) {
  const result = await transaction(async (session) => {
    const lesson = await get(classSessionRepository, sessionId, session);
    await authorizeLesson(lesson, user, session);
    checkVersion(lesson, data.version);
    const now = new Date();
    if (lesson.status === "CANCELLED") fail(409, "Buổi học đã bị hủy");
    if (lesson.session_date !== localDate(now))
      fail(409, "Chỉ được điểm danh trong ngày diễn ra buổi học");
    if (lesson.start_at > now) fail(409, "Buổi học chưa bắt đầu");
    const students = await rosterIds(lesson, session);
    const ids = new Set(data.rows.map((r) => r.student_id));
    if (
      ids.size !== data.rows.length ||
      ids.size !== students.length ||
      !students.every((s) => ids.has(String(s)))
    )
      fail(400, "Cần đúng và đủ danh sách tại thời điểm buổi học");
    for (const row of data.rows) {
      if (
        !["PRESENT", "ABSENT"].includes(row.status) &&
        !lesson.attendance.some(
          (old) =>
            same(old.student_id, row.student_id) && old.status === row.status,
        )
      )
        fail(
          400,
          "Điểm danh mới chỉ nhận PRESENT/ABSENT; trạng thái cũ chỉ được giữ nguyên",
        );
    }
    const before = {
      version: lesson.version,
      rows: clean(lesson.attendance),
    };
    lesson.attendance = data.rows.map((r) => ({
      ...r,
      updated_by: user._id,
      updated_at: now,
    }));
    lesson.attendance_saved = true;
    await saveDocument(lesson, { session });
    await audit(
      session,
      user,
      "SAVE_ATTENDANCE",
      "ClassSession",
      lesson._id,
      before,
      { version: lesson.version, rows: clean(lesson.attendance) },
    );
    return { version: lesson.version };
  });
  return result;
}
