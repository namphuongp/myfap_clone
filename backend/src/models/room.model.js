import { str, model } from "./model-factory.js";
export const Room = model("Room", {
  legacy_id: { type: Number, index: true, sparse: true },
  name: { ...str(60), unique: true },
  capacity: { type: Number, required: true, min: 1, max: 500 },
});
