import { createHash, randomBytes } from "node:crypto";
// Băm token trước khi lưu vào database.
export const hash = (value) => createHash("sha256").update(value).digest("hex");
// Tạo token đăng nhập ngẫu nhiên an toàn.
export const token = () => randomBytes(32).toString("hex");
