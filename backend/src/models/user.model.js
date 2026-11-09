import { Schema, ref, str, model } from "./model-factory.js";
export const User = model(
  "User",
  {
    legacy_id: { type: Number, index: true, sparse: true },
    user_code: { ...str(80), unique: true },
    name: str(),
    email: { ...str(254), lowercase: true, unique: true },
    password_hash: { type: String, required: true, select: false },
    role: {
      type: String,
      enum: ["STUDENT", "LECTURER", "HEAD", "STAFF"],
      required: true,
    },
    department_id: ref("Department"),
    active: { type: Boolean, default: true },
    major_id: { type: Schema.Types.ObjectId, ref: "Major", default: null },
    phone: { type: String, maxlength: 20, default: null },
    address: { type: String, maxlength: 250, default: null },
    date_of_birth: { type: String, default: null },
  },
  [[{ department_id: 1, role: 1 }, {}]],
);
