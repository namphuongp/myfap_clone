import { ref, model } from "./model-factory.js";
export const NoticeRead = model(
  "NoticeRead",
  {
    notice_id: ref("Notice"),
    user_id: ref("User"),
    read_at: { type: Date, required: true },
  },
  [[{ notice_id: 1, user_id: 1 }, { unique: true }]],
);
