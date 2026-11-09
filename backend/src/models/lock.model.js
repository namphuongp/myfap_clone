import { Schema } from "./model-factory.js";
import mongoose from "mongoose";
export const Lock = mongoose.model(
  "AcademicLock",
  new Schema(
    { _id: String, revision: { type: Number, default: 0 } },
    { versionKey: false, strict: "throw" },
  ),
);
