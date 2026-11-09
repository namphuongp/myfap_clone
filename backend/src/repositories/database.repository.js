import mongoose from "mongoose";
import { MODELS, Lock } from "../models/index.js";
export const databaseRepository = {
  ping() {
    return mongoose.connection.db.admin().ping();
  },
  async initialize() {
    for (const Model of MODELS) {
      await Model.createCollection();
      await Model.createIndexes();
    }
    await Lock.updateOne(
      { _id: "academic" },
      { $setOnInsert: { revision: 0 } },
      { upsert: true },
    );
  },
};
