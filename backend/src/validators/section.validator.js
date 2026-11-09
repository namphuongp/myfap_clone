import { z } from "zod";
import { id, version, body } from "./common.js";

export const availableSectionsSchema = body({
  semester_id: id.optional(),
  course_id: id.optional(),
});
export const createSectionSchema = body({
  code: z.string().trim().min(1).max(80),
  course_id: id,
  semester_id: id,
  lecturer_id: id,
});
export const setSectionStatusSchema = body({
  version,
  status: z.enum(["OPEN", "CLOSED"]),
});
