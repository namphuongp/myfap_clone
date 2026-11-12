import { Router } from "express";
import { roles } from "../middlewares/auth.middleware.js";
import { validate, validateId } from "../middlewares/validate.middleware.js";
import * as controller from "../controllers/major-transfer.controller.js";
import * as schemas from "../validators/major-transfer.validator.js";

export function majorTransferRoutes() {
  const router = Router();
  router.param("id", validateId);
  router.get("/major-transfer-options", roles("STUDENT"), controller.options);
  router.post(
    "/major-transfer-requests",
    roles("STUDENT"),
    validate(schemas.createSchema),
    controller.create,
  );
  router.get(
    "/major-transfer-requests",
    roles("STUDENT", "STAFF"),
    validate(schemas.listSchema, "query"),
    controller.list,
  );
  router.patch(
    "/major-transfer-requests/:id/decision",
    roles("STAFF"),
    validate(schemas.reviewSchema),
    controller.review,
  );
  return router;
}
