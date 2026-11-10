import { fail } from "../utils/api-error.js";
import { clean } from "../utils/serialize.js";
import { checkVersion } from "../utils/version.js";
import { get, saveDocument } from "../repositories/base.repository.js";
import { transaction } from "../repositories/transaction.js";
import { audit } from "./audit.service.js";
import { scopedSectionIds, authorizeLesson } from "./access.service.js";
import { ensureSlot, reschedule } from "./scheduling.service.js";
import { slotTimes } from "../utils/slots.js";
import {
  enrollmentRepository,
  classSessionRepository,
  leaveRepository,
  changeRepository,
  userRepository,
  sectionRepository,
  courseRepository,
  roomRepository,
} from "../repositories/index.js";
const requestRepositories = {
  leave: leaveRepository,
  change: changeRepository,
};
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
export async function createChange(user, data) {
  const result = await transaction(async (session) => {
    const lesson = await get(classSessionRepository, data.session_id, session);
    const section = await authorizeLesson(lesson, user, session);
    if (
      user.role === "HEAD" &&
      (data.proposed_date !== lesson.session_date ||
        data.proposed_slot_id !== lesson.slot_id)
    )
      fail(
        403,
        "Trưởng bộ môn chỉ được yêu cầu chuyển phòng, giữ nguyên ngày và ca",
      );
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
    if (
      await changeRepository.exists(
        { session_id: lesson._id, status: "PENDING" },
        { session },
      )
    )
      fail(409, "Buổi học đã có yêu cầu chờ duyệt; hãy chờ cán bộ xử lý");
    await ensureSlot(
      session,
      section,
      data.proposed_room_id,
      timing.start_at,
      timing.end_at,
      lesson._id,
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
export async function listRequests(user, q, kind) {
  const repository = requestRepositories[kind];

  if (repository === changeRepository && user.role === "STUDENT")
    fail(403, "Không có quyền");

  const filter = {};
  if (q.status) filter.status = q.status;
  if (
    user.role === "STUDENT" ||
    (repository === changeRepository &&
      ["LECTURER", "HEAD"].includes(user.role))
  )
    filter.requester_id = user._id;
  else if (user.role !== "STAFF") {
    const sections = await scopedSectionIds(user);
    filter.session_id = {
      $in: await classSessionRepository.distinct("_id", {
        section_id: { $in: sections },
      }),
    };
  }
  if (user.role === "HEAD") {
    const sections = await scopedSectionIds(user);
    filter.session_id = {
      $in: await classSessionRepository.distinct("_id", {
        section_id: { $in: sections },
      }),
    };
  }
  const [requests, total] = await Promise.all([
    repository.find(filter, {
      sort: { created_at: -1, _id: -1 },
      skip: (q.page - 1) * 50,
      limit: 50,
    }),
    repository.countDocuments(filter),
  ]);
  const lessons = await classSessionRepository.find({
    _id: { $in: requests.map((r) => r.session_id) },
  });
  const [people, sections, rooms] = await Promise.all([
    userRepository.find({
      _id: {
        $in: requests.flatMap((r) =>
          [r.requester_id, r.reviewer_id].filter(Boolean),
        ),
      },
    }),
    sectionRepository.find({ _id: { $in: lessons.map((r) => r.section_id) } }),
    roomRepository.find({
      _id: {
        $in: [
          ...lessons.map((r) => r.room_id),
          ...requests.map((r) => r.proposed_room_id).filter(Boolean),
          ...requests.map((r) => r.original_room_id).filter(Boolean),
        ],
      },
    }),
  ]);
  const courses = await courseRepository.find({
    _id: { $in: sections.map((r) => r.course_id) },
  });
  const byId = (rows) => new Map(rows.map((r) => [String(r._id), r]));
  const lessonMap = byId(lessons),
    peopleMap = byId(people),
    sectionMap = byId(sections),
    courseMap = byId(courses),
    roomMap = byId(rooms);
  return {
    page: q.page,
    total,
    has_more: q.page * 50 < total,
    items: requests.map((row) => {
      const lesson = lessonMap.get(String(row.session_id));
      const section = sectionMap.get(String(lesson?.section_id));
      const person = peopleMap.get(String(row.requester_id));
      return {
        ...clean(row),
        requester_name: person?.name ?? null,
        requester_code: person?.user_code ?? null,
        reviewer_name: peopleMap.get(String(row.reviewer_id))?.name ?? null,
        section_code: section?.code ?? null,
        course: courseMap.get(String(section?.course_id))?.name ?? null,
        session_date: lesson?.session_date ?? null,
        slot_id: kind === "leave" ? row.slot_id : (lesson?.slot_id ?? null),
        room_name: roomMap.get(String(lesson?.room_id))?.name ?? null,
        proposed_room_name:
          roomMap.get(String(row.proposed_room_id))?.name ?? null,
        original_room_name:
          roomMap.get(String(row.original_room_id))?.name ?? null,
      };
    }),
  };
}
export async function reviewRequest(user, requestId, data, kind) {
  const repository = requestRepositories[kind];

  const result = await transaction(async (session) => {
    const row = await get(repository, requestId, session);
    const lesson = await get(classSessionRepository, row.session_id, session);
    if (repository === leaveRepository)
      await authorizeLesson(lesson, user, session);
    checkVersion(row, data.version);
    if (row.status !== "PENDING") fail(409, "Đơn không còn chờ duyệt");
    if (data.decision === "APPROVED") {
      if (lesson.status !== "SCHEDULED" || lesson.start_at <= new Date())
        fail(409, "Buổi học đã bắt đầu hoặc không còn hiệu lực");
      if (repository === leaveRepository) {
        if (
          row.requested_start.getTime() !== lesson.start_at.getTime() ||
          row.requested_end.getTime() !== lesson.end_at.getTime()
        )
          fail(409, "Slot đã đổi, đơn nghỉ không còn hiệu lực");
        if (
          !(await enrollmentRepository.exists(
            {
              section_id: lesson.section_id,
              student_id: row.requester_id,
              status: "ACTIVE",
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
