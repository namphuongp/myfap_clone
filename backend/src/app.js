import { authRoutes, protectedRoutes } from "./routes/index.js";
import express from "express";
import helmet from "helmet";
import cors from "cors";
import { authenticate } from "./middlewares/auth.middleware.js";
import { apiLimiter } from "./middlewares/rate-limit.middleware.js";
import { errorHandler, notFound } from "./middlewares/error.middleware.js";
// Khởi tạo Express, bảo mật và đăng ký các nhóm API.
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
  app.use("/api", authenticate, protectedRoutes());
  app.use(notFound);
  app.use(errorHandler);
  return app;
}
