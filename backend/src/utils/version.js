import { fail } from "./api-error.js";
export const checkVersion = (row, expected) => {
  if (row.version !== expected) fail(409, "Dữ liệu đã thay đổi, hãy tải lại");
};
