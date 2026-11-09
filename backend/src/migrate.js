import { readFile } from "node:fs/promises";
import { db } from "./db.js";
try {
  if (await db.schema.hasTable("users"))
    throw new Error(
      "Database đã có bảng users. Không tự ghi đè schema đang có.",
    );
  const sql = await readFile(new URL("../schema.sql", import.meta.url), "utf8");
  // DDL MySQL tự commit; script cố ý chỉ dành cho database trống, không tự xóa bảng khi lỗi.
  for (const statement of sql
    .split(";")
    .map((s) => s.trim())
    .filter(Boolean))
    await db.raw(statement);
  console.log("Đã tạo schema MyFAP");
} finally {
  await db.destroy();
}
