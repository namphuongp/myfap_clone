import { reportRoutes } from "./routes/report.routes.js";
import { headRoutes } from "./routes/head.routes.js";
import { noticeRoutes } from "./routes/notice.routes.js";
import { profileRoutes } from "./routes/profile.routes.js";
import express from "express";
import helmet from "helmet";
import cors from "cors";
import { authenticate } from "./middlewares/auth.middleware.js";
import { apiLimiter } from "./middlewares/rate-limit.middleware.js";
import { errorHandler, notFound } from "./middlewares/error.middleware.js";
import { authRoutes, sessionRoutes } from "./routes/auth.routes.js";
import { catalogRoutes } from "./routes/catalog.routes.js";
import { academicRoutes } from "./routes/academic.routes.js";
import { requestRoutes } from "./routes/request.routes.js";
import { majorTransferRoutes } from "./routes/major-transfer.routes.js";
export function createApp() {
  const app = express();
  app.disable("x-powered-by");
  app.use(helmet());
  const origins = (process.env.CORS_ORIGINS ?? "")
    .split(",")
    .map((o) => o.trim())
    .filter(Boolean);
  app.use(
    cors({
      origin: (origin, cb) => {
        if (!origin || origins.includes(origin)) return cb(null, true);
        if (/^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin)) {
          return cb(null, true);
        }
        cb(null, false);
      },
    }),
  );
  app.use(express.json({ limit: "64kb" }));
  app.use("/api", apiLimiter());
  app.use("/api", authRoutes());
  app.use("/api", authenticate);
  app.use("/api", sessionRoutes());
  app.use("/api", profileRoutes());
  app.use("/api", noticeRoutes());
  app.use("/api", reportRoutes());
  app.use("/api", headRoutes());
  app.use("/api", catalogRoutes());
  app.use("/api", academicRoutes());
  app.use("/api", requestRoutes());
  app.use("/api", majorTransferRoutes());
  app.use(notFound);
  app.use(errorHandler);
  return app;
}
