import { fail } from "./api-error.js";
// Ngăn ghi đè dữ liệu đã được người khác cập nhật.
export const checkVersion = (row, expected) => {
  if (row.version !== expected) fail(409, "Dữ liệu đã thay đổi, hãy tải lại");
};
