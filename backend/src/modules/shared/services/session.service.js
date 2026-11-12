import { fail } from "../../../utils/api-error.js";
import { same } from "../../../utils/identity.js";
import { clean } from "../../../utils/serialize.js";
import { get } from "../../../repositories/base.repository.js";
import { transaction } from "../../../repositories/transaction.js";
import {
  sectionFilter,
  authorizeSection,
  authorizeLesson,
} from "./access.service.js";
import { recordSession, ensureSlot } from "./scheduling.service.js";
import { slotTimes } from "../../../utils/slots.js";
import {
  courseRepository,
  roomRepository,
  sectionRepository,
  classMembershipRepository,
  classSessionRepository,
  leaveRepository,
} from "../../../repositories/index.js";

async function approvedLeaveSessions(user, rows) {
  if (user.role !== "STUDENT" || rows.length === 0) return new Set();
  const leaves = await leaveRepository.find({
    requester_id: user._id,
    status: "APPROVED",
    session_id: { $in: rows.map((row) => row._id ?? row.id) },
  });
  return new Set(
    leaves
      .filter((leave) => {
        const lesson = rows.find((row) =>
          same(row._id ?? row.id, leave.session_id),
        );
        return (
          lesson &&
          lesson.status !== "CANCELLED" &&
          +leave.requested_start === +lesson.start_at &&
          +leave.requested_end === +lesson.end_at
        );
      })
      .map((leave) => String(leave.session_id)),
  );
}
// Lấy lịch cá nhân đúng phạm vi và thời gian thuộc lớp.
export async function personalSchedule(user, q) {
  if (q.to <= q.from || q.to - q.from > 93 * 86400000)
    fail(400, "Khoảng xem lịch tối đa 93 ngày");
  const sections = await sectionRepository.find(await sectionFilter(user));
  let rows = await classSessionRepository.find(
    {
      section_id: { $in: sections.map((s) => s._id) },
      ...(user.role === "LECTURER" ? { lecturer_id: user._id } : {}),
      start_at: { $lt: q.to },
      end_at: { $gt: q.from },
    },
    { sort: { start_at: 1 }, limit: 1000 },
  );
  if (user.role === "STUDENT") {
    const periods = await classMembershipRepository.find({
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
  const approvedLeaveIds = await approvedLeaveSessions(user, rows);
  return rows.map((s) => {
    const section = sections.find((c) => same(c._id, s.section_id));
    const dto = clean(s);
    let myAttendance = null;
    if (user.role === "STUDENT" && s.attendance) {
      const myRecord = s.attendance.find((a) => same(a.student_id, user._id));
      if (myRecord) {
        myAttendance = {
          status: myRecord.status,
          note: myRecord.note ?? null,
        };
      }
    }
    delete dto.attendance;
    return {
      ...dto,
      section_code: section.code,
      course_id: String(section.course_id),
      semester_id: String(section.semester_id),
      course: courses.find((c) => same(c._id, section.course_id))?.name,
      course_code: courses.find((c) => same(c._id, section.course_id))?.code,
      room_name: rooms.find((r) => same(r._id, s.room_id))?.name,
      my_attendance: myAttendance,
      approved_leave: approvedLeaveIds.has(String(s._id)),
    };
  });
}
// Lấy các buổi học trong lớp được phép xem.
export async function sectionSessions(user, sectionId) {
  const section = await get(sectionRepository, sectionId);
  await authorizeSection(section, user);
  const rows = clean(
    await classSessionRepository.find(
      {
        section_id: section._id,
        ...(user.role === "LECTURER" ? { lecturer_id: user._id } : {}),
      },
      { sort: { start_at: 1 }, limit: 1000 },
    ),
  );
  const approvedLeaveIds = await approvedLeaveSessions(user, rows);
  for (const row of rows) {
    if (user.role === "STUDENT" && row.attendance) {
      const myRecord = row.attendance.find((a) => same(a.student_id, user._id));
      if (myRecord) {
        row.my_attendance = {
          status: myRecord.status,
          note: myRecord.note ?? null,
        };
      }
    }
    delete row.attendance;
    row.approved_leave = approvedLeaveIds.has(String(row.id));
  }
  return rows;
}
// Tạo buổi học khi lịch, phòng và người dạy hợp lệ.
export async function createSession(user, data) {
  const row = await transaction(async (session) => {
    const section = await get(sectionRepository, data.section_id, session);
    await authorizeSection(section, user, session);
    const timing = slotTimes(data.session_date, data.slot_id);
    if (timing.start_at <= new Date()) fail(409, "Chỉ tạo buổi học tương lai");
    await ensureSlot(
      session,
      section,
      data.room_id,
      timing.start_at,
      timing.end_at,
      undefined,
      data.lecturer_id ?? null,
    );
    const [row] = await classSessionRepository.create(
      [
        {
          ...timing,
          section_id: section._id,
          lecturer_id: data.lecturer_id ?? null,
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
