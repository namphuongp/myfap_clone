import { z } from "zod";
export const SLOTS = Object.freeze([
  { id: 1, code: "SLOT_1", start_minute: 450, end_minute: 590 },
  { id: 2, code: "SLOT_2", start_minute: 600, end_minute: 740 },
  { id: 3, code: "SLOT_3", start_minute: 770, end_minute: 910 },
  { id: 4, code: "SLOT_4", start_minute: 920, end_minute: 1060 },
]);
export const day = z.iso.date();
export const slotId = z.number().int().min(1).max(4);
// Tính giờ bắt đầu và kết thúc theo ngày và slot.
export function slotTimes(sessionDate, slot) {
  day.parse(sessionDate);
  slotId.parse(slot);
  const row = SLOTS[slot - 1];
  const midnight = new Date(`${sessionDate}T00:00:00+07:00`);
  return {
    session_date: sessionDate,
    slot_id: slot,
    start_at: new Date(midnight.getTime() + row.start_minute * 60000),
    end_at: new Date(midnight.getTime() + row.end_minute * 60000),
  };
}
// Đổi thời điểm thành ngày học theo giờ Việt Nam.
export const localDate = (date) =>
  new Date(new Date(date).getTime() + 7 * 3600000).toISOString().slice(0, 10);
