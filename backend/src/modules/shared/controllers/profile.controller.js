import * as service from "../services/profile.service.js";
// Trả thông tin hồ sơ chỉ đọc của người đăng nhập.
export const getProfile = async (req, res) =>
  res.json(await service.getProfile(req.user));
