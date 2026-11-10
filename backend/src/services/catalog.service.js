import { majorRepository } from "../repositories/student-affairs.repositories.js";
import { fail } from "../utils/api-error.js";
import { clean } from "../utils/serialize.js";
import { get, saveDocument } from "../repositories/base.repository.js";
import { transaction } from "../repositories/transaction.js";
import { audit } from "./audit.service.js";
import { SLOTS } from "../utils/slots.js";
import { checkVersion } from "../utils/version.js";
import { same } from "../utils/identity.js";
import {
  courseRepository,
  semesterRepository,
  roomRepository,
} from "../repositories/index.js";
const repositories = {
  courses: courseRepository,
  semesters: semesterRepository,
  rooms: roomRepository,
};
export async function timeSlots() {
  return SLOTS;
}
export async function listCatalog(kind, actor) {
  const filter =
    kind === "semesters" ? { legacy: { $ne: true }, term: { $ne: null } } : {};
  if (kind === "courses" && actor.role === "HEAD")
    filter.department_id = actor.department_id;
  const rows = clean(
    await repositories[kind].find(filter, { sort: { _id: 1 }, limit: 500 }),
  );
  if (kind === "courses" && actor.role === "HEAD") {
    const majors = await majorRepository.find({
      department_id: actor.department_id,
    });
    return rows.map((row) => ({
      ...row,
      major_ids: majors
        .filter((m) => m.course_ids.some((id) => same(id, row.id)))
        .map((m) => String(m._id)),
    }));
  }
  return rows;
}
export async function createCourse(actor, data) {
  return transaction(async (session) => {
    const { major_ids, ...fields } = data;
    const row = await courseRepository.create(
      { ...fields, department_id: actor.department_id },
      { session },
    );
    await curriculum(actor, row, major_ids, session);
    await audit(session, actor, "CREATE_COURSE", "Course", row._id, null, row);
    return clean(row);
  });
}
export async function updateCourse(actor, id, data) {
  return transaction(async (session) => {
    const row = await get(courseRepository, id, session);
    if (!same(row.department_id, actor.department_id))
      fail(403, "Môn ngoài bộ môn");
    checkVersion(row, data.version);
    const before = clean(row);
    for (const key of ["code", "name", "active"])
      if (Object.hasOwn(data, key)) row[key] = data[key];
    if (data.major_ids !== undefined) {
      await curriculum(actor, row, data.major_ids, session);
      // Đổi chương trình môn cũng tăng version của môn để chặn cập nhật từ bản cũ.
      row.markModified("name");
    }
    await saveDocument(row, { session });
    await audit(
      session,
      actor,
      "UPDATE_COURSE",
      "Course",
      row._id,
      before,
      row,
    );
    return clean(row);
  });
}

export async function listMajors(actor) {
  return clean(
    await majorRepository.find(
      { department_id: actor.department_id, active: true },
      { select: "code name", sort: { code: 1 }, limit: 500 },
    ),
  );
}
async function curriculum(actor, course, ids, session) {
  const selected = new Set(ids);
  for (const id of selected) {
    const major = await get(majorRepository, id, session);
    if (!same(major.department_id, actor.department_id) || !major.active)
      fail(403, "Ngành ngoài bộ môn hoặc không hoạt động");
  }
  const rows = await majorRepository.find(
    { department_id: actor.department_id },
    { session },
  );
  for (const major of rows) {
    const had = major.course_ids.some((id) => same(id, course._id)),
      wants = selected.has(String(major._id));
    if (had === wants) continue;
    const before = clean(major);
    major.course_ids = major.course_ids.filter((id) => !same(id, course._id));
    if (wants) major.course_ids.push(course._id);
    await saveDocument(major, { session });
    await audit(
      session,
      actor,
      "COURSE_CURRICULUM",
      "Major",
      major._id,
      before,
      major,
    );
  }
}
