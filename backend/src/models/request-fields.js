import { ref, str, Schema } from "./model-factory.js";
export const requestFields = {
  legacy_id: { type: Number, index: true, sparse: true },
  session_id: ref("ClassSession"),
  requester_id: ref("User"),
  reason: str(1000),
  reviewer_id: { type: Schema.Types.ObjectId, ref: "User", default: null },
  review_note: { type: String, maxlength: 1000, default: null },
  reviewed_at: { type: Date, default: null },
};
