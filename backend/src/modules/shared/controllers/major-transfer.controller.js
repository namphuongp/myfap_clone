import * as service from "../services/major-transfer.service.js";

// Lấy các lựa chọn hợp lệ cho màn hình hiện tại.
export const options = async (_req, res) => res.json(await service.options());
// Tạo dữ liệu sau khi kiểm tra quyền và tính hợp lệ.
export const create = async (req, res) =>
  res.status(201).json(await service.create(req.user, req.validated.body));
// Lấy danh sách theo bộ lọc và phạm vi người dùng.
export const list = async (req, res) =>
  res.json(await service.list(req.user, req.validated.query));
// Lưu quyết định duyệt; chuyển ngành chỉ lên lịch từ kỳ tới.
export const review = async (req, res) =>
  res.json(await service.review(req.user, req.params.id, req.validated.body));
