import { Schema, ref, str, model } from "./model-factory.js";
export const Major = model("Major", {
  code: { ...str(80), unique: true },
  name: str(),
  department_id: ref("Department"),
  course_ids: [{ type: Schema.Types.ObjectId, ref: "Course" }],
  active: { type: Boolean, default: true },
});
