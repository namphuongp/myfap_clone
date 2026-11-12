import { z } from "zod";
import { id, version, text, date, body } from "./common.js";
import { day, slotId } from "../../../utils/slots.js";

export const personalScheduleSchema = body({ from: date, to: date });
export const createSessionSchema = body({
  section_id: id,
  room_id: id,
  session_date: day,
  slot_id: slotId,
});
export const changeScheduleSchema = body({
  version,
  room_id: id,
  session_date: day,
  slot_id: slotId,
  reason: text,
});
export const setSessionStatusSchema = body({
  version,
  status: z.enum(["COMPLETED", "CANCELLED"]),
  reason: text,
});
