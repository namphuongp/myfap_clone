import { semesterData } from "../utils/academic-calendar.js";
import { majorRepository } from "../repositories/student-affairs.repositories.js";
import { fail } from "../utils/api-error.js";
import { clean } from "../utils/serialize.js";
import { get } from "../repositories/base.repository.js";
import { transaction } from "../repositories/transaction.js";
import { audit } from "./audit.service.js";
import { SLOTS } from "../utils/slots.js";
import bcrypt from "bcryptjs";
import {
  departmentRepository,
  courseRepository,
  semesterRepository,
  userRepository,
  roomRepository,
} from "../repositories/index.js";
const catalogRepositories = {
  departments: departmentRepository,
  courses: courseRepository,
  semesters: semesterRepository,
  rooms: roomRepository,
};
export async function timeSlots() {
  return SLOTS;
}
export async function listCatalog(kind) {
  const repository = catalogRepositories[kind];
  return clean(
    await repository.find(
      kind === "semesters"
        ? { legacy: { $ne: true }, term: { $ne: null } }
        : {},
      { sort: { _id: 1 }, limit: 200 },
    ),
  );
}
export async function createCatalog(user, data, kind) {
  const repository = catalogRepositories[kind];
  const fields =
    kind === "semesters" ? semesterData(data.term, data.year) : data;
  return transaction(async (session) => {
    if (repository === courseRepository)
      await get(departmentRepository, fields.department_id, session);
    const row = await repository.create(fields, { session });
    await audit(
      session,
      user,
      "CREATE_CATALOG",
      repository.entityName,
      row._id,
      null,
      row,
    );
    return clean(row);
  });
}
export async function createUser(user, data) {
  const { password, ...fields } = data;
  const password_hash = await bcrypt.hash(password, 12);
  return transaction(async (session) => {
    await get(departmentRepository, fields.department_id, session);
    if (fields.major_id) {
      if (fields.role !== "STUDENT") fail(400, "Chỉ sinh viên có ngành học");
      const major = await get(majorRepository, fields.major_id, session);
      if (!major.active || String(major.department_id) !== fields.department_id)
        fail(400, "Ngành không hợp lệ hoặc không thuộc bộ môn");
    }
    const row = await userRepository.create(
      { ...fields, password_hash },
      { session },
    );
    await audit(session, user, "CREATE_USER", "User", row._id, null, fields);
    return clean(row);
  });
}
