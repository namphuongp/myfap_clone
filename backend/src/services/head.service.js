import {
  courseRepository,
  userRepository,
  semesterRepository,
  sectionRepository,
  classSessionRepository,
} from "../repositories/index.js";
import { Types } from "mongoose";
import { transaction } from "../repositories/transaction.js";
import { get, saveDocument } from "../repositories/base.repository.js";
import { clean } from "../utils/serialize.js";
import { same } from "../utils/identity.js";
import { checkVersion } from "../utils/version.js";
import { fail } from "../utils/api-error.js";
import { audit } from "./audit.service.js";
const scope = (user, row) => {
  if (!same(user.department_id, row.department_id))
    fail(403, "Ngoài phạm vi bộ môn");
};
const literal = (value) => value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
async function page(repository, filter, q) {
  const [rows, total] = await Promise.all([
    repository.find(filter, {
      sort: { created_at: -1, _id: -1 },
      skip: (q.page - 1) * 50,
      limit: 50,
    }),
    repository.countDocuments(filter),
  ]);
  return {
    page: q.page,
    total,
    has_more: q.page * 50 < total,
    items: clean(rows),
  };
}
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
export async function courses(user, q) {
  const filter = { department_id: user.department_id };
  if (q.search) {
    const re = { $regex: literal(q.search), $options: "i" };
    filter.$or = [{ code: re }, { name: re }];
  }
  return page(courseRepository, filter, q);
}
export async function createCourse(user, data) {
  return transaction(async (session) => {
    const row = await courseRepository.create(
      { ...data, department_id: user.department_id },
      { session },
    );
    await audit(
      session,
      user,
      "HEAD_CREATE_COURSE",
      "Course",
      row._id,
      null,
      row,
    );
    return clean(row);
  });
}
export async function updateCourse(user, id, data) {
  return transaction(async (session) => {
    const row = await get(courseRepository, id, session);
    scope(user, row);
    checkVersion(row, data.version);
    if (
      row.code !== data.code &&
      (await sectionRepository.exists({ course_id: row._id }, { session }))
    )
      fail(409, "Không đổi mã môn đã có lớp học");
    const before = clean(row);
    row.code = data.code;
    row.name = data.name;
    await saveDocument(row, { session });
    await audit(
      session,
      user,
      "HEAD_UPDATE_COURSE",
      "Course",
      row._id,
      before,
      row,
    );
    return clean(row);
  });
}
export async function sections(user, q) {
  const filter = { department_id: user.department_id };
  if (q.semester_id) {
    await get(semesterRepository, q.semester_id);
    filter.semester_id = q.semester_id;
  }
  if (q.course_id) {
    scope(user, await get(courseRepository, q.course_id));
    filter.course_id = q.course_id;
  }
  if (q.search) filter.code = { $regex: literal(q.search), $options: "i" };
  const result = await page(sectionRepository, filter, q);
  const ids = result.items.map((r) => r.id);
  const [courses, lecturers, semesters, counts] = await Promise.all([
    courseRepository.find({
      _id: { $in: result.items.map((r) => r.course_id) },
    }),
    userRepository.find(
      { _id: { $in: result.items.map((r) => r.lecturer_id) } },
      { select: "name user_code" },
    ),
    semesterRepository.find({
      _id: { $in: result.items.map((r) => r.semester_id) },
    }),
    classSessionRepository.aggregate([
      {
        $match: {
          section_id: { $in: ids.map((id) => new Types.ObjectId(id)) },
        },
      },
      { $group: { _id: "$section_id", count: { $sum: 1 } } },
    ]),
  ]);
  const map = (rows) => new Map(rows.map((r) => [String(r._id), r]));
  const cm = map(courses),
    lm = map(lecturers),
    sm = map(semesters),
    tm = map(counts);
  result.items = result.items.map((r) => ({
    ...r,
    course: cm.get(r.course_id)?.name,
    course_code: cm.get(r.course_id)?.code,
    lecturer: lm.get(r.lecturer_id)?.name,
    lecturer_code: lm.get(r.lecturer_id)?.user_code,
    semester_code: sm.get(r.semester_id)?.code,
    session_count: tm.get(r.id)?.count ?? 0,
  }));
  return result;
}
export async function assignLecturer(user, id, data) {
  return transaction(async (session) => {
    const row = await get(sectionRepository, id, session);
    scope(user, row);
    checkVersion(row, data.version);
    const semester = await get(semesterRepository, row.semester_id, session);
    if (semester.end_at <= new Date()) fail(409, "Học kỳ đã kết thúc");
    if (
      await classSessionRepository.exists({ section_id: row._id }, { session })
    )
      fail(409, "Không đổi phân công lớp đã có buổi học; liên hệ cán bộ");
    const lecturer = await get(userRepository, data.lecturer_id, session);
    scope(user, lecturer);
    if (!lecturer.active || lecturer.role !== "LECTURER")
      fail(400, "Cần giảng viên đang hoạt động trong bộ môn");
    const before = clean(row);
    row.lecturer_id = lecturer._id;
    await saveDocument(row, { session });
    await audit(
      session,
      user,
      "HEAD_ASSIGN_LECTURER",
      "Section",
      row._id,
      before,
      row,
    );
    return clean(row);
  });
}
