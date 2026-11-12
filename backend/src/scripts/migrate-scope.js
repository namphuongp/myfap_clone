import { connect, disconnect, initialize } from "../config/database.js";
import { teachingIndexPlan } from "../repositories/teaching-index.repository.js";
try {
  await connect();
  const oldIndexes = await teachingIndexPlan();
  const apply = process.argv.includes("--apply");
  if (apply) await initialize();
  console.log(
    JSON.stringify({
      mode: apply ? "APPLIED" : "PREVIEW",
      replaced_indexes: oldIndexes,
      documents_changed: 0,
      note: "Giữ nguyên buổi/giảng viên cũ, danh sách sinh viên, đơn, điểm danh và nhật ký. Schema cũ cần chạy db:migrate trước.",
    }),
  );
} finally {
  await disconnect();
}
