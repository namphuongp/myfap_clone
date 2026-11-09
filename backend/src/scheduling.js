import { fail, get } from "./core.js";
export async function ensureSlot(
  trx,
  section,
  roomId,
  start,
  end,
  exclude = 0,
) {
  if (end <= start || end - start > 12 * 3600000)
    fail(400, "Buổi học phải dài hơn 0 và không quá 12 giờ");
  const room = await get("rooms", roomId, trx);
  const [{ count }] = await trx("enrollments")
    .where({ section_id: section.id })
    .count("* as count");
  if (Number(count) > room.capacity) fail(409, "Phòng không đủ chỗ");
  const overlap = await trx("class_sessions as cs")
    .join("sections as s", "s.id", "cs.section_id")
    .where("cs.id", "<>", exclude)
    .where("cs.start_at", "<", end)
    .where("cs.end_at", ">", start)
    .select("cs.*", "s.lecturer_id");
  const students = await trx("enrollments")
    .where({ section_id: section.id })
    .pluck("student_id");
  for (const lesson of overlap) {
    if (lesson.room_id === roomId || lesson.lecturer_id === section.lecturer_id)
      fail(409, "Trùng phòng hoặc giảng viên");
    if (
      students.length &&
      (await trx("enrollments")
        .where({ section_id: lesson.section_id })
        .whereIn("student_id", students)
        .first())
    )
      fail(409, "Sinh viên bị trùng lịch");
  }
}
