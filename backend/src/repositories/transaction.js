import mongoose from "mongoose";
import { Lock } from "../models/index.js";
import { fail } from "../utils/api-error.js";
// Khóa chung giữ kiểm tra lịch/chỗ trống và ghi dữ liệu trong cùng transaction.
export async function transaction(work) {
  const session = await mongoose.startSession();
  try {
    return await session.withTransaction(async () => {
      const lock = await Lock.findOneAndUpdate(
        { _id: "academic" },
        { $inc: { revision: 1 } },
        { session, returnDocument: "after" },
      );
      if (!lock) fail(503, "Cần chạy npm run db:init");
      // Callback phải đọc/tạo document lại để retry không dùng trạng thái cũ.
      return work(session);
    });
  } finally {
    await session.endSession();
  }
}
