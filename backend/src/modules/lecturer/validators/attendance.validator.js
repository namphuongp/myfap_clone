import { z } from "zod";
import { id, version, body } from "../../shared/validators/common.js";

export const saveAttendanceSchema = body({
  version,
  rows: z
    .array(
      body({
        student_id: id,
        status: z.enum(["PRESENT", "ABSENT", "LATE", "EXCUSED"]),
      }),
    )
    .min(1)
    .max(30),
});
