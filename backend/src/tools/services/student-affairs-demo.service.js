import {
  userRepository,
  courseRepository,
  sectionRepository,
  classMembershipRepository,
} from "../../repositories/index.js";
import { majorRepository } from "../../repositories/index.js";
import { transaction } from "../../repositories/transaction.js";
import { saveDocument } from "../../repositories/base.repository.js";
import { audit } from "../../modules/shared/services/audit.service.js";
import { fail } from "../../utils/api-error.js";
export async function seedStudentAffairsDemo() {
  return transaction(async (session) => {
    const staff = await userRepository.findOne(
      {
        email: "staff@myfap.local",
        name: "Demo STAFF",
        role: "STAFF",
        active: true,
      },
      { session },
    );
    const student = await userRepository.findOne(
      {
        email: "student@myfap.local",
        name: "Demo STUDENT",
        role: "STUDENT",
        active: true,
      },
      { session },
    );
    if (!staff || !student)
      fail(
        409,
        "Lệnh này chỉ dùng cho tài khoản demo gốc; không tự gán ngành cho dữ liệu thật",
      );
    const sectionIds = await classMembershipRepository.distinct(
      "section_id",
      { student_id: student._id },
      { session },
    );
    const courseIds = await sectionRepository.distinct(
      "course_id",
      { _id: { $in: sectionIds } },
      { session },
    );
    let source = await majorRepository.findOne(
      { code: "SE-DEMO" },
      { session },
    );
    if (!source)
      source = await majorRepository.create(
        {
          code: "SE-DEMO",
          name: "Kỹ thuật phần mềm (demo)",
          department_id: student.department_id,
          course_ids: courseIds,
        },
        { session },
      );
    let course = await courseRepository.findOne(
      { code: "AI101-DEMO" },
      { session },
    );
    if (!course)
      course = await courseRepository.create(
        {
          code: "AI101-DEMO",
          name: "Nhập môn AI (demo)",
          department_id: student.department_id,
        },
        { session },
      );
    let target = await majorRepository.findOne(
      { code: "AI-DEMO" },
      { session },
    );
    if (!target)
      target = await majorRepository.create(
        {
          code: "AI-DEMO",
          name: "Trí tuệ nhân tạo (demo)",
          department_id: student.department_id,
          course_ids: [course._id],
        },
        { session },
      );
    if (!student.major_id) {
      student.major_id = source._id;
      await saveDocument(student, { session });
      await audit(
        session,
        staff,
        "ASSIGN_DEMO_MAJOR",
        "User",
        student._id,
        null,
        { major_id: String(source._id) },
      );
    }
    return {
      student_id: String(student._id),
      current_major_id: String(student.major_id),
      source_major_id: String(source._id),
      target_major_id: String(target._id),
    };
  });
}
