import express from "express";
import helmet from "helmet";
import cors from "cors";
import { rateLimit } from "express-rate-limit";
import { z } from "zod";
import { AuthSession } from "./models.js";
import { authenticate, ApiError, clean } from "./core.js";
import { publicRoutes } from "./auth-routes.js";
import { catalogRoutes } from "./catalog-routes.js";
import { academicRoutes } from "./academic-routes.js";
import { requestRoutes } from "./request-routes.js";
export function createApp() {
  const app = express();
  app.disable("x-powered-by");
  app.use(helmet());
  const origins = (process.env.CORS_ORIGINS ?? "").split(",").filter(Boolean);
  app.use(
    cors({
      origin: (origin, cb) => cb(null, !origin || origins.includes(origin)),
    }),
  );
  app.use(express.json({ limit: "64kb" }));
  app.use(
    "/api",
    rateLimit({
      windowMs: 60000,
      limit: 300,
      standardHeaders: "draft-8",
      legacyHeaders: false,
      message: { message: "Quá nhiều yêu cầu, hãy thử lại" },
    }),
  );
  app.use("/api", publicRoutes());
  app.use("/api", authenticate);
  app.get("/api/auth/me", (req, res) => res.json(clean(req.user)));
  app.post("/api/auth/logout", async (req, res) => {
    await AuthSession.deleteOne({ _id: req.auth._id });
    res.status(204).end();
  });
  app.use("/api", catalogRoutes());
  app.use("/api", academicRoutes());
  app.use("/api", requestRoutes());
  app.use((req, res) => res.status(404).json({ message: "API không tồn tại" }));
  app.use((error, req, res, next) => {
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
    if (
      ["ValidationError", "CastError", "StrictModeError"].includes(error.name)
    )
      return res.status(400).json({ message: "Dữ liệu không đúng schema" });
    if (
      error.type === "entity.parse.failed" ||
      error.type === "entity.too.large"
    )
      return res
        .status(error.status)
        .json({ message: "JSON không hợp lệ hoặc quá lớn" });
    console.error(error.code ?? error.name);
    res.status(500).json({ message: "Lỗi máy chủ" });
  });
  return app;
}
