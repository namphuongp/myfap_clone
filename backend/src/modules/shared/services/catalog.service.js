import { clean } from "../../../utils/serialize.js";
import { SLOTS } from "../../../utils/slots.js";
import {
  courseRepository,
  semesterRepository,
  roomRepository,
} from "../../../repositories/index.js";
const repositories = {
  courses: courseRepository,
  semesters: semesterRepository,
  rooms: roomRepository,
};
// Trả bốn khung giờ học cố định.
export async function timeSlots() {
  return SLOTS;
}
// Lấy danh mục dùng chung theo phạm vi người dùng.
export async function listCatalog(kind, actor) {
  const filter =
    kind === "semesters" ? { legacy: { $ne: true }, term: { $ne: null } } : {};
  if (kind === "courses" && actor.role === "HEAD")
    filter.department_id = actor.department_id;
  const rows = clean(
    await repositories[kind].find(filter, { sort: { _id: 1 }, limit: 500 }),
  );

  return rows;
}
