import { migrateTeachingIndex } from "./teaching-index.repository.js";
import { MajorTransfer } from "../models/major-transfer.model.js";
import mongoose from "mongoose";
import { MODELS, Lock } from "../models/index.js";
export const databaseRepository = {
  ping() {
    return mongoose.connection.db.admin().ping();
  },
  async initialize() {
    for (const Model of MODELS) {
      await Model.createCollection();
      if (Model.modelName === "MajorTransfer") {
        const indexes = await MajorTransfer.collection.indexes();
        for (const index of indexes) {
          const status = index.partialFilterExpression?.status;
          const legacyActiveTransferIndex =
            Array.isArray(status?.$in) && status.$in.includes("APPROVED");
          if (
            index.unique &&
            index.key?.student_id === 1 &&
            index.name !== "major_transfer_one_pending_per_student" &&
            legacyActiveTransferIndex
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
