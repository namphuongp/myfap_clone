import { fail } from "../utils/api-error.js";
import { same } from "../utils/identity.js";
import { get } from "../repositories/base.repository.js";
import {
  sectionRepository,
  enrollmentRepository,
  enrollmentPeriodRepository,
} from "../repositories/index.js";
export async function sectionFilter(user) {
  if (user.role === "HEAD") return { department_id: user.department_id };
  if (user.role === "LECTURER") return { lecturer_id: user._id };
  if (user.role === "STUDENT") {
    const ids = await enrollmentRepository.distinct("section_id", {
      student_id: user._id,
    });
    return { _id: { $in: ids } };
  }
  return {};
}
export async function scopedSectionIds(user) {
  return sectionRepository.distinct("_id", await sectionFilter(user));
}
export async function authorizeSection(section, user, session) {
  if (
    (user.role === "HEAD" &&
      !same(section.department_id, user.department_id)) ||
    (user.role === "LECTURER" && !same(section.lecturer_id, user._id))
  )
    fail(403, "Ngoài phạm vi truy cập");
  if (
    user.role === "STUDENT" &&
    !(await enrollmentRepository.findOne(
      {
        section_id: section._id,
        student_id: user._id,
      },
      { session: session ?? null },
    ))
  )
    fail(403, "Không thuộc lớp");
}
// Dùng khoảng đăng ký tại thời điểm buổi học để giữ đúng điểm danh khi rút/đăng ký lại.
export async function rosterIds(lesson, session) {
  return enrollmentPeriodRepository.distinct(
    "student_id",
    {
      section_id: lesson.section_id,
      starts_at: { $lte: lesson.start_at },
      $or: [{ ends_at: null }, { ends_at: { $gt: lesson.start_at } }],
    },
    { session: session ?? null },
  );
}
export async function authorizeLesson(lesson, user, session) {
  const section = await get(sectionRepository, lesson.section_id, session);
  await authorizeSection(section, user, session);
  if (
    user.role === "STUDENT" &&
    !(await rosterIds(lesson, session)).some((key) => same(key, user._id))
  )
    fail(403, "Không đăng ký ở thời điểm buổi học");
  return section;
}
