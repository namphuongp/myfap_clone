import { Router } from "express";
import { validate } from "../../middlewares/validate.middleware.js";
import { loginLimiter } from "../../middlewares/rate-limit.middleware.js";
import * as auth from "./controllers/auth.controller.js";
import { loginSchema } from "./validators/auth.validator.js";
// Khai báo API đăng nhập và kiểm tra kết nối.
export function authRoutes() {
  const router = Router();
  router.get("/health", auth.health);
  // DN3: Giới hạn số lần thử và kiểm tra dữ liệu trước khi xác thực.
  router.post("/auth/login", loginLimiter(), validate(loginSchema), auth.login);
  return router;
}
