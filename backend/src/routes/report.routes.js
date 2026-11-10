import { Router } from "express";
import { roles } from "../middlewares/auth.middleware.js";
import { validate } from "../middlewares/validate.middleware.js";
import * as schema from "../validators/report.validator.js";
import * as controller from "../controllers/report.controller.js";
export function reportRoutes() {
  const router = Router();
  router.get(
    "/reports/attendance",
    roles("HEAD"),
    validate(schema.attendanceReportSchema, "query"),
    controller.attendanceReport,
  );
  return router;
}
