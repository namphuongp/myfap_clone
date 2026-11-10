import { connect, disconnect } from "../config/database.js";
import { bootstrapAcademicCalendar } from "../services/academic-bootstrap.service.js";
import {
  userRepository,
  courseRepository,
  sectionRepository,
  classSessionRepository,
  enrollmentRepository,
  enrollmentPeriodRepository,
  roomRepository,
} from "../repositories/index.js";
import { slotTimes } from "../utils/slots.js";
import bcrypt from "bcryptjs";

try {
  await connect();
  await bootstrapAcademicCalendar({ apply: true });

  // 1. Lấy thông tin Giảng viên và Sinh viên demo
  const lecturer = await userRepository.findOne({ role: "LECTURER" });
  const student = await userRepository.findOne({ role: "STUDENT" });
  if (!lecturer || !student) {
    throw new Error("Không tìm thấy tài khoản LECTURER hoặc STUDENT demo");
  }

  const departmentId = lecturer.department_id;
  const password = process.env.SEED_PASSWORD || "Demo@12345678";
  const password_hash = await bcrypt.hash(password, 10);

  // 2. Tạo thêm 4 sinh viên trong cùng bộ môn để lớp có sĩ số đẹp (tổng 5 SV)
  const additionalStudentsData = [
    { code: "SE180001", name: "Nguyễn Văn An", email: "an.nv@myfap.local" },
    { code: "SE180002", name: "Trần Thị Bình", email: "binh.tt@myfap.local" },
    { code: "SE180003", name: "Lê Hoàng Cường", email: "cuong.lh@myfap.local" },
    { code: "SE180004", name: "Phạm Thu Dung", email: "dung.pt@myfap.local" },
  ];

  const allStudents = [student];
  for (const item of additionalStudentsData) {
    let s = await userRepository.findOne({ email: item.email });
    if (!s) {
      const [created] = await userRepository.create([
        {
          user_code: item.code,
          name: item.name,
          email: item.email,
          password_hash,
          role: "STUDENT",
          department_id: departmentId,
          active: true,
        },
      ]);
      s = created;
    }
    allStudents.push(s);
  }

  // 3. Lấy các lớp mà giảng viên phụ trách
  const sections = await sectionRepository.find({
    lecturer_id: lecturer._id,
  });

  const prmSection = sections.find((s) => s.code.includes("PRM393"));
  const dbiSection = sections.find((s) => s.code.includes("DBI202"));

  const targetSections = [prmSection, dbiSection].filter(Boolean);
  const enrolledAt = new Date(Date.now() - 14 * 86400000);

  // 4. Đăng ký tất cả 5 sinh viên vào các lớp của giảng viên
  for (const sec of targetSections) {
    for (const st of allStudents) {
      const existingEnrollment = await enrollmentRepository.findOne({
        section_id: sec._id,
        student_id: st._id,
      });

      if (!existingEnrollment) {
        await enrollmentRepository.create([
          {
            section_id: sec._id,
            student_id: st._id,
            course_id: sec.course_id,
            semester_id: sec.semester_id,
            enrolled_at: enrolledAt,
            status: "ACTIVE",
          },
        ]);
      }

      const existingPeriod = await enrollmentPeriodRepository.findOne({
        section_id: sec._id,
        student_id: st._id,
      });

      if (!existingPeriod) {
        await enrollmentPeriodRepository.create([
          {
            section_id: sec._id,
            student_id: st._id,
            starts_at: enrolledAt,
            ends_at: null,
          },
        ]);
      }
    }
  }

  // 5. Cập nhật buổi học hôm qua (2026-11-09) - Đã điểm danh mẫu để sinh viên xem được
  const sessionYesterday = await classSessionRepository.findOne({
    section_id: prmSection?._id,
    session_date: "2026-11-09",
  });

  if (sessionYesterday) {
    sessionYesterday.status = "COMPLETED";
    sessionYesterday.attendance_saved = true;
    const now = new Date();
    sessionYesterday.attendance = [
      {
        student_id: student._id,
        status: "PRESENT",
        updated_by: lecturer._id,
        updated_at: now,
      },
      {
        student_id: allStudents[1]._id,
        status: "PRESENT",
        updated_by: lecturer._id,
        updated_at: now,
      },
      {
        student_id: allStudents[2]._id,
        status: "LATE",
        updated_by: lecturer._id,
        updated_at: now,
      },
      {
        student_id: allStudents[3]._id,
        status: "ABSENT",
        updated_by: lecturer._id,
        updated_at: now,
      },
      {
        student_id: allStudents[4]._id,
        status: "EXCUSED",
        updated_by: lecturer._id,
        updated_at: now,
      },
    ];
    await sessionYesterday.save();
    console.log("-> Đã cập nhật điểm danh mẫu cho buổi học 09/11 (PRM393)");
  }

  // 6. Thêm buổi học HÔM NAY (2026-11-10) cho lớp PRM393 để giảng viên có thể trực tiếp điểm danh ngay
  const room = await roomRepository.findOne({});
  const existingTodaySession = await classSessionRepository.findOne({
    section_id: prmSection?._id,
    session_date: "2026-11-10",
  });

  if (!existingTodaySession && prmSection && room) {
    const timing = slotTimes("2026-11-10", 1); // 07:30 - 09:50 sáng nay
    await classSessionRepository.create([
      {
        ...timing,
        section_id: prmSection._id,
        lecturer_id: lecturer._id,
        room_id: room._id,
        status: "COMPLETED",
        attendance_saved: false, // Chưa điểm danh để giảng viên vào điểm danh
        attendance: [],
      },
    ]);
    console.log("-> Đã tạo buổi học ngày 10/11 (Hôm nay - Slot 1) để Giảng viên thực hành điểm danh");
  }

  console.log("=== ĐỒNG BỘ DỮ LIỆU GIẢNG VIÊN VÀ SINH VIÊN HOÀN TẤT ===");
  console.log(`- Giảng viên: ${lecturer.name} (${lecturer.email})`);
  console.log(`- Sinh viên demo: ${student.name} (${student.email})`);
  console.log(`- Tổng số sinh viên trong lớp: ${allStudents.length}`);
  console.log(`- Các lớp đồng bộ: PRM393 (Flutter Mobile), DBI202 (Cơ sở dữ liệu)`);
} catch (e) {
  console.error("Lỗi:", e);
} finally {
  await disconnect();
}
