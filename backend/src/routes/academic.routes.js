import { Router } from "express";
import { roles } from "../middlewares/auth.middleware.js";
import { validate, validateId } from "../middlewares/validate.middleware.js";
import * as sections from "../controllers/section.controller.js";
import * as sectionSchemas from "../validators/section.validator.js";
import * as enrollment from "../controllers/enrollment.controller.js";
import * as enrollmentSchemas from "../validators/enrollment.validator.js";
import * as sessions from "../controllers/session.controller.js";
import { personalScheduleSchema } from "../validators/session.validator.js";
import * as attendance from "../controllers/attendance.controller.js";
import { saveAttendanceSchema } from "../validators/attendance.validator.js";
import * as reports from "../controllers/report.controller.js";
import { departmentSummarySchema } from "../validators/report.validator.js";
import * as assignment from "../controllers/assignment.controller.js";
import { assignSessionsSchema } from "../validators/assignment.validator.js";
export function academicRoutes() {
  const router = Router();
  router.param("id", validateId);
  router.param("studentId", validateId);
  router.get("/lecturers", roles("HEAD"), assignment.listLecturers);
  router.get(
    "/sections/available",
    roles("STUDENT"),
    validate(sectionSchemas.availableSectionsSchema, "query"),
    sections.availableSections,
  );
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
  router.patch(
    "/sections/:id/status",
    roles("HEAD"),
    validate(sectionSchemas.setSectionStatusSchema),
    sections.setSectionStatus,
  );
  router.put(
    "/sections/:id/assignments",
    roles("HEAD"),
    validate(assignSessionsSchema),
    assignment.assignSessions,
  );
  router.get("/me/enrollments", roles("STUDENT"), enrollment.myEnrollments);
  router.post(
    "/sections/:id/enrollments",
    roles("STUDENT"),
    validate(enrollmentSchemas.registerStudentSchema),
    enrollment.registerStudent,
  );
  router.post(
    "/sections/:id/enrollments/:studentId/withdraw",
    roles("STUDENT"),
    validate(enrollmentSchemas.withdrawStudentSchema),
    enrollment.withdrawStudent,
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
