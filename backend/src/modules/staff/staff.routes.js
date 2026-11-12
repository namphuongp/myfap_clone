import { Router } from "express";
import { roles } from "../../middlewares/auth.middleware.js";
import { validate, validateId } from "../../middlewares/validate.middleware.js";
import * as notices from "./controllers/notice.controller.js";
import * as noticeSchemas from "./validators/notice.validator.js";
import * as requests from "../shared/controllers/request.controller.js";
import { reviewRequestSchema } from "../shared/validators/request.validator.js";
import * as transfers from "../shared/controllers/major-transfer.controller.js";
import { reviewSchema } from "../shared/validators/major-transfer.validator.js";

export function staffRoutes(){const router=Router();router.param("id",validateId);
router.post("/notices",roles("STAFF"),validate(noticeSchemas.createNoticeSchema),notices.createNotice);
router.post("/notices/:id/publish",roles("STAFF"),validate(noticeSchemas.noticeActionSchema),notices.publishNotice);
router.patch("/change-requests/:id/decision",roles("STAFF"),validate(reviewRequestSchema),requests.reviewRequest("change"));
router.patch("/major-transfer-requests/:id/decision",roles("STAFF"),validate(reviewSchema),transfers.review);
return router;}
