import { z } from "zod";
import { body, version, id } from "./common.js";
const code = z
  .string()
  .trim()
  .min(1)
  .max(80)
  .regex(/^[A-Za-z0-9_-]+$/);
const name = z.string().trim().min(1).max(120);
export const createCourseSchema = body({
  code,
  name,
  major_ids: z.array(id).max(100).default([]),
});
export const updateCourseSchema = body({
  version,
  code: code.optional(),
  name: name.optional(),
  active: z.boolean().optional(),
  major_ids: z.array(id).max(100).optional(),
}).refine(
  (v) => Object.keys(v).some((key) => key !== "version"),
  "Cần có trường cập nhật",
);
