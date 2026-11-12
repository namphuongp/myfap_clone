import { rateLimit } from "express-rate-limit";
// Giới hạn tần suất gọi API.
export const apiLimiter = () =>
  rateLimit({
    windowMs: 60000,
    limit: 300,
    standardHeaders: "draft-8",
    legacyHeaders: false,
    message: { message: "Quá nhiều yêu cầu, hãy thử lại" },
  });
// Giới hạn số lần thử đăng nhập.
export const loginLimiter = () =>
  rateLimit({
    windowMs: 900000,
    limit: 20,
    legacyHeaders: false,
    message: { message: "Thử đăng nhập quá nhiều lần" },
  });
