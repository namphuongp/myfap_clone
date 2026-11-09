import {
  majorRepository,
  majorTransferRepository,
} from "../repositories/student-affairs.repositories.js";
import {
  userRepository,
  departmentRepository,
  courseRepository,
  semesterRepository,
  sectionRepository,
  enrollmentRepository,
} from "../repositories/index.js";
import { get, saveDocument } from "../repositories/base.repository.js";
import { transaction } from "../repositories/transaction.js";
import { audit } from "./audit.service.js";
import { withdraw } from "./enrollment.service.js";
import { nextTerm } from "../utils/academic-calendar.js";
import { clean } from "../utils/serialize.js";
import { same } from "../utils/identity.js";
import { checkVersion } from "../utils/version.js";
import { fail } from "../utils/api-error.js";
async function courses(ids, session) {
  const values = [...new Set(ids)];
  for (const id of values) await get(courseRepository, id, session);
  return values;
}
export async function listMajors() {
  return clean(
    await majorRepository.find(
      { active: true },
      { sort: { code: 1 }, limit: 200 },
    ),
  );
}
export async function createMajor(actor, data) {
  return transaction(async (session) => {
    await get(departmentRepository, data.department_id, session);
    const row = await majorRepository.create(
      { ...data, course_ids: await courses(data.course_ids, session) },
      { session },
    );
    await audit(session, actor, "CREATE_MAJOR", "Major", row._id, null, row);
    return clean(row);
  });
}
export async function updateCurriculum(actor, id, data) {
  return transaction(async (session) => {
    const row = await get(majorRepository, id, session);
    checkVersion(row, data.version);
    const before = clean(row);
    row.course_ids = await courses(data.course_ids, session);
    await saveDocument(row, { session });
    await audit(
      session,
      actor,
      "UPDATE_CURRICULUM",
      "Major",
      row._id,
      before,
      row,
    );
    return clean(row);
  });
}
export async function assignInitialMajor(actor, id, data) {
  return transaction(async (session) => {
    const user = await get(userRepository, id, session);
    checkVersion(user, data.version);
    if (user.role !== "STUDENT") fail(400, "Chỉ gán ngành học cho sinh viên");
    if (user.major_id)
      fail(409, "Sinh viên đã có ngành; cần dùng quy trình chuyển ngành");
    const major = await get(majorRepository, data.major_id, session);
    if (!major.active) fail(409, "Ngành không hoạt động");
    const before = clean(user);
    user.major_id = major._id;
    user.department_id = major.department_id;
    await saveDocument(user, { session });
    await audit(
      session,
      actor,
      "ASSIGN_INITIAL_MAJOR",
      "User",
      user._id,
      before,
      user,
    );
    return clean(user);
  });
}
export async function createTransfer(actor, data) {
  return transaction(async (session) => {
    const student = await get(userRepository, actor._id, session);
    if (!student.major_id)
      fail(409, "Cán bộ cần cập nhật ngành hiện tại trước khi chuyển ngành");
    const from = await get(majorRepository, student.major_id, session),
      target = await get(majorRepository, data.to_major_id, session);
    if (!target.active || same(from._id, target._id))
      fail(400, "Ngành chuyển đến phải khác ngành hiện tại và đang hoạt động");
    const calendar = nextTerm();
    let semester = await semesterRepository.findOne(
      { code: calendar.code },
      { session },
    );
    if (!semester)
      semester = await semesterRepository.create(calendar, { session });
    const row = await majorTransferRepository.create(
      {
        student_id: student._id,
        from_major_id: from._id,
        to_major_id: target._id,
        from_department_id: from.department_id,
        to_department_id: target.department_id,
        reason: data.reason,
        effective_semester_id: semester._id,
        effective_at: semester.start_at,
      },
      { session },
    );
    await audit(
      session,
      actor,
      "CREATE_MAJOR_TRANSFER",
      "MajorTransfer",
      row._id,
      null,
      row,
    );
    return clean(row);
  });
}
export async function listTransfers(actor, q) {
  const filter = {};
  if (actor.role === "STUDENT") filter.student_id = actor._id;
  if (q.status) filter.status = q.status;
  return {
    page: q.page,
    items: clean(
      await majorTransferRepository.find(filter, {
        sort: { created_at: -1, _id: -1 },
        skip: (q.page - 1) * 20,
        limit: 20,
      }),
    ),
  };
}
export async function decideTransfer(actor, id, data) {
  return transaction(async (session) => {
    const row = await get(majorTransferRepository, id, session);
    checkVersion(row, data.version);
    if (row.status !== "PENDING") fail(409, "Đơn không còn chờ duyệt");
    if (data.decision === "APPROVED") {
      const student = await get(userRepository, row.student_id, session);
      const target = await get(majorRepository, row.to_major_id, session);
      if (!same(student.major_id, row.from_major_id))
        fail(409, "Ngành hiện tại đã thay đổi");
      if (!target.active) fail(409, "Ngành đích không hoạt động");
      if (row.effective_at <= new Date())
        fail(
          409,
          "Kỳ hiệu lực đã bắt đầu; sinh viên cần gửi đơn mới cho kỳ sau",
        );
    }
    const before = clean(row);
    row.status = data.decision;
    row.reviewer_id = actor._id;
    row.review_note = data.note;
    row.reviewed_at = new Date();
    await saveDocument(row, { session });
    await audit(
      session,
      actor,
      "REVIEW_MAJOR_TRANSFER",
      "MajorTransfer",
      row._id,
      before,
      row,
    );
    return clean(row);
  });
}
export async function cancelTransfer(actor, id, data) {
  return transaction(async (session) => {
    const row = await get(majorTransferRepository, id, session);
    if (!same(row.student_id, actor._id))
      fail(403, "Chỉ được rút đơn của mình");
    checkVersion(row, data.version);
    if (row.status !== "PENDING") fail(409, "Chỉ rút đơn đang chờ duyệt");
    const before = clean(row);
    row.status = "CANCELLED";
    await saveDocument(row, { session });
    await audit(
      session,
      actor,
      "CANCEL_MAJOR_TRANSFER",
      "MajorTransfer",
      row._id,
      before,
      row,
    );
    return clean(row);
  });
}
// Chuyển ngành chỉ đóng đăng ký ở kỳ hiệu lực trở đi; các môn chung và lịch sử học cũ vẫn giữ.
export async function applyDueTransfers({ studentId, now = new Date() } = {}) {
  const filter = {
    status: "APPROVED",
    applied_at: null,
    effective_at: { $lte: now },
  };
  if (studentId) filter.student_id = studentId;
  if (!(await majorTransferRepository.exists(filter))) return [];
  return transaction(async (session) => {
    const rows = await majorTransferRepository.find(filter, {
      session,
      sort: { effective_at: 1 },
      limit: 50,
    });
    const applied = [];
    for (const row of rows) {
      const student = await get(userRepository, row.student_id, session),
        target = await get(majorRepository, row.to_major_id, session),
        from = await get(majorRepository, row.from_major_id, session);
      if (!same(student.major_id, row.from_major_id))
        fail(409, "Dữ liệu ngành không khớp đơn đã duyệt");
      if (!target.active) fail(409, "Ngành đích không còn hoạt động");
      const actor = await get(userRepository, row.reviewer_id, session);
      const oldCourses = new Set(from.course_ids.map(String)),
        newCourses = new Set(target.course_ids.map(String));
      const enrolled = await enrollmentRepository.find(
        { student_id: student._id, status: "ACTIVE" },
        { session },
      );
      const cancelled = [];
      for (const e of enrolled) {
        if (
          !oldCourses.has(String(e.course_id)) ||
          newCourses.has(String(e.course_id))
        )
          continue;
        const section = await get(sectionRepository, e.section_id, session);
        const semester = await get(
          semesterRepository,
          section.semester_id,
          session,
        );
        if (semester.end_at <= row.effective_at) continue;
        await withdraw(
          session,
          actor,
          e.section_id,
          student._id,
          e.version,
          row.effective_at,
        );
        cancelled.push(String(e.section_id));
      }
      const before = clean(student);
      student.major_id = target._id;
      student.department_id = target.department_id;
      await saveDocument(student, { session });
      row.applied_at = now;
      await saveDocument(row, { session });
      await audit(
        session,
        actor,
        "APPLY_MAJOR_TRANSFER",
        "User",
        student._id,
        before,
        {
          ...clean(student),
          transfer_id: String(row._id),
          cancelled_section_ids: cancelled,
        },
      );
      applied.push(String(row._id));
    }
    return applied;
  });
}
