import { ref, str, model } from "./model-factory.js";
export const Section = model(
  "Section",
  {
    legacy_id: { type: Number, index: true, sparse: true },
    code: str(80),
    course_id: ref("Course"),
    semester_id: ref("Semester"),
    department_id: ref("Department"),
    // Chỉ giữ để đọc dữ liệu cũ, không dùng làm phân công hiện tại.
    lecturer_id: { ...ref("User"), required: false, default: null },
    capacity: { type: Number, enum: [30], default: 30 },
    status: { type: String, enum: ["OPEN", "CLOSED"], default: "OPEN" },
  },
  [
    [{ semester_id: 1, code: 1 }, { unique: true }],
    [{ course_id: 1, semester_id: 1 }, {}],
    [{ lecturer_id: 1 }, {}],
    [{ department_id: 1 }, {}],
  ],
);
