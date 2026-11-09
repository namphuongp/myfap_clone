import { Schema, model } from "./model-factory.js";
export const ImportBatch = model("ImportBatch", {
  source_hash: { type: String, unique: true, required: true },
  counts: { type: Schema.Types.Mixed, required: true },
});
