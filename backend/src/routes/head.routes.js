import { Router } from "express";
import { roles } from "../middlewares/auth.middleware.js";
import { validate, validateId } from "../middlewares/validate.middleware.js";
import * as schemas from "../validators/head.validator.js";
import * as controller from "../controllers/head.controller.js";
export function headRoutes() {
  const router = Router();
  router.use("/head", roles("HEAD"));
  router.param("id", validateId);
  router.get("/head/options", controller.options);
  router.get(
    "/head/courses",
    validate(schemas.list, "query"),
    controller.courses,
  );
  router.post(
    "/head/courses",
    validate(schemas.courseCreate),
    controller.createCourse,
  );
  router.patch(
    "/head/courses/:id",
    validate(schemas.courseUpdate),
    controller.updateCourse,
  );
  router.get(
    "/head/sections",
    validate(schemas.list, "query"),
    controller.sections,
  );
  router.patch(
    "/head/sections/:id/lecturer",
    validate(schemas.assign),
    controller.assignLecturer,
  );
  return router;
}
