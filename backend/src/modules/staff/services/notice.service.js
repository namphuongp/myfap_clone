import {
  noticeRepository,
  majorRepository,
  departmentRepository,
  userRepository,
} from "../../../repositories/index.js";

import { get, saveDocument } from "../../../repositories/base.repository.js";
import { transaction } from "../../../repositories/transaction.js";
import { audit } from "../../shared/services/audit.service.js";
import { clean } from "../../../utils/serialize.js";
import { checkVersion } from "../../../utils/version.js";
import { fail } from "../../../utils/api-error.js";
// Kiểm tra đối tượng nhận và chuẩn hóa nội dung thông báo.
async function audienceFields(data, session) {
  const departments = [...new Set(data.department_ids)],
    majors = [...new Set(data.major_ids)];
  const isGlobal = [
    "ALL_STUDENTS",
    "ALL_LECTURERS",
    "ALL_HEADS",
    "ALL_USERS",
  ].includes(data.audience);
  if (
    (isGlobal && (departments.length || majors.length)) ||
    (data.audience === "DEPARTMENT" && (!departments.length || majors.length)) ||
    (data.audience === "MAJOR" && (!majors.length || departments.length))
  )
    fail(400, "Đối tượng nhận không khớp loại thông báo");
  for (const id of departments) await get(departmentRepository, id, session);
  for (const id of majors) {
    const major = await get(majorRepository, id, session);
    if (!major.active) fail(400, "Ngành nhận thông báo đã ngừng hoạt động");
  }
  if (data.expires_at && data.expires_at <= new Date())
    fail(400, "Ngày hết hạn phải ở tương lai");
  return {
    title: data.title,
    content: data.content,
    audience: data.audience,
    department_ids: departments,
    major_ids: majors,
    expires_at: data.expires_at ?? null,
  };
}
// Giới hạn thông báo theo đối tượng nhận và thời hạn.
async function visibleFilter(actor) {
  // TB4: Sinh viên chỉ thấy thông báo đã phát hành, chưa hết hạn, đúng ngành/bộ môn/đối tượng.
  const user = await get(userRepository, actor._id);
  const scope = [{ audience: "ALL_USERS" }];
  if (user.role === "STUDENT") scope.push({ audience: "ALL_STUDENTS" });
  if (user.role === "LECTURER") scope.push({ audience: "ALL_LECTURERS" });
  if (user.role === "HEAD") scope.push({ audience: "ALL_HEADS" });
  if (user.department_id) {
    scope.push({ audience: "DEPARTMENT", department_ids: user.department_id });
  }
  if (user.role === "STUDENT" && user.major_id) {
    scope.push({ audience: "MAJOR", major_ids: user.major_id });
  }
  const now = new Date();
  return {
    status: "PUBLISHED",
    published_at: { $lte: now },
    $and: [
      { $or: [{ expires_at: null }, { expires_at: { $gt: now } }] },
      { $or: scope },
    ],
  };
}
// Tạo thông báo nháp sau khi kiểm tra đối tượng nhận.
export async function createNotice(actor, data) {
  // PT4: Backend kiểm tra đối tượng nhận và lưu thông báo DRAFT.
  return transaction(async (session) => {
    const fields = await audienceFields(data, session);
    const row = await noticeRepository.create(
      { ...fields, created_by: actor._id },
      { session },
    );
    await audit(session, actor, "CREATE_NOTICE", "Notice", row._id, null, row);
    return clean(row);
  });
}
// Phát hành thông báo với kiểm tra phiên bản.
export async function publishNotice(actor, id, data) {
  // PT7: Phát hành bản nháp để các role phù hợp bắt đầu nhìn thấy thông báo.
  return transaction(async (session) => {
    const row = await get(noticeRepository, id, session);
    checkVersion(row, data.version);
    if (row.status !== "DRAFT") fail(409, "Thông báo không còn là bản nháp");
    if (row.expires_at && row.expires_at <= new Date())
      fail(409, "Thông báo đã hết hạn");
    const before = clean(row);
    row.status = "PUBLISHED";
    row.published_at = new Date();
    await saveDocument(row, { session });
    await audit(
      session,
      actor,
      "PUBLISH_NOTICE",
      "Notice",
      row._id,
      before,
      row,
    );
    return clean(row);
  });
}
// Lấy thông báo đúng đối tượng và trạng thái.
export async function listNotices(actor, q) {
  if (actor.role !== "STAFF" && q.status && q.status !== "PUBLISHED")
    fail(403, "Chỉ được xem thông báo đã phát hành");
  const filter =
    actor.role === "STAFF"
      ? q.status
        ? { status: q.status }
        : {}
      : await visibleFilter(actor);
  const rows = await noticeRepository.find(filter, {
    sort: { published_at: -1, created_at: -1, _id: -1 },
    skip: (q.page - 1) * 20,
    limit: 20,
  });
  return { page: q.page, items: clean(rows) };
}
// Đọc thông báo nếu người dùng thuộc đối tượng nhận.
export async function getNotice(actor, id) {
  // TB6: Mở chi tiết cũng kiểm tra lại quyền xem, không đọc được thông báo ngoài đối tượng.
  const row =
    actor.role === "STAFF"
      ? await get(noticeRepository, id)
      : await noticeRepository.findOne({
          _id: id,
          ...(await visibleFilter(actor)),
        });
  if (!row) fail(404, "Không tìm thấy thông báo");
  return clean(row);
}
