import { Router } from "express";
import { roles } from "../middlewares/auth.middleware.js";
import { validate, validateId } from "../middlewares/validate.middleware.js";
import * as schemas from "../validators/major.validator.js";
import * as controller from "../controllers/major.controller.js";
export function majorRoutes() {
  const router = Router();
  router.param("id", validateId);
  router.get("/majors", roles("STUDENT", "STAFF"), controller.listMajors);
  router.post(
    "/majors",
    roles("STAFF"),
    validate(schemas.createMajorSchema),
    controller.createMajor,
  );
  router.patch(
    "/majors/:id/curriculum",
    roles("STAFF"),
    validate(schemas.curriculumSchema),
    controller.updateCurriculum,
  );
  router.patch(
    "/users/:id/major",
    roles("STAFF"),
    validate(schemas.initialMajorSchema),
    controller.assignInitialMajor,
  );
  router.post(
    "/major-transfer-requests",
    roles("STUDENT"),
    validate(schemas.createTransferSchema),
    controller.createTransfer,
  );
  router.get(
    "/major-transfer-requests",
    roles("STUDENT", "STAFF"),
    validate(schemas.listTransfersSchema, "query"),
    controller.listTransfers,
  );
  router.patch(
    "/major-transfer-requests/:id/decision",
    roles("STAFF"),
    validate(schemas.decisionSchema),
    controller.decideTransfer,
  );
  router.post(
    "/major-transfer-requests/:id/cancel",
    roles("STUDENT"),
    validate(schemas.cancelTransferSchema),
    controller.cancelTransfer,
  );
  return router;
}
