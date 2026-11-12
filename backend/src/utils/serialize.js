import mongoose from "mongoose";
// Chuyển document thành JSON và loại thông tin nhạy cảm.
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
