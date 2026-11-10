import { z } from "zod";
import { body, id, version, text } from "./common.js";
export const assignSessionsSchema = body({
  assignments: z
    .array(body({ session_id: id, lecturer_id: id.nullable(), version }))
    .min(1)
    .max(200)
    .refine(
      (rows) => new Set(rows.map((r) => r.session_id)).size === rows.length,
      "Trùng buổi phân công",
    ),
  reason: text,
});
