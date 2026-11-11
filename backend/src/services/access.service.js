import { fail } from "../utils/api-error.js";
import { same } from "../utils/identity.js";
import { get } from "../repositories/base.repository.js";
import {
  sectionRepository,
  enrollmentRepository,
  enrollmentPeriodRepository,
  classSessionRepository,
} from "../repositories/index.js";
export async function sectionFilter(user) {
  if (user.role === "HEAD") return { department_id: user.department_id };
  if (user.role === "LECTURER")
    return {
      _id: {
        $in: await classSessionRepository.distinct("section_id", {
          lecturer_id: user._id,
        }),
      },
    };
  if (user.role === "STUDENT")
    return {
      _id: {
        $in: await enrollmentRepository.distinct("section_id", {
          student_id: user._id,
        }),
      },
    };
  return {};
}
export async function authorizeSection(section, user, session) {
  if (user.role === "HEAD" && !same(section.department_id, user.department_id))
    fail(403, "Ngoài phạm vi bộ môn");
  if (
    user.role === "LECTURER" &&
    !(await classSessionRepository.exists(
      { section_id: section._id, lecturer_id: user._id },
      { session },
    ))
  )
    fail(403, "Không có buổi phụ trách trong lớp");
  if (
    user.role === "STUDENT" &&
    !(await enrollmentRepository.exists(
      { section_id: section._id, student_id: user._id },
      { session },
    ))
  )
    fail(403, "Không thuộc lớp");
}
export async function rosterIds(lesson, session) {
  return enrollmentPeriodRepository.distinct(
    "student_id",
    {
      section_id: lesson.section_id,
      starts_at: { $lte: lesson.start_at },
      $or: [{ ends_at: null }, { ends_at: { $gt: lesson.start_at } }],
    },
    { session },
  );
}
export async function authorizeLesson(lesson, user, session) {
  const section = await get(sectionRepository, lesson.section_id, session);
  if (user.role === "LECTURER") {
    if (!same(lesson.lecturer_id, user._id))
      fail(403, "Không phụ trách buổi học này");
  } else await authorizeSection(section, user, session);
  if (
    user.role === "STUDENT" &&
    !(await rosterIds(lesson, session)).some((key) => same(key, user._id))
  )
    fail(403, "Không đăng ký ở thời điểm buổi học");
  return section;
}
