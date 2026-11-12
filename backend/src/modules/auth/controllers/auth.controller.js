import * as service from "../services/auth.service.js";
// Kiểm tra kết nối database.
export const health = async (req, res) => {
  const result = await service.health();
  res.json(result);
};
// Xác thực tài khoản và tạo phiên đăng nhập.
export const login = async (req, res) => {
  const result = await service.login(req.validated.body);
  res.json(result);
};

// Thu hồi phiên đăng nhập hiện tại.
export const logout = async (req, res) => {
  await service.logout(req.auth);
  res.status(204).end();
};
