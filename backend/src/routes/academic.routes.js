import { Router } from "express";
import { roles } from "../middlewares/auth.middleware.js";
import { validate, validateId } from "../middlewares/validate.middleware.js";
import * as sectionController from "../controllers/section.controller.js";
import * as sectionSchemas from "../validators/section.validator.js";
import * as enrollmentController from "../controllers/enrollment.controller.js";
import * as enrollmentSchemas from "../validators/enrollment.validator.js";
import * as sessionController from "../controllers/session.controller.js";
import * as sessionSchemas from "../validators/session.validator.js";
import * as attendanceController from "../controllers/attendance.controller.js";
import * as attendanceSchemas from "../validators/attendance.validator.js";
import * as reportController from "../controllers/report.controller.js";
import * as reportSchemas from "../validators/report.validator.js";
export function academicRoutes() {
  const router = Router();
  router.param("id", validateId);
  router.param("studentId", validateId);
  router.get(
    "/sections/available",
    roles("STUDENT", "STAFF"),
    validate(sectionSchemas.availableSectionsSchema, "query"),
    sectionController.availableSections,
  );
  router.get(
    "/sections",
    roles("STUDENT", "LECTURER", "STAFF"),
    sectionController.listSections,
  );
  router.post(
    "/sections",
    roles("STAFF"),
    validate(sectionSchemas.createSectionSchema, "body"),
    sectionController.createSection,
  );
  router.patch(
    "/sections/:id/status",
    roles("STAFF"),
    validate(sectionSchemas.setSectionStatusSchema, "body"),
    sectionController.setSectionStatus,
  );
  router.get(
    "/me/enrollments",
    roles("STUDENT"),
    enrollmentController.myEnrollments,
  );
  router.get(
    "/sections/:id/enrollments",
    roles("STUDENT", "LECTURER", "STAFF"),
    enrollmentController.listEnrollments,
  );
  router.post(
    "/sections/:id/enrollments",
    roles("STUDENT", "STAFF"),
    validate(enrollmentSchemas.registerStudentSchema, "body"),
    enrollmentController.registerStudent,
  );
  router.post(
    "/sections/:id/enrollments/:studentId/withdraw",
    roles("STUDENT", "STAFF"),
    validate(enrollmentSchemas.withdrawStudentSchema, "body"),
    enrollmentController.withdrawStudent,
  );
  router.get(
    "/schedule",
    roles("STUDENT", "LECTURER", "STAFF"),
    validate(sessionSchemas.personalScheduleSchema, "query"),
    sessionController.personalSchedule,
  );
  router.get(
    "/sections/:id/sessions",
    roles("STUDENT", "LECTURER", "STAFF"),
    sessionController.sectionSessions,
  );
  router.post(
    "/sessions",
    roles("STAFF"),
    validate(sessionSchemas.createSessionSchema, "body"),
    sessionController.createSession,
  );
  router.patch(
    "/sessions/:id/schedule",
    roles("STAFF"),
    validate(sessionSchemas.changeScheduleSchema, "body"),
    sessionController.changeSchedule,
  );
  router.patch(
    "/sessions/:id/status",
    roles("STAFF"),
    validate(sessionSchemas.setSessionStatusSchema, "body"),
    sessionController.setSessionStatus,
  );
  router.get(
    "/sessions/:id/history",
    roles("LECTURER", "STAFF"),
    sessionController.sessionHistory,
  );
  router.get(
    "/sessions/:id/attendance-history",
    roles("LECTURER", "STAFF"),
    attendanceController.attendanceHistory,
  );
  router.get(
    "/sessions/:id/attendance",
    roles("STUDENT", "LECTURER", "STAFF"),
    attendanceController.getAttendance,
  );
  router.put(
    "/sessions/:id/attendance",
    roles("LECTURER"),
    validate(attendanceSchemas.saveAttendanceSchema, "body"),
    attendanceController.saveAttendance,
  );
  router.get(
    "/department/summary",
    roles("HEAD"),
    validate(reportSchemas.departmentSummarySchema, "query"),
    reportController.departmentSummary,
  );
  return router;
}
