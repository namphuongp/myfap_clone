import { ApiError } from "../utils/api-error.js";
import { resolveSession } from "../modules/auth/services/auth.service.js";
// Chỉ cho phép các role được khai báo truy cập.
export const roles =
  (...allowed) =>
  (req, res, next) =>
    allowed.includes(req.user.role)
      ? next()
      : next(new ApiError(403, "Không có quyền"));
// Xác thực người dùng trước khi xử lý API.
export async function authenticate(req, res, next) {
  try {
    const bearer = req.headers.authorization?.match(
      /^Bearer ([a-f\d]{64})$/i,
    )?.[1];
    const { user, auth } = await resolveSession(bearer);
    req.user = user;
    req.auth = auth;
    next();
  } catch (error) {
    next(error);
  }
}
