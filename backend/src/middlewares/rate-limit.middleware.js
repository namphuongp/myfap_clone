import { rateLimit } from "express-rate-limit";
export const apiLimiter = () =>
  rateLimit({
    windowMs: 60000,
    limit: 300,
    standardHeaders: "draft-8",
    legacyHeaders: false,
    message: { message: "Quá nhiều yêu cầu, hãy thử lại" },
  });
export const loginLimiter = () =>
  rateLimit({
    windowMs: 900000,
    limit: 20,
    legacyHeaders: false,
    message: { message: "Thử đăng nhập quá nhiều lần" },
  });
