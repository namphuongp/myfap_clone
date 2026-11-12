import { Schema, ref, str, model } from "./model-factory.js";
export const ActivityLog = model(
  "ActivityLog",
  {
    actor_id: ref("User"),
    action: str(80),
    entity: str(60),
    entity_id: { type: Schema.Types.ObjectId, required: true },
    request_id: { type: Schema.Types.ObjectId, ref: "Change", default: null },
    category: {
      type: String,
      enum: ["AUDIT", "SESSION_HISTORY"],
      default: "AUDIT",
    },
    before_data: { type: Schema.Types.Mixed, default: null },
    after_data: { type: Schema.Types.Mixed, default: null },
    legacy_data: { type: Schema.Types.Mixed, default: undefined },
  },
  [
    [{ entity: 1, entity_id: 1, created_at: -1 }, {}],
    [{ actor_id: 1, created_at: -1 }, {}],
  ],
);
