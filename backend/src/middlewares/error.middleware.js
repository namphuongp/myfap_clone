import { z } from "zod";
import { ApiError } from "../utils/api-error.js";
export function notFound(req, res) {
  res.status(404).json({ message: "API không tồn tại" });
}
export function errorHandler(error, req, res, next) {
  if (error instanceof z.ZodError)
    return res
      .status(400)
      .json({ message: "Dữ liệu không hợp lệ", issues: error.issues });
  if (error instanceof ApiError)
    return res.status(error.status).json({ message: error.message });
  if (error.code === 11000 || error.name === "VersionError")
    return res
      .status(409)
      .json({ message: "Dữ liệu trùng hoặc đã thay đổi, hãy tải lại" });
  if (["ValidationError", "CastError", "StrictModeError"].includes(error.name))
    return res.status(400).json({ message: "Dữ liệu không đúng schema" });
  if (error.type === "entity.parse.failed" || error.type === "entity.too.large")
    return res
      .status(error.status)
      .json({ message: "JSON không hợp lệ hoặc quá lớn" });
  console.error(error.code ?? error.name);
  return res.status(500).json({ message: "Lỗi máy chủ" });
}
