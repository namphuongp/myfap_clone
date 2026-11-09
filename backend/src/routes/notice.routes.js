import { Router } from "express";
import { roles } from "../middlewares/auth.middleware.js";
import { validate, validateId } from "../middlewares/validate.middleware.js";
import * as schemas from "../validators/notice.validator.js";
import * as controller from "../controllers/notice.controller.js";
export function noticeRoutes() {
  const router = Router();
  router.param("id", validateId);
  router.get(
    "/notices",
    roles("STUDENT", "STAFF"),
    validate(schemas.listNoticesSchema, "query"),
    controller.listNotices,
  );
  router.get("/notices/:id", roles("STUDENT", "STAFF"), controller.getNotice);
  router.post(
    "/notices",
    roles("STAFF"),
    validate(schemas.createNoticeSchema),
    controller.createNotice,
  );
  router.patch(
    "/notices/:id",
    roles("STAFF"),
    validate(schemas.updateNoticeSchema),
    controller.updateNotice,
  );
  router.post(
    "/notices/:id/publish",
    roles("STAFF"),
    validate(schemas.noticeActionSchema),
    controller.publishNotice,
  );
  router.post(
    "/notices/:id/archive",
    roles("STAFF"),
    validate(schemas.noticeActionSchema),
    controller.archiveNotice,
  );
  router.post("/notices/:id/read", roles("STUDENT"), controller.markRead);
  return router;
}
