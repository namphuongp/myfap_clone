import { ref, model } from "./model-factory.js";
export const EnrollmentPeriod = model(
  "EnrollmentPeriod",
  {
    section_id: ref("Section"),
    student_id: ref("User"),
    starts_at: { type: Date, required: true },
    ends_at: { type: Date, default: null },
  },
  [
    [
      { section_id: 1, student_id: 1 },
      { unique: true, partialFilterExpression: { ends_at: null } },
    ],
    [{ section_id: 1, starts_at: 1, ends_at: 1 }, {}],
  ],
);
