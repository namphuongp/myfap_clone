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
    if (!major.active) fail(409, "Ngành không hoạt động");
    const activeCourses = await courseRepository.distinct("_id", {
      _id: { $in: major.course_ids },
      active: { $ne: false },
    });
    const allowed = activeCourses.map(String);
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
export async function listSections(user, q = {}) {
  return await decorate(
    await sectionRepository.find(
      {
        ...(await sectionFilter(user)),
        ...Object.fromEntries(
          ["course_id", "semester_id"]
            .filter((key) => q[key])
            .map((key) => [key, q[key]]),
        ),
      },
      {
        sort: { _id: 1 },
        limit: 200,
      },
    ),
  );
}
export async function createSection(user, data) {
  const result = await transaction(async (session) => {
    const course = await get(courseRepository, data.course_id, session);
    const semester = await get(semesterRepository, data.semester_id, session);
    if (!same(course.department_id, user.department_id))
      fail(403, "Môn ngoài bộ môn");
    if (course.active === false) fail(409, "Môn đã ngừng sử dụng");
    if (semester.end_at <= new Date()) fail(409, "Học kỳ đã kết thúc");
    const [row] = await sectionRepository.create(
      [
        {
          ...data,
          department_id: course.department_id,
          capacity: 30,
          status: "CLOSED",
        },
      ],
      { session },
    );
    await audit(session, user, "CREATE_SECTION", "Section", row._id, null, row);
    return sectionDto(row);
  });
  return result;
}
export async function setSectionStatus(user, sectionId, data) {
  const row = await transaction(async (session) => {
    const row = await get(sectionRepository, sectionId, session);
    if (!same(row.department_id, user.department_id))
      fail(403, "Lớp ngoài bộ môn");
    checkVersion(row, data.version);
    if (data.status === "OPEN") {
      const course = await get(courseRepository, row.course_id, session);
      if (course.active === false) fail(409, "Môn đã ngừng sử dụng");
      if (
        !(await classSessionRepository.exists(
          {
            section_id: row._id,
            status: "SCHEDULED",
            slot_id: { $type: "number" },
            start_at: { $gt: new Date() },
          },
          { session },
        ))
      )
        fail(409, "Lớp cần có lịch tương lai trước khi mở đăng ký");
    }
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
    return sectionDto(row);
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
    ...sectionDto(s),
    course: courses.find((c) => same(c._id, s.course_id))?.name,
    course_code: courses.find((c) => same(c._id, s.course_id))?.code,
    semester_code: semesters.find((t) => same(t._id, s.semester_id))?.code,
  }));
}

function sectionDto(row) {
  const dto = clean(row);
  delete dto.lecturer_id;
  return { ...dto, assignment_basis: "SESSION" };
}
