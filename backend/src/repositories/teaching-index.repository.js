import { ClassSession } from "../models/class-session.model.js";
const currentName = "session_lecturer_slot_assigned";
// Xác định index giảng viên cần thay.
export async function teachingIndexPlan() {
  const exists = await ClassSession.db.db
    .listCollections({ name: ClassSession.collection.name })
    .hasNext();
  const indexes = exists ? await ClassSession.collection.indexes() : [];
  return indexes
    .filter(
      (index) =>
        JSON.stringify(index.key) ===
          JSON.stringify({ lecturer_id: 1, session_date: 1, slot_id: 1 }) &&
        index.name !== currentName,
    )
    .map((i) => i.name);
}
// Chỉ thay index cũ của giảng viên, không dùng syncIndexes để tránh xóa index ngoài phạm vi.
export async function migrateTeachingIndex() {
  for (const name of await teachingIndexPlan()) {
    try {
      await ClassSession.collection.dropIndex(name);
    } catch (error) {
      if (error.code !== 27) throw error;
    }
  }
}
