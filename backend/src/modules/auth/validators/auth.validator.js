import { z } from "zod";
import { body } from "../../shared/validators/common.js";

export const loginSchema = body({
  email: z
    .email()
    .max(254)
    .transform((v) => v.toLowerCase()),
  password: z
    .string()
    .min(1)
    .refine((v) => Buffer.byteLength(v, "utf8") <= 72),
});
