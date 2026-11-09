import mongoose from "mongoose";
import { z } from "zod";
import { createHash, randomBytes } from "node:crypto";
import {
  User,
  AuthSession,
  Audit,
  Lock,
  Enrollment,
  Section,
} from "./models.js";
export class ApiError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}
export const fail = (status, message) => {
  throw new ApiError(status, message);
};
export const id = z
  .string()
  .regex(/^[a-f\d]{24}$/i, "ID phải là MongoDB ObjectId")
  .transform((value) => value.toLowerCase());
export const version = z.number().int().nonnegative();
export const text = z.string().trim().min(1).max(1000);
export const date = z.iso
  .datetime({ offset: true })
  .transform((v) => new Date(v));
export const body = (fields) => z.strictObject(fields);
export const parse = (schema, value) => schema.parse(value);
export const hash = (value) => createHash("sha256").update(value).digest("hex");
export const token = () => randomBytes(32).toString("hex");
export const same = (a, b) => String(a) === String(b);
export const roles =
  (...allowed) =>
  (req, res, next) =>
    allowed.includes(req.user.role)
      ? next()
      : next(new ApiError(403, "Không có quyền"));
export const checkVersion = (row, expected) => {
  if (row.version !== expected) fail(409, "Dữ liệu đã thay đổi, hãy tải lại");
};
export async function get(Model, key, session) {
  const row = await Model.findById(key).session(session ?? null);
  if (!row) fail(404, "Không tìm thấy dữ liệu");
  return row;
}
export function clean(value) {
  if (value == null) return value;
  if (value instanceof Date) return value;
  if (value instanceof mongoose.Types.ObjectId) return String(value);
  if (Array.isArray(value)) return value.map(clean);
  if (typeof value !== "object") return value;
  const raw = typeof value.toObject === "function" ? value.toObject() : value;
  const out = {};
  for (const [key, v] of Object.entries(raw)) {
    if (/password|token_hash/i.test(key)) continue;
    out[key === "_id" ? "id" : key] = clean(v);
  }
  return out;
}
export async function audit(
  session,
  user,
  action,
  entity,
  key,
  before = null,
  after = null,
) {
  await Audit.create(
    [
      {
        actor_id: user._id,
        action,
        entity,
        entity_id: key,
        before_data: clean(before),
        after_data: clean(after),
      },
    ],
    { session },
  );
}
// Một khóa ghi trong transaction bảo vệ kiểm tra lịch và chỗ trống qua nhiều collection.
export async function transaction(work) {
  const session = await mongoose.startSession();
  try {
    // Tạo/đọc document bên trong callback để mỗi lần retry lấy lại trạng thái mới.
    return await session.withTransaction(async () => {
      const lock = await Lock.findOneAndUpdate(
        { _id: "academic" },
        { $inc: { revision: 1 } },
        { session, returnDocument: "after" },
      );
      if (!lock) fail(503, "Cần chạy npm run db:init");
      return work(session);
    });
  } finally {
    await session.endSession();
  }
}
export async function authenticate(req, res, next) {
  try {
    const bearer = req.headers.authorization?.match(
      /^Bearer ([a-f\d]{64})$/i,
    )?.[1];
    if (!bearer) fail(401, "Cần đăng nhập");
    const auth = await AuthSession.findOne({
      token_hash: hash(bearer),
      expires_at: { $gt: new Date() },
    });
    if (!auth) fail(401, "Phiên đã hết hạn");
    const user = await User.findOne({ _id: auth.user_id, active: true });
    if (!user) fail(401, "Phiên không hợp lệ");
    req.user = user;
    req.auth = auth;
    next();
  } catch (error) {
    next(error);
  }
}
export async function sectionFilter(user) {
  if (user.role === "HEAD") return { department_id: user.department_id };
  if (user.role === "LECTURER") return { lecturer_id: user._id };
  if (user.role === "STUDENT") {
    const ids = await Enrollment.distinct("section_id", {
      student_id: user._id,
    });
    return { _id: { $in: ids } };
  }
  return {};
}
export async function scopedSectionIds(user) {
  return Section.distinct("_id", await sectionFilter(user));
}
export async function authorizeSection(section, user, session) {
  if (
    (user.role === "HEAD" &&
      !same(section.department_id, user.department_id)) ||
    (user.role === "LECTURER" && !same(section.lecturer_id, user._id))
  )
    fail(403, "Ngoài phạm vi truy cập");
  if (
    user.role === "STUDENT" &&
    !(await Enrollment.findOne({
      section_id: section._id,
      student_id: user._id,
    }).session(session ?? null))
  )
    fail(403, "Không thuộc lớp");
}
