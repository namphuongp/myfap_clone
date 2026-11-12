import {
  majorTransferRepository,
  majorRepository,
} from "../../../repositories/index.js";
import {
  userRepository,
  semesterRepository,
  sectionRepository,
  classMembershipRepository,
} from "../../../repositories/index.js";
import { get, saveDocument } from "../../../repositories/base.repository.js";
import { transaction } from "../../../repositories/transaction.js";
import { audit } from "./audit.service.js";
import { closeMembership } from "./class-membership.service.js";
import { nextTerm } from "../../../utils/academic-calendar.js";
import { same } from "../../../utils/identity.js";
import { clean } from "../../../utils/serialize.js";
import { checkVersion } from "../../../utils/version.js";
import { fail } from "../../../utils/api-error.js";

async function nextSemester(session, now = new Date()) {
  const data = nextTerm(now);
  if (!data) fail(409, "Không xác định được học kỳ tiếp theo");
  let term = await semesterRepository.findOne({ code: data.code }, { session });
  if (!term) term = await semesterRepository.create(data, { session });
  if (+term.start_at !== +data.start_at || +term.end_at !== +data.end_at)
    fail(409, "Lịch học kỳ tiếp theo chưa được chuẩn hóa");
  return term;
}
export async function options() {
  return clean(
    await majorRepository.find(
      { active: true },
      { select: "code name", sort: { code: 1 }, limit: 500 },
    ),
  );
}
export async function create(actor, data) {
  return transaction(async (session) => {
    const student = await get(userRepository, actor._id, session);
    if (!student.major_id) fail(409, "Tài khoản chưa được gán ngành hiện tại");
    const target = await get(majorRepository, data.to_major_id, session);
    if (!target.active) fail(400, "Ngành được chọn không còn hoạt động");
    if (same(student.major_id, target._id))
      fail(400, "Ngành được chọn đang là ngành hiện tại");
    if (
      await majorTransferRepository.exists(
        {
          student_id: student._id,
          status: { $in: ["PENDING", "APPROVED"] },
          applied_at: null,
        },
        { session },
      )
    )
      fail(409, "Đã có đơn chuyển ngành đang chờ hoặc đã duyệt chờ kỳ tới");
    const term = await nextSemester(session);
    const row = await majorTransferRepository.create(
      {
        student_id: student._id,
        from_major_id: student.major_id,
        to_major_id: target._id,
        from_department_id: student.department_id,
        to_department_id: target.department_id,
        reason: data.reason,
        effective_semester_id: term._id,
        effective_at: term.start_at,
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
export async function list(actor, query) {
  const filter = {};
  if (query.status) filter.status = query.status;
  if (actor.role === "STUDENT") filter.student_id = actor._id;
  const rows = await majorTransferRepository.find(filter, {
    sort: { created_at: -1, _id: -1 },
    skip: (query.page - 1) * 50,
    limit: 50,
  });
  const [students, majors, terms] = await Promise.all([
    userRepository.find(
      { _id: { $in: rows.map((r) => r.student_id) } },
      { select: "name user_code" },
    ),
    majorRepository.find({
      _id: { $in: rows.flatMap((r) => [r.from_major_id, r.to_major_id]) },
    }),
    semesterRepository.find({
      _id: { $in: rows.map((r) => r.effective_semester_id).filter(Boolean) },
    }),
  ]);
  const map = (values) => new Map(values.map((r) => [String(r._id), r]));
  const studentsById = map(students),
    majorsById = map(majors),
    termsById = map(terms);
  return {
    page: query.page,
    items: rows.map((row) => ({
      ...clean(row),
      student: clean(studentsById.get(String(row.student_id))) ?? null,
      from_major: clean(majorsById.get(String(row.from_major_id))) ?? null,
      to_major: clean(majorsById.get(String(row.to_major_id))) ?? null,
      effective_semester:
        clean(termsById.get(String(row.effective_semester_id))) ?? null,
    })),
  };
}
export async function review(actor, id, data) {
  return transaction(async (session) => {
    const row = await get(majorTransferRepository, id, session);
    checkVersion(row, data.version);
    if (row.status !== "PENDING") fail(409, "Đơn không còn chờ duyệt");
    const student = await get(userRepository, row.student_id, session),
      before = clean(row);
    if (data.decision === "APPROVED") {
      if (!same(student.major_id, row.from_major_id))
        fail(
          409,
          "Ngành hiện tại của sinh viên đã thay đổi; cần kiểm tra lại đơn",
        );
      const target = await get(majorRepository, row.to_major_id, session);
      if (!target.active) fail(409, "Ngành đích đã ngừng hoạt động");
      // Duyệt chỉ lên lịch cho kỳ kế tiếp, không sửa ngành hay danh sách lớp ngay.
      const term = await nextSemester(session);
      row.effective_semester_id = term._id;
      row.effective_at = term.start_at;
      row.applied_at = null;
    }
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
// Áp dụng cả khi server đã tắt qua ranh giới học kỳ; transaction làm thao tác idempotent.
export async function applyDueMajorTransfers(
  now = new Date(),
  studentId = null,
) {
  const filter = {
    status: "APPROVED",
    applied_at: null,
    effective_at: { $lte: now },
    ...(studentId ? { student_id: studentId } : {}),
  };
  const due = await majorTransferRepository.find(filter, {
    select: "_id",
    sort: { effective_at: 1, _id: 1 },
  });
  for (const pending of due)
    await transaction(async (session) => {
      const row = await majorTransferRepository.findOne(
        { _id: pending._id, ...filter },
        { session },
      );
      if (!row) return;
      const student = await get(userRepository, row.student_id, session),
        target = await get(majorRepository, row.to_major_id, session);
      const actor = { _id: row.reviewer_id ?? row.student_id },
        before = clean(row);
      if (!target.active || !same(student.major_id, row.from_major_id)) {
        row.status = "CANCELLED";
        row.review_note = [
          row.review_note,
          "Không áp dụng: ngành hiện tại hoặc ngành đích đã thay đổi.",
        ]
          .filter(Boolean)
          .join("\n")
          .slice(0, 1000);
        await saveDocument(row, { session });
        await audit(
          session,
          actor,
          "CANCEL_MAJOR_TRANSFER_CONFLICT",
          "MajorTransfer",
          row._id,
          before,
          row,
        );
        return;
      }
      const memberships = await classMembershipRepository.find(
        { student_id: student._id, ends_at: null },
        { session },
      );
      const sections = await sectionRepository.find(
        { _id: { $in: memberships.map((m) => m.section_id) } },
        { session },
      );
      const allowed = new Set(target.course_ids.map(String));
      const sectionsById = new Map(sections.map((s) => [String(s._id), s]));
      for (const member of memberships) {
        const section = sectionsById.get(String(member.section_id));
        if (!section) fail(409, "Dữ liệu sinh viên thuộc lớp không hợp lệ");
        if (!allowed.has(String(section.course_id)))
          await closeMembership(
            session,
            actor,
            member.section_id,
            student._id,
            member.version,
            new Date(Math.max(+row.effective_at, +member.starts_at)),
          );
      }
      const beforeStudent = clean(student);
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
        beforeStudent,
        student,
      );
      await audit(
        session,
        actor,
        "APPLY_MAJOR_TRANSFER",
        "MajorTransfer",
        row._id,
        before,
        row,
      );
    });
  return due.length;
}
