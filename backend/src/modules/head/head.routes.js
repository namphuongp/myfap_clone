import { Router } from "express";
import { roles } from "../../middlewares/auth.middleware.js";
import { validate, validateId } from "../../middlewares/validate.middleware.js";
import * as lecturers from "./controllers/head-lecturer.controller.js";
import { options } from "./controllers/head.controller.js";
import * as lecturerSchemas from "./validators/head-lecturer.validator.js";
import * as reports from "./controllers/report.controller.js";
import * as reportSchemas from "./validators/report.validator.js";
import * as sections from "../shared/controllers/section.controller.js";
import { createSectionSchema } from "../shared/validators/section.validator.js";

export function headRoutes(){const router=Router();router.param("id",validateId);
router.get("/head/lecturers",roles("HEAD"),validate(lecturerSchemas.listLecturersSchema,"query"),lecturers.list);
router.get("/head/lecturers/:id",roles("HEAD"),lecturers.detail);
router.post("/head/lecturers",roles("HEAD"),validate(lecturerSchemas.createLecturerSchema),lecturers.create);
router.patch("/head/lecturers/:id",roles("HEAD"),validate(lecturerSchemas.updateLecturerSchema),lecturers.update);
router.get("/head/options",roles("HEAD"),options);
router.get("/reports/attendance",roles("HEAD"),validate(reportSchemas.attendanceReportSchema,"query"),reports.attendanceReport);
router.get("/department/summary",roles("HEAD"),validate(reportSchemas.departmentSummarySchema,"query"),reports.departmentSummary);
router.post("/sections",roles("HEAD"),validate(createSectionSchema),sections.createSection);
return router;}
