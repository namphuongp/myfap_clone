import { z } from "zod";
export const id = z
  .string()
  .regex(/^[a-f\d]{24}$/i, "ID phải là MongoDB ObjectId")
  .transform((value) => value.toLowerCase());
export const version = z.number().int().nonnegative();
export const text = z.string().trim().min(1).max(1000);
export const date = z.iso
  .datetime({ offset: true })
  .transform((v) => new Date(v));
export const body = (fields) => z.strictObject(fields);
export const parse = (schema, value) => schema.parse(value);
