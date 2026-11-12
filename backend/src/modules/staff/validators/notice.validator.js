import { z } from "zod";
import { body, id, version, date } from "../../shared/validators/common.js";
const fields = {
  title: z.string().trim().min(1).max(160),
  content: z.string().trim().min(1).max(5000),
  audience: z
    .enum([
      "ALL_STUDENTS",
      "ALL_LECTURERS",
      "ALL_HEADS",
      "ALL_USERS",
      "DEPARTMENT",
      "MAJOR",
    ])
    .default("ALL_STUDENTS"),
  department_ids: z.array(id).max(100).default([]),
  major_ids: z.array(id).max(100).default([]),
  expires_at: date.nullable().optional(),
};
export const createNoticeSchema = body(fields);
export const noticeActionSchema = body({ version });
export const listNoticesSchema = body({
  page: z.coerce.number().int().min(1).max(10000).default(1),
  status: z.enum(["DRAFT", "PUBLISHED", "ARCHIVED"]).optional(),
});
