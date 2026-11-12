import mongoose from "mongoose";
// So sánh ID an toàn khi dữ liệu có kiểu khác nhau.
export const same = (a, b) => String(a) === String(b);
// Tạo ID MongoDB cho bản ghi mới.
export const newId = () => new mongoose.Types.ObjectId();
