import { connect, initialize, disconnect } from "../config/database.js";
import { transaction } from "../repositories/transaction.js";
import { saveDocument } from "../repositories/base.repository.js";
import { audit } from "../modules/shared/services/audit.service.js";
import { nextTerm } from "../utils/academic-calendar.js";
import {
  userRepository,
  majorRepository,
  semesterRepository,
  majorTransferRepository,
} from "../repositories/index.js";

const samples = [
  {
    email: "an.nv@myfap.local",
    status: "PENDING",
    target: "AI-DEMO",
    reason: "Em muốn tìm hiểu chuyên sâu về trí tuệ nhân tạo.",
  },
  {
    email: "binh.tt@myfap.local",
    status: "REJECTED",
    target: "IS-DEMO",
    reason: "Em muốn chuyển sang ngành Hệ thống thông tin.",
  },
  {
    email: "cuong.lh@myfap.local",
    status: "APPROVED",
    target: "DS-DEMO",
    reason: "Em muốn học chuyên sâu về khoa học dữ liệu.",
  },
];

async function seedTransferDemo() {
  return transaction(async (session) => {
    const staff = await userRepository.findOne(
      {
        email: "staff@myfap.local",
        role: "STAFF",
        name: "Demo STAFF",
        active: true,
      },
      { session },
    );
    const source = await majorRepository.findOne(
      { code: "SE-DEMO", active: true },
      { session },
    );
    const ai = await majorRepository.findOne(
      { code: "AI-DEMO", active: true },
      { session },
    );
    if (!staff || !source || !ai)
      throw new Error(
        "Cần chạy seed demo gốc trước; không thay đổi database chưa có tài khoản/ngành demo.",
      );
    const termData = nextTerm();
    const term = await semesterRepository.findOne(
      { code: termData.code },
      { session },
    );
    if (!term || +term.start_at !== +termData.start_at)
      throw new Error(
        "Học kỳ tiếp theo chưa được seed hoặc không khớp lịch chuẩn.",
      );

    const majors = new Map([["AI-DEMO", ai]]);
    for (const item of [
      {
        code: "IS-DEMO",
        name: "Hệ thống thông tin (demo)",
        course_ids: source.course_ids,
      },
      {
        code: "DS-DEMO",
        name: "Khoa học dữ liệu (demo)",
        course_ids: ai.course_ids,
      },
    ]) {
      let major = await majorRepository.findOne(
        { code: item.code },
        { session },
      );
      if (!major) {
        major = await majorRepository.create(
          { ...item, department_id: source.department_id },
          { session },
        );
        await audit(
          session,
          staff,
          "SEED_TRANSFER_MAJOR",
          "Major",
          major._id,
          null,
          major,
        );
      } else if (
        String(major.department_id) !== String(source.department_id) ||
        !major.active
      ) {
        throw new Error(
          `Ngành ${item.code} đã bị thay đổi; seed không ghi đè.`,
        );
      }
      majors.set(item.code, major);
    }

    const result = {
      majors: [...majors.keys()],
      created_requests: [],
      skipped_requests: [],
    };
    for (const item of samples) {
      const student = await userRepository.findOne(
        { email: item.email, role: "STUDENT", active: true },
        { session },
      );
      if (
        !student ||
        String(student.department_id) !== String(source.department_id)
      )
        throw new Error(
          `Thiếu sinh viên demo ${item.email}; seed không thay đổi tài khoản khác.`,
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
      if (
        String(student.major_id) !== String(source._id) ||
        (await majorTransferRepository.exists(
          { student_id: student._id },
          { session },
        ))
      ) {
        result.skipped_requests.push(item.email);
        continue;
      }
      const reviewed = item.status !== "PENDING";
      const request = await majorTransferRepository.create(
        {
          student_id: student._id,
          from_major_id: source._id,
          to_major_id: majors.get(item.target)._id,
          from_department_id: source.department_id,
          to_department_id: source.department_id,
          reason: item.reason,
          status: item.status,
          effective_semester_id: term._id,
          effective_at: term.start_at,
          ...(reviewed
            ? {
                reviewer_id: staff._id,
                review_note:
                  item.status === "APPROVED"
                    ? "Đủ điều kiện chuyển ngành từ kỳ tiếp theo."
                    : "Chưa đủ điều kiện chuyển ngành trong kỳ này.",
                reviewed_at: new Date(),
              }
            : {}),
        },
        { session },
      );
      await audit(
        session,
        staff,
        "SEED_TRANSFER_REQUEST",
        "MajorTransfer",
        request._id,
        null,
        request,
      );
      result.created_requests.push({ email: item.email, status: item.status });
    }
    return result;
  });
}

try {
  await connect();
  await initialize();
  console.log(JSON.stringify(await seedTransferDemo(), null, 2));
} catch (error) {
  console.error("Không tạo được dữ liệu chuyển ngành demo:", error.message);
  process.exitCode = 1;
} finally {
  await disconnect();
}
