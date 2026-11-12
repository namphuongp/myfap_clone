import { ref, model, Schema } from "./model-factory.js";
export const ClassMembership = model(
  "ClassMembership",
  {
    section_id: ref("Section"),
    student_id: ref("User"),
    // Giữ môn/kỳ để tạo unique index, tránh sinh viên thuộc hai lớp của cùng môn/kỳ.
    course_id: ref("Course"),
    semester_id: ref("Semester"),
    starts_at: { type: Date, required: true },
    ends_at: {
      type: Date,
      default: null,
      validate: {
        validator: function (value) {
          return !value || value >= this.starts_at;
        },
        message: "Thời gian rời lớp không hợp lệ",
      },
    },
    legacy_data: { type: Schema.Types.Mixed, default: undefined },
  },
  [
    [
      { section_id: 1, student_id: 1 },
      { unique: true, partialFilterExpression: { ends_at: null } },
    ],
    [
      { student_id: 1, course_id: 1, semester_id: 1 },
      { unique: true, partialFilterExpression: { ends_at: null } },
    ],
    [{ section_id: 1, starts_at: 1, ends_at: 1 }, {}],
    [{ student_id: 1, section_id: 1, starts_at: -1 }, {}],
  ],
);
