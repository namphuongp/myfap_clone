import * as service from "../services/head.service.js";
// Lấy các lựa chọn hợp lệ cho màn hình hiện tại.
export const options = async (req, res) =>
  res.json(await service.options(req.user));
