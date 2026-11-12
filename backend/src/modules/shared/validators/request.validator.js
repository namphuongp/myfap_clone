import { z } from "zod";
import { id, version, text, body } from "./common.js";
import { day, slotId } from "../../../utils/slots.js";

export const createLeaveSchema = body({ session_id: id, reason: text });
export const createChangeSchema = body({
  session_id: id,
  reason: text,
  proposed_room_id: id,
  proposed_date: day,
  proposed_slot_id: slotId,
});
export const listRequestsSchema = (kind) =>
  body({
    status: z
      .enum(
        kind === "leave"
          ? ["PENDING", "APPROVED", "REJECTED", "INVALIDATED", "CANCELLED"]
          : ["PENDING", "APPROVED", "REJECTED", "CANCELLED"],
      )
      .optional(),
    page: z.coerce.number().int().min(1).max(10000).default(1),
  });
export const reviewRequestSchema = body({
  version,
  decision: z.enum(["APPROVED", "REJECTED"]),
  note: text,
});
