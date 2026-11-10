import { z } from "zod";
import { body, id, version } from "./common.js";
const code = z
  .string()
  .trim()
  .min(1)
  .max(80)
  .regex(/^[A-Za-z0-9_-]+$/);
const name = z.string().trim().min(1).max(120);
export const courseCreate = body({ code, name });
export const courseUpdate = body({ version, code, name });
export const assign = body({ version, lecturer_id: id });
export const list = body({
  search: z.string().trim().max(100).default(""),
  semester_id: id.optional(),
  course_id: id.optional(),
  page: z.coerce.number().int().min(1).max(10000).default(1),
});
