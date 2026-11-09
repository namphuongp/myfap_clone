import { ref, model } from "./model-factory.js";
export const AuthSession = model(
  "AuthSession",
  {
    user_id: ref("User"),
    token_hash: { type: String, unique: true, required: true, select: false },
    expires_at: { type: Date, required: true },
  },
  [[{ expires_at: 1 }, { expireAfterSeconds: 0 }]],
);
