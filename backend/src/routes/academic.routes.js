import { Router } from "express";
import { roles } from "../middlewares/auth.middleware.js";
import { validate, validateId } from "../middlewares/validate.middleware.js";
import * as sections from "../controllers/section.controller.js";
import * as sectionSchemas from "../validators/section.validator.js";
import * as sessions from "../controllers/session.controller.js";
import { personalScheduleSchema } from "../validators/session.validator.js";
import * as attendance from "../controllers/attendance.controller.js";
import { saveAttendanceSchema } from "../validators/attendance.validator.js";
import * as reports from "../controllers/report.controller.js";
import { departmentSummarySchema } from "../validators/report.validator.js";
export function academicRoutes() {
  const router = Router();
  router.param("id", validateId);
  router.get(
    "/sections",
    roles("STUDENT", "LECTURER", "HEAD"),
    validate(sectionSchemas.listSectionsSchema, "query"),
    sections.listSections,
  );
  router.post(
    "/sections",
    roles("HEAD"),
    validate(sectionSchemas.createSectionSchema),
    sections.createSection,
  );
  router.get(
    "/schedule",
    roles("STUDENT", "LECTURER"),
    validate(personalScheduleSchema, "query"),
    sessions.personalSchedule,
  );
  router.get(
    "/sections/:id/sessions",
    roles("STUDENT", "LECTURER", "HEAD"),
    sessions.sectionSessions,
  );
  router.get(
    "/sessions/:id/attendance",
    roles("LECTURER"),
    attendance.getAttendance,
  );
  router.put(
    "/sessions/:id/attendance",
    roles("LECTURER"),
    validate(saveAttendanceSchema),
    attendance.saveAttendance,
  );
  router.get(
    "/department/summary",
    roles("HEAD"),
    validate(departmentSummarySchema, "query"),
    reports.departmentSummary,
  );
  return router;
}
