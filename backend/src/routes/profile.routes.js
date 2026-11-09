import { Router } from "express";
import { rateLimit } from "express-rate-limit";
import { validate } from "../middlewares/validate.middleware.js";
import * as schemas from "../validators/profile.validator.js";
import * as controller from "../controllers/profile.controller.js";
export function profileRoutes() {
  const router = Router();
  router.get("/profile", controller.getProfile);
  router.patch(
    "/profile",
    validate(schemas.updateProfileSchema),
    controller.updateProfile,
  );
  router.patch(
    "/profile/password",
    rateLimit({
      windowMs: 900000,
      limit: 10,
      legacyHeaders: false,
      message: { message: "Thử đổi mật khẩu quá nhiều lần" },
    }),
    validate(schemas.changePasswordSchema),
    controller.changePassword,
  );
  return router;
}
