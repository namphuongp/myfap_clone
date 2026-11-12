import bcrypt from "bcryptjs";
import {
  userRepository,
  classSessionRepository,
  authSessionRepository,
} from "../../../repositories/index.js";
import { transaction } from "../../../repositories/transaction.js";
import { saveDocument } from "../../../repositories/base.repository.js";
import { checkVersion } from "../../../utils/version.js";
import { fail } from "../../../utils/api-error.js";
import { clean } from "../../../utils/serialize.js";
import { audit } from "../../shared/services/audit.service.js";
// Giới hạn dữ liệu theo bộ môn của trưởng bộ môn.
const scope = (actor) => ({
  department_id: actor.department_id,
  role: "LECTURER",
});
// Thoát ký tự đặc biệt trước khi tìm kiếm bằng biểu thức chính quy.
const literal = (value) =>
  value
    .split("")
    .map((c) =>
      "\\^$.*+?()[]{}|".includes(c) ? String.fromCharCode(92) + c : c,
    )
    .join("");
// Chuyển dữ liệu thành cấu trúc trả về API.
function dto(row) {
  const data = clean(row);
  return Object.fromEntries(
    [
      "id",
      "version",
      "user_code",
      "name",
      "email",
      "phone",
      "address",
      "active",
      "department_id",
      "created_at",
      "updated_at",
    ].map((k) => [k, data[k]]),
  );
}
// Tìm danh sách theo bộ lọc nội bộ.
async function find(actor, id, session) {
  const row = await userRepository.findOne(
    { ...scope(actor), _id: id },
    { session },
  );
  if (!row) fail(404, "Không tìm thấy giảng viên trong bộ môn");
  return row;
}
// Lấy danh sách theo bộ lọc và phạm vi người dùng.
export async function list(actor, q) {
  const filter = scope(actor);
  if (q.status !== "ALL") filter.active = q.status === "ACTIVE";
  if (q.search) {
    const re = { $regex: literal(q.search), $options: "i" };
    filter.$or = [{ name: re }, { email: re }, { user_code: re }];
  }
  const [rows, total] = await Promise.all([
    userRepository.find(filter, {
      sort: { name: 1, _id: 1 },
      skip: (q.page - 1) * 50,
      limit: 50,
    }),
    userRepository.countDocuments(filter),
  ]);
  return {
    page: q.page,
    total,
    has_more: q.page * 50 < total,
    items: rows.map(dto),
  };
}
// Lấy chi tiết trong phạm vi được phép.
export async function detail(actor, id) {
  const row = await find(actor, id);
  const [total, upcoming, completed] = await Promise.all([
    classSessionRepository.countDocuments({ lecturer_id: row._id }),
    classSessionRepository.countDocuments({
      lecturer_id: row._id,
      status: "SCHEDULED",
      end_at: { $gt: new Date() },
    }),
    classSessionRepository.countDocuments({
      lecturer_id: row._id,
      status: "COMPLETED",
    }),
  ]);
  return {
    ...dto(row),
    teaching: {
      total_sessions: total,
      upcoming_sessions: upcoming,
      completed_sessions: completed,
    },
  };
}
// Tạo dữ liệu sau khi kiểm tra quyền và tính hợp lệ.
export async function create(actor, data) {
  // GV4: Tạo tài khoản giảng viên trong đúng bộ môn, băm mật khẩu và ghi audit.
  const { password, ...fields } = data;
  const password_hash = await bcrypt.hash(password, 12);
  return transaction(async (session) => {
    const row = await userRepository.create(
      {
        ...fields,
        password_hash,
        role: "LECTURER",
        department_id: actor.department_id,
        active: true,
      },
      { session },
    );
    const result = dto(row);
    await audit(
      session,
      actor,
      "HEAD_CREATE_LECTURER",
      "User",
      row._id,
      null,
      result,
    );
    return result;
  });
}
// Cập nhật dữ liệu có kiểm tra phiên bản.
export async function update(actor, id, data) {
  // GV5: Chỉ sửa giảng viên cùng bộ môn và kiểm tra version trước khi lưu.
  return transaction(async (session) => {
    const row = await find(actor, id, session);
    checkVersion(row, data.version);
    if (
      data.active === false &&
      (await classSessionRepository.exists(
        {
          lecturer_id: row._id,
          status: "SCHEDULED",
          end_at: { $gt: new Date() },
        },
        { session },
      ))
    )
      fail(
        409,
        "Giảng viên còn buổi dạy đang diễn ra hoặc sắp tới; cần hoàn tất lịch trước khi ngừng hoạt động",
      );
    const before = dto(row);
    const revoke =
      data.active === false ||
      (data.email !== undefined && data.email !== row.email);
    for (const k of ["name", "email", "phone", "address", "active"])
      if (Object.hasOwn(data, k)) row[k] = data[k];
    await saveDocument(row, { session });
    if (revoke)
      await authSessionRepository.deleteMany({ user_id: row._id }, { session });
    const result = dto(row);
    await audit(
      session,
      actor,
      "HEAD_UPDATE_LECTURER",
      "User",
      row._id,
      before,
      result,
    );
    return result;
  });
}
