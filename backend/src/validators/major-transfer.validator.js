import { z } from "zod";
import { body, id, text, version } from "./common.js";

export const createSchema = body({ to_major_id: id, reason: text });
export const listSchema = body({
  status: z.enum(["PENDING", "APPROVED", "REJECTED", "CANCELLED"]).optional(),
  page: z.coerce.number().int().min(1).max(10000).default(1),
});
export const reviewSchema = body({
  version,
  decision: z.enum(["APPROVED", "REJECTED"]),
  note: text,
});
