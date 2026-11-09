import { Schema, options, ref } from "./model-factory.js";
import mongoose from "mongoose";
import { slotTimes } from "../utils/slots.js";
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
