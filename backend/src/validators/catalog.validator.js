import { z } from "zod";
import { id, date, body } from "./common.js";

const code = z
  .string()
  .trim()
  .min(1)
  .max(80)
  .regex(/^[A-Za-z0-9_-]+$/);
const name = z.string().trim().min(1).max(120);
export const createUserSchema = body({
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
  major_id: id.nullable().optional(),
});
export const catalogSchemas = {
  departments: body({ code: code.max(60), name }),
  courses: body({ code, name, department_id: id }),
  semesters: body({
    term: z.enum(["SPRING", "SUMMER", "FALL"]),
    year: z.number().int().min(2000).max(2100),
  }),
  rooms: body({
    name: name.max(60),
    capacity: z.number().int().min(1).max(500),
  }),
};
