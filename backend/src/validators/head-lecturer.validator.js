import { z } from "zod";
import { body, version } from "./common.js";
const name = z.string().trim().min(1).max(120);
const email = z
  .email()
  .max(254)
  .transform((v) => v.toLowerCase());
const phone = z
  .string()
  .trim()
  .regex(/^\+?[0-9]{9,15}$/, "Số điện thoại cần 9–15 chữ số")
  .nullable();
const address = z.string().trim().max(250).nullable();
export const listLecturersSchema = body({
  search: z.string().trim().max(100).default(""),
  status: z.enum(["ALL", "ACTIVE", "INACTIVE"]).default("ALL"),
  page: z.coerce.number().int().min(1).max(10000).default(1),
});
export const createLecturerSchema = body({
  user_code: z
    .string()
    .trim()
    .min(1)
    .max(80)
    .regex(/^[A-Za-z0-9_-]+$/),
  name,
  email,
  password: z
    .string()
    .min(12)
    .refine(
      (v) => Buffer.byteLength(v, "utf8") <= 72,
      "Mật khẩu tối đa 72 byte",
    ),
  phone: phone.optional(),
  address: address.optional(),
});
export const updateLecturerSchema = body({
  version,
  name: name.optional(),
  email: email.optional(),
  phone: phone.optional(),
  address: address.optional(),
  active: z.boolean().optional(),
}).refine(
  (v) => Object.keys(v).some((k) => k !== "version"),
  "Cần có thông tin cập nhật",
);
