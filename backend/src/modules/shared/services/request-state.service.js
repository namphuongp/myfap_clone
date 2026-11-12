import { clean } from "../../../utils/serialize.js";
import { saveDocument } from "../../../repositories/base.repository.js";
import { transaction } from "../../../repositories/transaction.js";
import { audit } from "./audit.service.js";
import {
  classSessionRepository,
  leaveRepository,
  changeRepository,
} from "../../../repositories/index.js";

// Đóng đơn còn chờ khi buổi học đã bắt đầu.
export async function expirePendingRequests(now = new Date()) {
  const [leaves, changes] = await Promise.all([
    leaveRepository.find({ status: "PENDING" }, { select: "session_id" }),
    changeRepository.find({ status: "PENDING" }, { select: "session_id" }),
  ]);
  const sessionIds = [
    ...new Set([...leaves, ...changes].map((row) => String(row.session_id))),
  ];
  if (sessionIds.length === 0) return 0;
  const lessons = await classSessionRepository.find(
    { _id: { $in: sessionIds }, start_at: { $lte: now } },
    { select: "_id" },
  );
  if (lessons.length === 0) return 0;
  return transaction(async (session) => {
    let expired = 0;
    for (const lessonId of lessons.map((lesson) => lesson._id)) {
      const lesson = await classSessionRepository.findById(lessonId, {
        session,
      });
      if (!lesson || lesson.start_at > now) continue;
      for (const repository of [leaveRepository, changeRepository]) {
        const rows = await repository.find(
          { session_id: lessonId, status: "PENDING" },
          { session },
        );
        for (const row of rows) {
          const before = clean(row);
          row.status = "EXPIRED";
          await saveDocument(row, { session });
          await audit(
            session,
            { _id: row.requester_id },
            "EXPIRE_REQUEST",
            repository.entityName,
            row._id,
            before,
            row,
          );
          expired += 1;
        }
      }
    }
    return expired;
  });
}
// Hủy các đơn không còn phù hợp với thay đổi buổi học.
export async function cancelRequests(session, user, lesson) {
  for (const repository of [leaveRepository, changeRepository]) {
    const rows = await repository.find(
      {
        session_id: lesson._id,
        status: {
          $in:
            repository === leaveRepository
              ? ["PENDING", "APPROVED"]
              : ["PENDING"],
        },
      },
      { session: session },
    );
    for (const row of rows) {
      const before = clean(row);
      row.status = "CANCELLED";
      await saveDocument(row, { session });
      await audit(
        session,
        user,
        "CANCEL_SESSION_REQUEST",
        repository.entityName,
        row._id,
        before,
        row,
      );
    }
  }
}
