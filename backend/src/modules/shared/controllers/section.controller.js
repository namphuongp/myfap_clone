import * as service from "../services/section.service.js";
// Lấy lớp học phần trong phạm vi được phép.
export const listSections = async (req, res) => {
  const result = await service.listSections(req.user, req.validated.query);
  res.json(result);
};
// Tạo lớp học phần; chưa bắt buộc có giảng viên.
export const createSection = async (req, res) => {
  // TL2: Chuyển tài khoản HEAD và dữ liệu lớp đã kiểm tra sang service.
  const result = await service.createSection(req.user, req.validated.body);
  res.status(201).json(result);
};
