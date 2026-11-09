import { Router } from "express";
import bcrypt from "bcryptjs";
import { z } from "zod";
import { Department, Course, Semester, Room, User } from "./models.js";
import {
  body,
  id,
  date,
  parse,
  roles,
  get,
  fail,
  audit,
  transaction,
  clean,
} from "./core.js";
import { SLOTS } from "./slots.js";
const code = z
  .string()
  .trim()
  .min(1)
  .max(80)
  .regex(/^[A-Za-z0-9_-]+$/);
const name = z.string().trim().min(1).max(120);
export function catalogRoutes() {
  const router = Router();
  router.get("/time-slots", (req, res) => res.json(SLOTS));
  for (const [path, Model, schema] of [
    ["departments", Department, body({ code: code.max(60), name })],
    ["courses", Course, body({ code, name, department_id: id })],
    ["semesters", Semester, body({ code, name, start_at: date, end_at: date })],
    [
      "rooms",
      Room,
      body({ name: name.max(60), capacity: z.number().int().min(1).max(500) }),
    ],
  ]) {
    router.get(`/${path}`, async (req, res) =>
      res.json(clean(await Model.find().sort({ _id: 1 }).limit(200))),
    );
    router.post(`/${path}`, roles("STAFF"), async (req, res) => {
      const data = parse(schema, req.body);
      const result = await transaction(async (session) => {
        if (Model === Course)
          await get(Department, data.department_id, session);
        if (Model === Semester && data.end_at <= data.start_at)
          fail(400, "Ngày kết thúc phải sau ngày bắt đầu");
        const [row] = await Model.create([data], { session });
        await audit(
          session,
          req.user,
          "CREATE_CATALOG",
          Model.modelName,
          row._id,
          null,
          row,
        );
        return clean(row);
      });
      res.status(201).json(result);
    });
  }
  router.post("/users", roles("STAFF"), async (req, res) => {
    const data = parse(
      body({
        user_code: code,
        name,
        email: z
          .email()
          .max(254)
          .transform((v) => v.toLowerCase()),
        password: z
          .string()
          .min(12)
          .refine(
            (v) => Buffer.byteLength(v, "utf8") <= 72,
            "Mật khẩu tối đa 72 byte",
          ),
        role: z.enum(["STUDENT", "LECTURER", "HEAD", "STAFF"]),
        department_id: id,
      }),
      req.body,
    );
    const { password, ...fields } = data;
    const password_hash = await bcrypt.hash(password, 12);
    const result = await transaction(async (session) => {
      await get(Department, fields.department_id, session);
      const [row] = await User.create([{ ...fields, password_hash }], {
        session,
      });
      await audit(
        session,
        req.user,
        "CREATE_USER",
        "User",
        row._id,
        null,
        fields,
      );
      return clean(row);
    });
    res.status(201).json(result);
  });
  return router;
}
