import { ref, model } from "./model-factory.js";
export const Enrollment = model(
  "Enrollment",
  {
    section_id: ref("Section"),
    student_id: ref("User"),
    course_id: ref("Course"),
    semester_id: ref("Semester"),
    status: { type: String, enum: ["ACTIVE", "WITHDRAWN"], default: "ACTIVE" },
    enrolled_at: { type: Date, required: true },
    withdrawn_at: { type: Date, default: null },
  },
  [
    [{ section_id: 1, student_id: 1 }, { unique: true }],
    [
      { student_id: 1, course_id: 1, semester_id: 1 },
      { unique: true, partialFilterExpression: { status: "ACTIVE" } },
    ],
    [{ section_id: 1, status: 1 }, {}],
  ],
);
