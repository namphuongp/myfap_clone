import { assertCollectionsMigrated } from "./collection-migration.repository.js";
import { migrateTeachingIndex } from "./teaching-index.repository.js";
import { MajorTransfer } from "../models/major-transfer.model.js";
import mongoose from "mongoose";
import { MODELS, Lock } from "../models/index.js";
export const databaseRepository = {
  // Kiểm tra database còn hoạt động.
  ping() {
    return mongoose.connection.db.admin().ping();
  },
  // Khởi tạo collection và đúng các index cần thiết.
  async initialize({ allowLegacy = false } = {}) {
    if (!allowLegacy) await assertCollectionsMigrated();
    for (const Model of MODELS) {
      await Model.createCollection();
      if (Model.modelName === "MajorTransfer") {
        const indexes = await MajorTransfer.collection.indexes();
        for (const index of indexes) {
          if (
            index.unique &&
            index.key?.student_id === 1 &&
            index.name !== "major_transfer_one_active_per_student"
          ) {
            await MajorTransfer.collection.dropIndex(index.name);
          }
        }
      }
      if (Model.modelName === "ClassSession") await migrateTeachingIndex();
      await Model.createIndexes();
    }
    await Lock.updateOne(
      { _id: "academic" },
      { $setOnInsert: { revision: 0 } },
      { upsert: true },
    );
  },
};
