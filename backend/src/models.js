import mongoose from "mongoose";
import { slotTimes } from "./slots.js";
const { Schema } = mongoose;
const options = {
  timestamps: { createdAt: "created_at", updatedAt: "updated_at" },
  versionKey: "version",
  optimisticConcurrency: true,
  strict: "throw",
};
const ref = (model) => ({
  type: Schema.Types.ObjectId,
  ref: model,
  required: true,
});
const str = (max = 120) => ({
  type: String,
  required: true,
  trim: true,
  maxlength: max,
});
const model = (name, fields, indexes = []) => {
  const schema = new Schema(fields, options);
  for (const [keys, config] of indexes) schema.index(keys, config);
  return mongoose.model(name, schema);
};
export const Department = model("Department", {
  code: { ...str(60), unique: true },
  name: str(),
});
export const Course = model(
  "Course",
  {
    code: { ...str(80), unique: true },
    name: str(),
    department_id: ref("Department"),
  },
  [[{ department_id: 1, name: 1 }, { unique: true }]],
);
export const Semester = model("Semester", {
  code: { ...str(80), unique: true },
  name: str(),
  start_at: { type: Date, required: true },
  end_at: { type: Date, required: true },
});
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
  },
  [[{ department_id: 1, role: 1 }, {}]],
);
export const AuthSession = model(
  "AuthSession",
  {
    user_id: ref("User"),
    token_hash: { type: String, unique: true, required: true, select: false },
    expires_at: { type: Date, required: true },
  },
  [[{ expires_at: 1 }, { expireAfterSeconds: 0 }]],
);
export const Room = model("Room", {
  legacy_id: { type: Number, index: true, sparse: true },
  name: { ...str(60), unique: true },
  capacity: { type: Number, required: true, min: 1, max: 500 },
});
export const Section = model(
  "Section",
  {
    legacy_id: { type: Number, index: true, sparse: true },
    code: str(80),
    course_id: ref("Course"),
    semester_id: ref("Semester"),
    department_id: ref("Department"),
    lecturer_id: ref("User"),
    capacity: { type: Number, enum: [30], default: 30 },
    status: { type: String, enum: ["OPEN", "CLOSED"], default: "OPEN" },
  },
  [
    [{ semester_id: 1, code: 1 }, { unique: true }],
    [{ course_id: 1, semester_id: 1 }, {}],
    [{ lecturer_id: 1 }, {}],
    [{ department_id: 1 }, {}],
  ],
);
export const Enrollment = model(
  "Enrollment",
  {
    section_id: ref("Section"),
    student_id: ref("User"),
    course_id: ref("Course"),
    semester_id: ref("Semester"),
    status: { type: String, enum: ["ACTIVE", "WITHDRAWN"], default: "ACTIVE" },
    enrolled_at: { type: Date, required: true },
    withdrawn_at: { type: Date, default: null },
  },
  [
    [{ section_id: 1, student_id: 1 }, { unique: true }],
    [
      { student_id: 1, course_id: 1, semester_id: 1 },
      { unique: true, partialFilterExpression: { status: "ACTIVE" } },
    ],
    [{ section_id: 1, status: 1 }, {}],
  ],
);
export const EnrollmentPeriod = model(
  "EnrollmentPeriod",
  {
    section_id: ref("Section"),
    student_id: ref("User"),
    starts_at: { type: Date, required: true },
    ends_at: { type: Date, default: null },
  },
  [
    [
      { section_id: 1, student_id: 1 },
      { unique: true, partialFilterExpression: { ends_at: null } },
    ],
    [{ section_id: 1, starts_at: 1, ends_at: 1 }, {}],
  ],
);
const attendanceSchema = new Schema(
  {
    student_id: ref("User"),
    status: {
      type: String,
      enum: ["PRESENT", "ABSENT", "LATE", "EXCUSED"],
      required: true,
    },
    updated_by: ref("User"),
    updated_at: { type: Date, required: true },
  },
  { _id: false, strict: "throw" },
);
const sessionSchema = new Schema(
  {
    legacy_id: { type: Number, index: true, sparse: true },
    section_id: ref("Section"),
    lecturer_id: ref("User"),
    room_id: ref("Room"),
    session_date: { type: String, required: true },
    slot_id: { type: Number, enum: [1, 2, 3, 4, null], default: null },
    start_at: { type: Date, required: true },
    end_at: { type: Date, required: true },
    legacy_unaligned: { type: Boolean, default: false },
    status: {
      type: String,
      enum: ["SCHEDULED", "COMPLETED", "CANCELLED"],
      default: "SCHEDULED",
    },
    attendance_saved: { type: Boolean, default: false },
    attendance: {
      type: [attendanceSchema],
      default: [],
      validate: (v) => v.length <= 30,
    },
  },
  options,
);
sessionSchema.pre("validate", function () {
  if (this.end_at <= this.start_at)
    throw new Error("Khoảng thời gian không hợp lệ");
  if (!this.legacy_unaligned) {
    const expected = slotTimes(this.session_date, this.slot_id);
    if (
      expected.start_at.getTime() !== this.start_at.getTime() ||
      expected.end_at.getTime() !== this.end_at.getTime()
    )
      throw new Error("Giờ học không khớp slot");
  }
  if (
    new Set(this.attendance.map((a) => String(a.student_id))).size !==
    this.attendance.length
  )
    throw new Error("Trùng sinh viên trong điểm danh");
});
for (const key of ["section_id", "room_id", "lecturer_id"])
  sessionSchema.index(
    { [key]: 1, session_date: 1, slot_id: 1 },
    {
      unique: true,
      partialFilterExpression: {
        status: { $in: ["SCHEDULED", "COMPLETED"] },
        slot_id: { $type: "number" },
      },
    },
  );
sessionSchema.index({ start_at: 1, end_at: 1, status: 1 });
export const ClassSession = mongoose.model("ClassSession", sessionSchema);
const requestFields = {
  legacy_id: { type: Number, index: true, sparse: true },
  session_id: ref("ClassSession"),
  requester_id: ref("User"),
  reason: str(1000),
  reviewer_id: { type: Schema.Types.ObjectId, ref: "User", default: null },
  review_note: { type: String, maxlength: 1000, default: null },
  reviewed_at: { type: Date, default: null },
};
export const Leave = model(
  "Leave",
  {
    ...requestFields,
    status: {
      type: String,
      enum: ["PENDING", "APPROVED", "REJECTED", "INVALIDATED", "CANCELLED"],
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
export const Lock = mongoose.model(
  "AcademicLock",
  new Schema(
    { _id: String, revision: { type: Number, default: 0 } },
    { versionKey: false, strict: "throw" },
  ),
);
export const ImportBatch = model("ImportBatch", {
  source_hash: { type: String, unique: true, required: true },
  counts: { type: Schema.Types.Mixed, required: true },
});
export const MODELS = [
  Department,
  Course,
  Semester,
  User,
  AuthSession,
  Room,
  Section,
  Enrollment,
  EnrollmentPeriod,
  ClassSession,
  Leave,
  Change,
  Audit,
  SessionHistory,
  Lock,
  ImportBatch,
];
