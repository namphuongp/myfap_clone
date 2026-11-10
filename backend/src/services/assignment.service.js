import {
  userRepository,
  sectionRepository,
  classSessionRepository,
  changeRepository,
} from "../repositories/index.js";
import { get, saveDocument } from "../repositories/base.repository.js";
import { transaction } from "../repositories/transaction.js";
import { authorizeSection } from "./access.service.js";
import { ensureSlot, recordSession } from "./scheduling.service.js";
import { audit } from "./audit.service.js";
import { checkVersion } from "../utils/version.js";
import { same } from "../utils/identity.js";
import { clean } from "../utils/serialize.js";
import { fail } from "../utils/api-error.js";
export async function listLecturers(actor) {
  return clean(
    await userRepository.find(
      { role: "LECTURER", active: true, department_id: actor.department_id },
      { select: "name user_code department_id", sort: { name: 1 }, limit: 500 },
    ),
  );
}
export async function assignSessions(actor, sectionId, data) {
  return transaction(async (session) => {
    const section = await get(sectionRepository, sectionId, session);
    await authorizeSection(section, actor, session);
    const result = [];
    for (const item of data.assignments) {
      const lesson = await get(
        classSessionRepository,
        item.session_id,
        session,
      );
      if (!same(lesson.section_id, section._id))
        fail(403, "Buổi không thuộc lớp phân công");
      checkVersion(lesson, item.version);
      if (
        lesson.status !== "SCHEDULED" ||
        lesson.start_at <= new Date() ||
        lesson.attendance_saved
      )
        fail(409, "Chỉ phân công buổi tương lai chưa điểm danh");
      if (item.lecturer_id) {
        const lecturer = await get(userRepository, item.lecturer_id, session);
        if (
          !lecturer.active ||
          lecturer.role !== "LECTURER" ||
          !same(lecturer.department_id, actor.department_id)
        )
          fail(400, "Giảng viên phải hoạt động và thuộc bộ môn");
      }
      if (same(lesson.lecturer_id, item.lecturer_id)) {
        result.push(sessionDto(lesson));
        continue;
      }
      await ensureSlot(
        session,
        section,
        lesson.room_id,
        lesson.start_at,
        lesson.end_at,
        lesson._id,
        item.lecturer_id,
      );
      const before = clean(lesson);
      lesson.lecturer_id = item.lecturer_id;
      await saveDocument(lesson, { session });
      // Đổi người phụ trách hủy đề xuất cũ; đơn nghỉ giữ nguyên vì ngày/slot chưa đổi.
      const pending = await changeRepository.find(
        { session_id: lesson._id, status: "PENDING" },
        { session },
      );
      for (const request of pending) {
        const old = clean(request);
        request.status = "CANCELLED";
        await saveDocument(request, { session });
        await audit(
          session,
          actor,
          "CANCEL_CHANGE_REASSIGNMENT",
          "Change",
          request._id,
          old,
          request,
        );
      }
      await recordSession(session, actor, "ASSIGN_LECTURER", before, lesson);
      await audit(
        session,
        actor,
        "ASSIGNMENT_REASON",
        "ClassSession",
        lesson._id,
        null,
        { reason: data.reason },
      );
      result.push(sessionDto(lesson));
    }
    return { items: result };
  });
}
function sessionDto(lesson) {
  const dto = clean(lesson);
  delete dto.attendance;
  return dto;
}
