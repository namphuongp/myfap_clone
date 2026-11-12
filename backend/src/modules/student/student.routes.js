import { Router } from "express";
import { roles } from "../../middlewares/auth.middleware.js";
import { validate } from "../../middlewares/validate.middleware.js";
import * as requests from "../shared/controllers/request.controller.js";
import * as requestSchemas from "../shared/validators/request.validator.js";
import * as transfers from "../shared/controllers/major-transfer.controller.js";
import * as transferSchemas from "../shared/validators/major-transfer.validator.js";

// Khai báo thao tác riêng của sinh viên.
export function studentRoutes() {
  const router = Router();
  // XN4: Chỉ STUDENT được gọi; kiểm tra dữ liệu rồi chuyển sang controller.
  router.post(
    "/leave-requests",
    roles("STUDENT"),
    validate(requestSchemas.createLeaveSchema),
    requests.createLeave,
  );
  router.get("/major-transfer-options", roles("STUDENT"), transfers.options);
  // CN4: Chỉ sinh viên được gửi đơn; backend kiểm tra ngành đích và lý do.
  router.post(
    "/major-transfer-requests",
    roles("STUDENT"),
    validate(transferSchemas.createSchema),
    transfers.create,
  );
  return router;
}
