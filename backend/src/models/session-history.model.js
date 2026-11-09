import { Schema, ref, str, model } from "./model-factory.js";
export const SessionHistory = model(
  "SessionHistory",
  {
    session_id: ref("ClassSession"),
    actor_id: ref("User"),
    request_id: { type: Schema.Types.ObjectId, ref: "Change", default: null },
    action: str(80),
    before_data: { type: Schema.Types.Mixed, default: null },
    after_data: { type: Schema.Types.Mixed, required: true },
  },
  [[{ session_id: 1, created_at: -1 }, {}]],
);
