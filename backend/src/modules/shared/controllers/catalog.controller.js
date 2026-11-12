import * as service from "../services/catalog.service.js";
// Trả bốn khung giờ học cố định.
export const timeSlots = async (req, res) =>
  res.json(await service.timeSlots());
// Lấy danh mục dùng chung theo phạm vi người dùng.
export const listCatalog = (kind) => async (req, res) =>
  res.json(await service.listCatalog(kind, req.user));
