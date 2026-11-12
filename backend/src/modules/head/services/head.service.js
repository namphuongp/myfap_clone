import {
  courseRepository,
  userRepository,
  semesterRepository,
} from "../../../repositories/index.js";
import { clean } from "../../../utils/serialize.js";
export async function options(user) {
  const [courses, lecturers, semesters] = await Promise.all([
    courseRepository.find(
      { department_id: user.department_id },
      { sort: { code: 1 } },
    ),
    userRepository.find(
      { department_id: user.department_id, role: "LECTURER", active: true },
      { select: "name user_code department_id", sort: { name: 1 } },
    ),
    semesterRepository.find(
      { legacy: { $ne: true }, term: { $ne: null } },
      { sort: { start_at: -1 } },
    ),
  ]);
  return {
    courses: clean(courses),
    lecturers: clean(lecturers),
    semesters: clean(semesters),
  };
}
