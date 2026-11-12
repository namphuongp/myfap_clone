import { Schema, ref, str, model } from "./model-factory.js";
export const MajorTransfer = model(
  "MajorTransfer",
  {
    student_id: ref("User"),
    from_major_id: ref("Major"),
    to_major_id: ref("Major"),
    from_department_id: ref("Department"),
    to_department_id: ref("Department"),
    reason: str(1000),
    status: {
      type: String,
      enum: ["PENDING", "APPROVED", "REJECTED", "CANCELLED"],
      default: "PENDING",
    },
    effective_semester_id: {
      type: Schema.Types.ObjectId,
      ref: "Semester",
      default: null,
    },
    effective_at: { type: Date, required: true },
    applied_at: { type: Date, default: null },
    reviewer_id: { type: Schema.Types.ObjectId, ref: "User", default: null },
    review_note: { type: String, maxlength: 1000, default: null },
    reviewed_at: { type: Date, default: null },
  },
  [
    [
      { student_id: 1 },
      {
        name: "major_transfer_one_pending_per_student",
        unique: true,
        partialFilterExpression: { status: "PENDING" },
      },
    ],
    [{ status: 1, effective_at: 1, applied_at: 1 }, {}],
    [{ from_department_id: 1, status: 1 }, {}],
  ],
);
