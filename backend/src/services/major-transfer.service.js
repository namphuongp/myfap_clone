import {
  majorTransferRepository,
  majorRepository,
} from "../repositories/student-affairs.repositories.js";
import { userRepository } from "../repositories/index.js";
import { get, saveDocument } from "../repositories/base.repository.js";
import { transaction } from "../repositories/transaction.js";
import { audit } from "./audit.service.js";
import { clean } from "../utils/serialize.js";
import { checkVersion } from "../utils/version.js";
import { fail } from "../utils/api-error.js";

const same = (a, b) => String(a) === String(b);

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
    const existing = await majorTransferRepository.findOne(
      {
        student_id: student._id,
        status: "PENDING",
      },
      { session },
    );
    if (existing)
      fail(409, "Đã có đơn chuyển ngành đang chờ hoặc chưa áp dụng");
    const row = await majorTransferRepository.create(
      {
        student_id: student._id,
        from_major_id: student.major_id,
        to_major_id: target._id,
        from_department_id: student.department_id ?? target.department_id,
        to_department_id: target.department_id,
        reason: data.reason,
        effective_at: new Date(),
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
  const [students, majors] = await Promise.all([
    userRepository.find(
      { _id: { $in: [...new Set(rows.map((row) => String(row.student_id)))] } },
      { select: "name user_code" },
    ),
    majorRepository.find({
      _id: {
        $in: [
          ...new Set(
            rows.flatMap((row) => [
              String(row.from_major_id),
              String(row.to_major_id),
            ]),
          ),
        ],
      },
    }),
  ]);
  const studentById = new Map(students.map((row) => [String(row._id), row]));
  const majorById = new Map(majors.map((row) => [String(row._id), row]));
  return {
    page: query.page,
    items: rows.map((row) => ({
      ...clean(row),
      student: clean(studentById.get(String(row.student_id))) ?? null,
      from_major: clean(majorById.get(String(row.from_major_id))) ?? null,
      to_major: clean(majorById.get(String(row.to_major_id))) ?? null,
    })),
  };
}

export async function review(actor, id, data) {
  return transaction(async (session) => {
    const row = await get(majorTransferRepository, id, session);
    checkVersion(row, data.version);
    if (row.status !== "PENDING") fail(409, "Đơn không còn chờ duyệt");
    const student = await get(userRepository, row.student_id, session);
    const before = clean(row);
    if (data.decision === "APPROVED") {
      if (!same(student.major_id, row.from_major_id))
        fail(
          409,
          "Ngành hiện tại của sinh viên đã thay đổi; cần kiểm tra lại đơn",
        );
      const target = await get(majorRepository, row.to_major_id, session);
      if (!target.active) fail(409, "Ngành đích đã ngừng hoạt động");
      const beforeStudent = clean(student);
      student.major_id = target._id;
      await saveDocument(student, { session });
      row.applied_at = new Date();
      row.effective_at = row.applied_at;
      await audit(
        session,
        actor,
        "APPLY_MAJOR_TRANSFER",
        "User",
        student._id,
        beforeStudent,
        student,
      );
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
