import { Router } from "express";
import { roles } from "../middlewares/auth.middleware.js";
import * as controller from "../controllers/catalog.controller.js";
export function catalogRoutes() {
  const router = Router();
  router.get(
    "/time-slots",
    roles("STUDENT", "LECTURER", "HEAD", "STAFF"),
    controller.timeSlots,
  );
  for (const kind of ["courses", "semesters", "rooms"])
    router.get(`/${kind}`, controller.listCatalog(kind));
  return router;
}
