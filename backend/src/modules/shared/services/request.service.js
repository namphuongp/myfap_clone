import { displayRequests } from "./request-display.service.js";
import { fail } from "../../../utils/api-error.js";
import { clean } from "../../../utils/serialize.js";
import { checkVersion } from "../../../utils/version.js";
import { get, saveDocument } from "../../../repositories/base.repository.js";
import { transaction } from "../../../repositories/transaction.js";
import { audit } from "./audit.service.js";
import { authorizeLesson } from "./access.service.js";
import { ensureSlot, reschedule } from "./scheduling.service.js";
import { slotTimes } from "../../../utils/slots.js";
import {
  classMembershipRepository,
  classSessionRepository,
  leaveRepository,
  changeRepository,
} from "../../../repositories/index.js";
const requestRepositories = {
  leave: leaveRepository,
  change: changeRepository,
};
// Tạo đơn nghỉ cho buổi học sinh viên đang tham gia.
export async function createLeave(user, data) {
  const result = await transaction(async (session) => {
    const lesson = await get(classSessionRepository, data.session_id, session);
    await authorizeLesson(lesson, user, session);
    if (
      lesson.status !== "SCHEDULED" ||
      lesson.start_at <= new Date() ||
      !lesson.slot_id
    )
      fail(409, "Chỉ xin nghỉ buổi tương lai có slot hợp lệ");
    const [row] = await leaveRepository.create(
      [
        {
          ...data,
          requester_id: user._id,
          session_version: lesson.version,
          session_date: lesson.session_date,
          slot_id: lesson.slot_id,
          requested_start: lesson.start_at,
          requested_end: lesson.end_at,
        },
      ],
      { session },
    );
    await audit(session, user, "CREATE_LEAVE", "Leave", row._id, null, row);
    return clean(row);
  });
  return result;
}
// Tạo đề xuất đổi lịch hoặc phòng của giảng viên phụ trách.
export async function createChange(user, data) {
  const result = await transaction(async (session) => {
    const lesson = await get(classSessionRepository, data.session_id, session);
    const section = await authorizeLesson(lesson, user, session);
    const timing = slotTimes(data.proposed_date, data.proposed_slot_id);
    if (
      lesson.status !== "SCHEDULED" ||
      lesson.start_at <= new Date() ||
      timing.start_at <= new Date() ||
      lesson.attendance_saved
    )
      fail(409, "Chỉ đổi buổi tương lai chưa điểm danh");
    if (
      String(lesson.room_id) === data.proposed_room_id &&
      timing.start_at.getTime() === lesson.start_at.getTime() &&
      timing.end_at.getTime() === lesson.end_at.getTime()
    )
      fail(400, "Lịch đề xuất không thay đổi");
    await ensureSlot(
      session,
      section,
      data.proposed_room_id,
      timing.start_at,
      timing.end_at,
      lesson._id,
      lesson.lecturer_id,
    );
    const [row] = await changeRepository.create(
      [
        {
          ...data,
          requester_id: user._id,
          session_version: lesson.version,
          proposed_start: timing.start_at,
          proposed_end: timing.end_at,
          original_room_id: lesson.room_id,
          original_date: lesson.session_date,
          original_slot_id: lesson.slot_id,
          original_start: lesson.start_at,
          original_end: lesson.end_at,
        },
      ],
      { session },
    );
    await audit(session, user, "CREATE_CHANGE", "Change", row._id, null, row);
    return clean(row);
  });
  return result;
}
// Lấy các đơn theo quyền người gửi hoặc người duyệt.
export async function listRequests(user, q, kind) {
  const repository = requestRepositories[kind];

  if (repository === changeRepository && user.role === "STUDENT")
    fail(403, "Không có quyền");

  const filter = {};
  if (q.status) filter.status = q.status;
  if (
    user.role === "STUDENT" ||
    (repository === changeRepository && user.role === "LECTURER")
  )
    filter.requester_id = user._id;
  else if (user.role !== "STAFF") {
    filter.session_id = {
      $in: await classSessionRepository.distinct("_id", {
        lecturer_id: user._id,
      }),
    };
  }
  const total = await repository.countDocuments(filter);
  return {
    page: q.page,
    total,
    has_more: q.page * 50 < total,
    items: await displayRequests(
      await repository.find(filter, {
        sort: { created_at: -1, _id: -1 },
        skip: (q.page - 1) * 50,
        limit: 50,
      }),
    ),
  };
}
// Duyệt đơn với kiểm tra phiên bản, lịch và quyền phụ trách.
export async function reviewRequest(user, requestId, data, kind) {
  const repository = requestRepositories[kind];

  const result = await transaction(async (session) => {
    const row = await get(repository, requestId, session);
    const lesson = await get(classSessionRepository, row.session_id, session);
    if (repository === leaveRepository)
      await authorizeLesson(lesson, user, session);
    checkVersion(row, data.version);
    if (row.status !== "PENDING") fail(409, "Đơn không còn chờ duyệt");
    if (lesson.status !== "SCHEDULED" || lesson.start_at <= new Date())
      fail(409, "Buổi học đã bắt đầu hoặc không còn hiệu lực");
    if (data.decision === "APPROVED") {
      if (repository === leaveRepository) {
        if (
          row.requested_start.getTime() !== lesson.start_at.getTime() ||
          row.requested_end.getTime() !== lesson.end_at.getTime()
        )
          fail(409, "Slot đã đổi, đơn nghỉ không còn hiệu lực");
        if (
          !(await classMembershipRepository.exists(
            {
              section_id: lesson.section_id,
              student_id: row.requester_id,
              starts_at: { $lte: lesson.start_at },
              $or: [{ ends_at: null }, { ends_at: { $gt: lesson.start_at } }],
            },
            { session: session },
          ))
        )
          fail(409, "Sinh viên không còn học lớp này");
      } else {
        checkVersion(lesson, row.session_version);
        if (!row.proposed_slot_id || !row.proposed_date)
          fail(409, "Đơn cũ chưa có slot; cần gửi đơn mới");
        await reschedule(
          session,
          user,
          lesson,
          {
            room_id: row.proposed_room_id,
            session_date: row.proposed_date,
            slot_id: row.proposed_slot_id,
          },
          row._id,
        );
      }
    }
    const before = clean(row);
    row.status = data.decision;
    row.reviewer_id = user._id;
    row.review_note = data.note;
    row.reviewed_at = new Date();
    await saveDocument(row, { session });
    await audit(
      session,
      user,
      "REVIEW_REQUEST",
      repository.entityName,
      row._id,
      before,
      row,
    );
    return clean(row);
  });
  return result;
}
