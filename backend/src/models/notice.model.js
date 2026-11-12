import { Schema, ref, str, model } from "./model-factory.js";
export const Notice = model(
  "Notice",
  {
    title: str(160),
    content: str(5000),
    audience: {
      type: String,
      enum: [
        "ALL_STUDENTS",
        "ALL_LECTURERS",
        "ALL_HEADS",
        "ALL_USERS",
        "DEPARTMENT",
        "MAJOR",
      ],
      default: "ALL_STUDENTS",
    },
    department_ids: [{ type: Schema.Types.ObjectId, ref: "Department" }],
    major_ids: [{ type: Schema.Types.ObjectId, ref: "Major" }],
    status: {
      type: String,
      enum: ["DRAFT", "PUBLISHED", "ARCHIVED"],
      default: "DRAFT",
    },
    created_by: ref("User"),
    published_at: { type: Date, default: null },
    expires_at: { type: Date, default: null },
  },
  [
    [{ status: 1, published_at: -1 }, {}],
    [{ department_ids: 1, status: 1 }, {}],
    [{ major_ids: 1, status: 1 }, {}],
  ],
);
