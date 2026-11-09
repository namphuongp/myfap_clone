import { str, model } from "./model-factory.js";
export const Semester = model(
  "Semester",
  {
    code: { ...str(80), unique: true },
    name: str(),
    start_at: { type: Date, required: true },
    end_at: { type: Date, required: true },
    term: {
      type: String,
      enum: ["SPRING", "SUMMER", "FALL", null],
      default: null,
    },
    year: { type: Number, default: null },
    academic_year: { type: String, default: null },
    legacy: { type: Boolean, default: false },
  },
  [
    [
      { term: 1, year: 1 },
      { unique: true, partialFilterExpression: { term: { $type: "string" } } },
    ],
  ],
);
