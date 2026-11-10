import { Router } from "express";
import { roles } from "../middlewares/auth.middleware.js";
import { validate, validateId } from "../middlewares/validate.middleware.js";
import * as catalogController from "../controllers/catalog.controller.js";
import * as catalogSchemas from "../validators/catalog.validator.js";
export function catalogRoutes() {
  const router = Router();
  router.param("id", validateId);
  router.param("studentId", validateId);
  router.get(
    "/time-slots",
    roles("STUDENT", "LECTURER", "STAFF"),
    catalogController.timeSlots,
  );
  for (const kind of ["departments", "courses", "semesters", "rooms"]) {
    router.get(
      `/${kind}`,
      roles(
        ...(kind === "rooms"
          ? ["STUDENT", "LECTURER", "HEAD", "STAFF"]
          : ["STUDENT", "LECTURER", "HEAD", "STAFF"]),
      ),
      catalogController.listCatalog(kind),
    );
  }
  for (const kind of ["departments", "courses", "semesters", "rooms"]) {
    router.post(
      `/${kind}`,
      roles("STAFF"),
      validate(catalogSchemas.catalogSchemas[kind], "body"),
      catalogController.createCatalog(kind),
    );
  }
  router.post(
    "/users",
    roles("STAFF"),
    validate(catalogSchemas.createUserSchema, "body"),
    catalogController.createUser,
  );
  return router;
}
