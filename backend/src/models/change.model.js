import { Schema, ref, model } from "./model-factory.js";
import { requestFields } from "./request-fields.js";
export const Change = model(
  "Change",
  {
    ...requestFields,
    status: {
      type: String,
      enum: ["PENDING", "APPROVED", "REJECTED", "CANCELLED"],
      default: "PENDING",
    },
    session_version: { type: Number, required: true },
    proposed_room_id: ref("Room"),
    proposed_date: { type: String, default: null },
    proposed_slot_id: { type: Number, enum: [1, 2, 3, 4, null], default: null },
    proposed_start: { type: Date, required: true },
    proposed_end: { type: Date, required: true },
    original_room_id: {
      type: Schema.Types.ObjectId,
      ref: "Room",
      default: null,
    },
    original_date: { type: String, default: null },
    original_slot_id: { type: Number, enum: [1, 2, 3, 4, null], default: null },
    original_start: { type: Date, default: null },
    original_end: { type: Date, default: null },
  },
  [
    [
      { session_id: 1 },
      { unique: true, partialFilterExpression: { status: "PENDING" } },
    ],
    [{ requester_id: 1, status: 1, created_at: -1 }, {}],
  ],
);
