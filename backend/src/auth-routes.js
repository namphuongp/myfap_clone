import { Router } from "express";
import { rateLimit } from "express-rate-limit";
import bcrypt from "bcryptjs";
import mongoose from "mongoose";
import { z } from "zod";
import { User, AuthSession } from "./models.js";
import { body, parse, fail, token, hash, clean } from "./core.js";
export function publicRoutes() {
  const router = Router();
  router.get("/health", async (req, res) => {
    await mongoose.connection.db.admin().ping();
    res.json({ status: "ok", database: "mongodb" });
  });
  router.post(
    "/auth/login",
    rateLimit({
      windowMs: 900000,
      limit: 20,
      legacyHeaders: false,
      message: { message: "Thử đăng nhập quá nhiều lần" },
    }),
    async (req, res) => {
      const data = parse(
        body({
          email: z
            .email()
            .max(254)
            .transform((v) => v.toLowerCase()),
          password: z
            .string()
            .min(1)
            .refine((v) => Buffer.byteLength(v, "utf8") <= 72),
        }),
        req.body,
      );
      const user = await User.findOne({ email: data.email }).select(
        "+password_hash",
      );
      const valid = await bcrypt.compare(
        data.password,
        user?.password_hash ??
          "$2b$12$YgJE9YWOVcrTGLlX7ybzXu5xFxIx7Kf1T7QmZvJ6VCCbZz04HfA3O",
      );
      if (!user?.active || !valid) fail(401, "Email hoặc mật khẩu không đúng");
      const accessToken = token();
      const hours = Number(process.env.SESSION_HOURS ?? 8);
      const expiresAt = new Date(
        Date.now() +
          (Number.isFinite(hours) && hours > 0 ? hours : 8) * 3600000,
      );
      await AuthSession.create({
        user_id: user._id,
        token_hash: hash(accessToken),
        expires_at: expiresAt,
      });
      res.json({ accessToken, expiresAt, user: clean(user) });
    },
  );
  return router;
}
