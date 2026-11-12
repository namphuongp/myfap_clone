import {
  userRepository,
  classSessionRepository,
  sectionRepository,
  courseRepository,
  roomRepository,
} from "../../../repositories/index.js";
import { clean } from "../../../utils/serialize.js";

// Chỉ bổ sung thông tin hiển thị cho các đơn đã được lọc quyền, không truy vấn từng dòng.
export async function displayRequests(rows) {
  if (!rows.length) return [];
  const [people, lessons] = await Promise.all([
    userRepository.find(
      { _id: { $in: rows.map((r) => r.requester_id) } },
      { select: "name user_code" },
    ),
    classSessionRepository.find(
      { _id: { $in: rows.map((r) => r.session_id) } },
      { select: "section_id room_id session_date slot_id" },
    ),
  ]);
  const [sections, rooms] = await Promise.all([
    sectionRepository.find(
      { _id: { $in: lessons.map((s) => s.section_id) } },
      { select: "code course_id" },
    ),
    roomRepository.find(
      {
        _id: {
          $in: [
            ...lessons.map((s) => s.room_id),
            ...rows.flatMap((r) => [r.original_room_id, r.proposed_room_id]),
          ].filter(Boolean),
        },
      },
      { select: "name" },
    ),
  ]);
  const courses = await courseRepository.find(
    { _id: { $in: sections.map((s) => s.course_id) } },
    { select: "code name" },
  );
  // Lập bảng tra bản ghi theo ID.
  const byId = (items) =>
    new Map(items.map((item) => [String(item._id), item]));
  const peopleById = byId(people),
    lessonById = byId(lessons),
    sectionById = byId(sections),
    courseById = byId(courses),
    roomById = byId(rooms);
  return rows.map((row) => {
    const person = peopleById.get(String(row.requester_id));
    const lesson = lessonById.get(String(row.session_id));
    const section = sectionById.get(String(lesson?.section_id));
    const course = courseById.get(String(section?.course_id));
    return {
      ...clean(row),
      requester: person
        ? { name: person.name, user_code: person.user_code }
        : null,
      lesson: lesson
        ? {
            section_code: section?.code ?? null,
            course: course?.name ?? null,
            course_code: course?.code ?? null,
            session_date: lesson.session_date,
            slot_id: lesson.slot_id,
            room_name: roomById.get(String(lesson.room_id))?.name ?? null,
          }
        : null,
      original_room_name:
        roomById.get(String(row.original_room_id))?.name ?? null,
      proposed_room_name:
        roomById.get(String(row.proposed_room_id))?.name ?? null,
    };
  });
}
