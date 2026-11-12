export class ApiError extends Error {
  // Khởi tạo đối tượng và các phụ thuộc cần thiết.
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}
// Ném lỗi API với mã trạng thái rõ ràng.
export const fail = (status, message) => {
  throw new ApiError(status, message);
};
