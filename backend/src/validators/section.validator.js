import { z } from "zod";
import { id, body } from "./common.js";
export const listSectionsSchema = body({
  semester_id: id.optional(),
  course_id: id.optional(),
});
export const createSectionSchema = body({
  code: z.string().trim().min(1).max(80),
  course_id: id,
  semester_id: id,
});
