import { str, model } from "./model-factory.js";
export const Department = model("Department", {
  code: { ...str(60), unique: true },
  name: str(),
});
