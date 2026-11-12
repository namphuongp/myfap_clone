import { rateLimit } from "express-rate-limit";
export const apiLimiter = () =>
  rateLimit({
    windowMs: 60000,
    limit: 300,
    skip: (req) => req.method === "POST" && req.path === "/auth/login",
    standardHeaders: "draft-8",
    legacyHeaders: false,
    message: { message: "Quá nhiều yêu cầu, hãy thử lại" },
  });
