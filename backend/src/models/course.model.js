import { ref, str, model } from "./model-factory.js";
export const Course = model(
  "Course",
  {
    code: { ...str(80), unique: true },
    name: str(),
    department_id: ref("Department"),
  },
  [[{ department_id: 1, name: 1 }, { unique: true }]],
);
