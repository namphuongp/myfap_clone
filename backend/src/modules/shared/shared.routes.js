import { Router } from "express";
import { roles } from "../../middlewares/auth.middleware.js";
import { validate, validateId } from "../../middlewares/validate.middleware.js";
import * as auth from "../auth/controllers/auth.controller.js";
import { getProfile } from "./controllers/profile.controller.js";
import * as catalog from "./controllers/catalog.controller.js";
import * as sections from "./controllers/section.controller.js";
import { listSectionsSchema } from "./validators/section.validator.js";
import * as sessions from "./controllers/session.controller.js";
import { personalScheduleSchema } from "./validators/session.validator.js";
import * as requests from "./controllers/request.controller.js";
import { listRequestsSchema } from "./validators/request.validator.js";
import * as transfers from "./controllers/major-transfer.controller.js";
import { listSchema } from "./validators/major-transfer.validator.js";
import * as notices from "../staff/controllers/notice.controller.js";
import { listNoticesSchema } from "../staff/validators/notice.validator.js";

// Khai báo API được dùng chung giữa các role.
export function sharedRoutes() {
  const router = Router();
  router.param("id", validateId);
  router.post("/auth/logout", auth.logout);
  router.get("/profile", getProfile);
  router.get("/time-slots", catalog.timeSlots);
  for (const kind of ["courses", "semesters", "rooms"])
    router.get("/" + kind, catalog.listCatalog(kind));
  router.get(
    "/sections",
    roles("STUDENT", "LECTURER", "HEAD"),
    validate(listSectionsSchema, "query"),
    sections.listSections,
  );
  router.get(
    "/schedule",
    roles("STUDENT", "LECTURER"),
    validate(personalScheduleSchema, "query"),
    sessions.personalSchedule,
  );
  router.get(
    "/sections/:id/sessions",
    roles("STUDENT", "LECTURER", "HEAD"),
    sessions.sectionSessions,
  );
  router.get(
    "/leave-requests",
    roles("STUDENT", "LECTURER"),
    validate(listRequestsSchema("leave"), "query"),
    requests.listRequests("leave"),
  );
  router.get(
    "/change-requests",
    roles("LECTURER", "STAFF"),
    validate(listRequestsSchema("change"), "query"),
    requests.listRequests("change"),
  );
  router.get(
    "/major-transfer-requests",
    roles("STUDENT", "STAFF"),
    validate(listSchema, "query"),
    transfers.list,
  );
  router.get(
    "/notices",
    roles("STUDENT", "STAFF"),
    validate(listNoticesSchema, "query"),
    notices.listNotices,
  );
  router.get("/notices/:id", roles("STUDENT", "STAFF"), notices.getNotice);
  return router;
}
