import { z } from "zod";
import { body, version } from "./common.js";
import { localDate } from "../utils/slots.js";
export const updateProfileSchema = body({
  version,
  phone: z
    .string()
    .trim()
    .regex(/^[+0-9 ()-]{7,20}$/, "Số điện thoại không hợp lệ")
    .nullable()
    .optional(),
  address: z.string().trim().min(1).max(250).nullable().optional(),
  date_of_birth: z.iso
    .date()
    .refine(
      (v) => v >= "1900-01-01" && v <= localDate(new Date()),
      "Ngày sinh không hợp lệ",
    )
    .nullable()
    .optional(),
}).refine(
  (v) => Object.keys(v).some((k) => k !== "version"),
  "Cần có thông tin cần thay đổi",
);
const password = z
  .string()
  .min(1)
  .refine((v) => Buffer.byteLength(v, "utf8") <= 72, "Mật khẩu tối đa 72 byte");
export const changePasswordSchema = body({
  current_password: password,
  new_password: password.refine(
    (v) => v.length >= 12,
    "Mật khẩu mới cần ít nhất 12 ký tự",
  ),
});
