import { Router } from "express";
import { roles } from "../middlewares/auth.middleware.js";
import { validate, validateId } from "../middlewares/validate.middleware.js";
import * as controller from "../controllers/request.controller.js";
import * as schemas from "../validators/request.validator.js";
export function requestRoutes() {
  const router = Router();
  router.param("id", validateId);
  router.post(
    "/leave-requests",
    roles("STUDENT"),
    validate(schemas.createLeaveSchema),
    controller.createLeave,
  );
  router.post(
    "/change-requests",
    roles("LECTURER"),
    validate(schemas.createChangeSchema),
    controller.createChange,
  );
  for (const [kind, path, reviewer] of [
    ["leave", "leave-requests", "LECTURER"],
    ["change", "change-requests", "STAFF"],
  ]) {
    const readPolicy =
      kind === "change"
        ? [roles("LECTURER", "STAFF")]
        : [roles("STUDENT", "LECTURER")];
    router.get(
      `/${path}`,
      ...readPolicy,
      validate(schemas.listRequestsSchema(kind), "query"),
      controller.listRequests(kind),
    );
    router.patch(
      `/${path}/:id/decision`,
      roles(reviewer),
      validate(schemas.reviewRequestSchema),
      controller.reviewRequest(kind),
    );
  }
  return router;
}
