import { ApiError } from "../utils/api-error.js";
import { resolveSession } from "../services/auth.service.js";
export const roles =
  (...allowed) =>
  (req, res, next) =>
    allowed.includes(req.user.role)
      ? next()
      : next(new ApiError(403, "Không có quyền"));
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
