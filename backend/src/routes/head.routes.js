import { Router } from "express";
import { roles } from "../middlewares/auth.middleware.js";
import { options } from "../controllers/head.controller.js";
import { validate, validateId } from "../middlewares/validate.middleware.js";
import * as lecturers from "../controllers/head-lecturer.controller.js";
import * as schemas from "../validators/head-lecturer.validator.js";
export function headRoutes() {
  const router = Router();
  router.param("id", validateId);
  router.get(
    "/head/lecturers",
    roles("HEAD"),
    validate(schemas.listLecturersSchema, "query"),
    lecturers.list,
  );
  router.get("/head/lecturers/:id", roles("HEAD"), lecturers.detail);
  router.post(
    "/head/lecturers",
    roles("HEAD"),
    validate(schemas.createLecturerSchema),
    lecturers.create,
  );
  router.patch(
    "/head/lecturers/:id",
    roles("HEAD"),
    validate(schemas.updateLecturerSchema),
    lecturers.update,
  );
  router.get("/head/options", roles("HEAD"), options);
  return router;
}
