import { model } from "./model-factory.js";
import { requestFields } from "./request-fields.js";
export const Leave = model(
  "Leave",
  {
    ...requestFields,
    status: {
      type: String,
      enum: [
        "PENDING",
        "APPROVED",
        "REJECTED",
        "INVALIDATED",
        "CANCELLED",
        "EXPIRED",
      ],
      default: "PENDING",
    },
    session_version: { type: Number, required: true },
    session_date: { type: String, required: true },
    slot_id: { type: Number, enum: [1, 2, 3, 4, null], default: null },
    requested_start: { type: Date, required: true },
    requested_end: { type: Date, required: true },
  },
  [
    [
      { session_id: 1, requester_id: 1 },
      {
        unique: true,
        partialFilterExpression: { status: { $in: ["PENDING", "APPROVED"] } },
      },
    ],
    [{ requester_id: 1, status: 1, created_at: -1 }, {}],
  ],
);
