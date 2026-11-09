import { Router } from "express";

import { validate, validateId } from "../middlewares/validate.middleware.js";
import * as authController from "../controllers/auth.controller.js";
import * as authSchemas from "../validators/auth.validator.js";
import { loginLimiter } from "../middlewares/rate-limit.middleware.js";
export function authRoutes() {
  const router = Router();
  router.param("id", validateId);
  router.param("studentId", validateId);
  router.get("/health", authController.health);
  router.post(
    "/auth/login",
    loginLimiter(),
    validate(authSchemas.loginSchema, "body"),
    authController.login,
  );
  return router;
}
export function sessionRoutes() {
  const router = Router();
  router.get("/auth/me", authController.me);
  router.post("/auth/logout", authController.logout);
  return router;
}
