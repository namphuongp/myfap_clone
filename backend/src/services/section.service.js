import { majorRepository } from "../repositories/student-affairs.repositories.js";
import { fail } from "../utils/api-error.js";
import { same } from "../utils/identity.js";
import { clean } from "../utils/serialize.js";
import { checkVersion } from "../utils/version.js";
import { get, saveDocument } from "../repositories/base.repository.js";
import { transaction } from "../repositories/transaction.js";
import { audit } from "./audit.service.js";
import { sectionFilter } from "./access.service.js";
import {
  courseRepository,
  semesterRepository,
  userRepository,
  sectionRepository,
  enrollmentRepository,
  classSessionRepository,
} from "../repositories/index.js";
export async function availableSections(user, q) {
  const future = await classSessionRepository.distinct("section_id", {
    status: "SCHEDULED",
    slot_id: { $ne: null },
    start_at: { $gt: new Date() },
  });
  const filter = { _id: { $in: future }, status: "OPEN" };
  if (user.role === "STUDENT") {
    if (!user.major_id)
      fail(409, "Cán bộ cần cập nhật ngành học trước khi đăng ký môn");
    const major = await get(majorRepository, user.major_id);
    const allowed = major.course_ids.map(String);
    filter.course_id = {
      $in: q.course_id ? allowed.filter((id) => id === q.course_id) : allowed,
    };
  } else if (q.course_id) filter.course_id = q.course_id;
  if (q.semester_id) filter.semester_id = q.semester_id;
  const rows = await sectionRepository.find(filter, {
    sort: { _id: 1 },
    limit: 200,
  });
  const result = await decorate(rows);
  const counts = await enrollmentRepository.activeCounts(
    rows.map((row) => row._id),
  );
  const bySection = new Map(counts.map((row) => [String(row._id), row.count]));
  for (const row of result) {
    row.enrolled = bySection.get(row.id) ?? 0;
    row.remaining = 30 - row.enrolled;
  }
  return result;
}
export async function listSections(user) {
  return await decorate(
    await sectionRepository.find(await sectionFilter(user), {
      sort: { _id: 1 },
      limit: 200,
    }),
  );
}
export async function createSection(user, data) {
  const result = await transaction(async (session) => {
    const course = await get(courseRepository, data.course_id, session);
    const lecturer = await get(userRepository, data.lecturer_id, session);
    const semester = await get(semesterRepository, data.semester_id, session);
    if (
      lecturer.role !== "LECTURER" ||
      !lecturer.active ||
      !same(lecturer.department_id, course.department_id)
    )
      fail(400, "Giảng viên phải hoạt động và thuộc bộ môn của môn học");
    if (semester.end_at <= new Date()) fail(409, "Học kỳ đã kết thúc");
    const [row] = await sectionRepository.create(
      [{ ...data, department_id: course.department_id, capacity: 30 }],
      { session },
    );
    await audit(session, user, "CREATE_SECTION", "Section", row._id, null, row);
    return clean(row);
  });
  return result;
}
export async function setSectionStatus(user, sectionId, data) {
  const row = await transaction(async (session) => {
    const row = await get(sectionRepository, sectionId, session);
    checkVersion(row, data.version);
    const before = clean(row);
    row.status = data.status;
    await saveDocument(row, { session });
    await audit(
      session,
      user,
      "SET_SECTION_STATUS",
      "Section",
      row._id,
      before,
      row,
    );
    return clean(row);
  });
  return row;
}
async function decorate(rows) {
  const courses = await courseRepository.find({
    _id: { $in: rows.map((s) => s.course_id) },
  });
  const semesters = await semesterRepository.find({
    _id: { $in: rows.map((s) => s.semester_id) },
  });
  return rows.map((s) => ({
    ...clean(s),
    course: courses.find((c) => same(c._id, s.course_id))?.name,
    course_code: courses.find((c) => same(c._id, s.course_id))?.code,
    semester_code: semesters.find((t) => same(t._id, s.semester_id))?.code,
  }));
}
