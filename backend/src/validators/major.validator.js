import { z } from "zod";
import { body, id, version, text } from "./common.js";
export const createMajorSchema = body({
  code: z
    .string()
    .trim()
    .min(1)
    .max(80)
    .regex(/^[A-Za-z0-9_-]+$/),
  name: z.string().trim().min(1).max(120),
  department_id: id,
  course_ids: z.array(id).max(200).default([]),
});
export const curriculumSchema = body({
  version,
  course_ids: z.array(id).max(200),
});
export const initialMajorSchema = body({ version, major_id: id });
export const createTransferSchema = body({ to_major_id: id, reason: text });
export const decisionSchema = body({
  version,
  decision: z.enum(["APPROVED", "REJECTED"]),
  note: text,
});
export const cancelTransferSchema = body({ version });
export const listTransfersSchema = body({
  page: z.coerce.number().int().min(1).max(10000).default(1),
  status: z.enum(["PENDING", "APPROVED", "REJECTED", "CANCELLED"]).optional(),
});
