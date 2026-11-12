import { Router } from "express";
import { roles } from "../../middlewares/auth.middleware.js";
import { validate, validateId } from "../../middlewares/validate.middleware.js";
import * as attendance from "./controllers/attendance.controller.js";
import { saveAttendanceSchema } from "./validators/attendance.validator.js";
import * as requests from "../shared/controllers/request.controller.js";
import * as schemas from "../shared/validators/request.validator.js";

// Khai báo điểm danh, duyệt nghỉ và yêu cầu của giảng viên.
export function lecturerRoutes() {
  const router = Router();
  router.param("id", validateId);
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
  router.patch(
    "/leave-requests/:id/decision",
    roles("LECTURER"),
    validate(schemas.reviewRequestSchema),
    requests.reviewRequest("leave"),
  );
  router.post(
    "/change-requests",
    roles("LECTURER"),
    validate(schemas.createChangeSchema),
    requests.createChange,
  );
  return router;
}
