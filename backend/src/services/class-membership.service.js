import {
  classMembershipRepository,
  classSessionRepository,
  leaveRepository,
} from "../repositories/index.js";
import { saveDocument } from "../repositories/base.repository.js";
import { checkVersion } from "../utils/version.js";
import { fail } from "../utils/api-error.js";
import { clean } from "../utils/serialize.js";
import { audit } from "./audit.service.js";
// Kết thúc khoảng thuộc lớp khi áp dụng chuyển ngành; không có API tự đăng ký/rút lớp.
export async function closeMembership(
  session,
  user,
  sectionId,
  studentId,
  expected,
  effectiveAt = new Date(),
) {
  const row = await classMembershipRepository.findOne(
    {
      section_id: sectionId,
      student_id: studentId,
      ends_at: null,
    },
    { session: session },
  );
  if (!row) fail(404, "Sinh viên không còn thuộc lớp");
  checkVersion(row, expected);
  if (row.ends_at) fail(409, "Sinh viên đã rời lớp");
  const before = clean(row);
  const now = effectiveAt;
  row.ends_at = now;
  await saveDocument(row, { session });
  const lessons = await classSessionRepository.distinct(
    "_id",
    {
      section_id: sectionId,
      start_at: { $gte: now },
    },
    { session: session },
  );
  const leaves = await leaveRepository.find(
    {
      requester_id: studentId,
      session_id: { $in: lessons },
      status: { $in: ["PENDING", "APPROVED"] },
    },
    { session: session },
  );
  for (const leave of leaves) {
    const old = clean(leave);
    leave.status = "CANCELLED";
    await saveDocument(leave, { session });
    await audit(
      session,
      user,
      "CANCEL_LEAVE_MEMBERSHIP_END",
      "Leave",
      leave._id,
      old,
      leave,
    );
  }
  await audit(
    session,
    user,
    "END_CLASS_MEMBERSHIP",
    "Section",
    sectionId,
    before,
    row,
  );
  return clean(row);
}
