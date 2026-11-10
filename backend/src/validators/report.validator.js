import { z } from "zod";
import { body, id } from "./common.js";
export const departmentSummarySchema = body({ semester_id: id.optional() });
export const attendanceReportSchema = body({
  semester_id: id.optional(),
  course_id: id.optional(),
  lecturer_id: id.optional(),
  section_id: id.optional(),
  group_by: z.enum(["SECTION", "COURSE", "LECTURER"]).default("SECTION"),
});
