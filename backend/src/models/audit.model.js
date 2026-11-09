import { Schema, ref, str, model } from "./model-factory.js";
export const Audit = model(
  "Audit",
  {
    actor_id: ref("User"),
    action: str(80),
    entity: str(60),
    entity_id: { type: Schema.Types.ObjectId, required: true },
    before_data: { type: Schema.Types.Mixed, default: null },
    after_data: { type: Schema.Types.Mixed, default: null },
  },
  [[{ entity: 1, entity_id: 1, created_at: -1 }, {}]],
);
