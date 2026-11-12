import * as service from "../services/head-lecturer.service.js";
// Lấy danh sách theo bộ lọc và phạm vi người dùng.
export const list = async (req, res) =>
  res.json(await service.list(req.user, req.validated.query));
// Lấy chi tiết trong phạm vi được phép.
export const detail = async (req, res) =>
  res.json(await service.detail(req.user, req.params.id));
// Tạo dữ liệu sau khi kiểm tra quyền và tính hợp lệ.
export const create = async (req, res) =>
  res.status(201).json(await service.create(req.user, req.validated.body));
// Cập nhật dữ liệu có kiểm tra phiên bản.
export const update = async (req, res) =>
  res.json(await service.update(req.user, req.params.id, req.validated.body));
