import { z } from "zod";
import { createHash, randomBytes } from "node:crypto";
import { db } from "./db.js";
export class ApiError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}
export function fail(status, message) {
  throw new ApiError(status, message);
}
export const id = z.coerce.number().int().positive().max(2147483647);
export const version = z.number().int().nonnegative();
export const text = z.string().trim().min(1).max(1000);
export const date = z.iso
  .datetime({ offset: true })
  .transform((v) => new Date(v));
export const body = (fields) => z.strictObject(fields);
export const parse = (schema, value) => schema.parse(value);
export const hash = (value) => createHash("sha256").update(value).digest("hex");
export const token = () => randomBytes(32).toString("hex");
export const roles =
  (...allowed) =>
  (req, res, next) =>
    allowed.includes(req.user.role)
      ? next()
      : next(new ApiError(403, "Không có quyền"));
export async function get(table, key, trx = db) {
  const row = await trx(table).where({ id: key }).first();
  if (!row) fail(404, "Không tìm thấy dữ liệu");
  return row;
}
export function checkVersion(row, expected) {
  if (row.version !== expected) fail(409, "Dữ liệu đã thay đổi, hãy tải lại");
}
export async function authenticate(req, res, next) {
  try {
    const bearer = req.headers.authorization?.match(
      /^Bearer ([a-f\d]{64})$/i,
    )?.[1];
    if (!bearer) fail(401, "Cần đăng nhập");
    const session = await db("auth_sessions")
      .where({ token_hash: hash(bearer) })
      .where("expires_at", ">", new Date())
      .first();
    if (!session) fail(401, "Phiên đã hết hạn");
    const user = await db("users")
      .select("id", "name", "email", "role", "department", "active")
      .where({ id: session.user_id, active: true })
      .first();
    if (!user) fail(401, "Phiên không hợp lệ");
    req.user = user;
    req.auth = session;
    next();
  } catch (error) {
    next(error);
  }
}
export async function audit(trx, user, action, table, key) {
  await trx("audit_logs").insert({
    actor_id: user.id,
    action,
    entity: table,
    entity_id: key,
  });
}
// Khóa lịch dùng chung: kiểm tra xung đột và ghi thay đổi nằm trong cùng transaction.
export async function academicTransaction(work) {
  return db.transaction(async (trx) => {
    await trx("academic_lock").where({ id: 1 }).forUpdate().first();
    return work(trx);
  });
}
export function sectionScope(query, user, alias = "s") {
  if (user.role === "STUDENT")
    query.whereExists(
      db("enrollments as e")
        .select(db.raw("1"))
        .whereColumn("e.section_id", `${alias}.id`)
        .where("e.student_id", user.id),
    );
  if (user.role === "LECTURER") query.where(`${alias}.lecturer_id`, user.id);
  if (user.role === "HEAD") query.where(`${alias}.department`, user.department);
  return query;
}
export async function authorizeSection(section, user, trx = db) {
  if (
    (user.role === "LECTURER" && section.lecturer_id !== user.id) ||
    (user.role === "HEAD" && section.department !== user.department)
  )
    fail(403, "Ngoài phạm vi truy cập");
  if (
    user.role === "STUDENT" &&
    !(await trx("enrollments")
      .where({ section_id: section.id, student_id: user.id })
      .first())
  )
    fail(403, "Không thuộc lớp");
}
