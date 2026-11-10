import { Router } from "express";
import { roles } from "../middlewares/auth.middleware.js";
import { validate, validateId } from "../middlewares/validate.middleware.js";
import * as controller from "../controllers/catalog.controller.js";
import {
  createCourseSchema,
  updateCourseSchema,
} from "../validators/catalog.validator.js";
export function catalogRoutes() {
  const router = Router();
  router.param("id", validateId);
  router.get(
    "/time-slots",
    roles("STUDENT", "LECTURER", "HEAD", "STAFF"),
    controller.timeSlots,
  );
  for (const kind of ["courses", "semesters", "rooms"])
    router.get(`/${kind}`, controller.listCatalog(kind));
  router.get("/majors", roles("HEAD"), controller.listMajors);
  router.post(
    "/courses",
    roles("HEAD"),
    validate(createCourseSchema),
    controller.createCourse,
  );
  router.patch(
    "/courses/:id",
    roles("HEAD"),
    validate(updateCourseSchema),
    controller.updateCourse,
  );
  return router;
}
