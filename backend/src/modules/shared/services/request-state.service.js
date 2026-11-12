import { clean } from "../../../utils/serialize.js";
import { saveDocument } from "../../../repositories/base.repository.js";
import { audit } from "./audit.service.js";
import {
  leaveRepository,
  changeRepository,
} from "../../../repositories/index.js";
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
