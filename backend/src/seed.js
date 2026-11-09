import bcrypt from "bcryptjs";
import { connect, initialize, disconnect } from "./db.js";
import {
  Department,
  Course,
  Semester,
  User,
  Room,
  Section,
  Enrollment,
  EnrollmentPeriod,
  ClassSession,
} from "./models.js";
import { transaction } from "./core.js";
import { slotTimes, localDate } from "./slots.js";
export async function seed() {
  const password = process.env.SEED_PASSWORD;
  if (!password || password.length < 12 || Buffer.byteLength(password) > 72)
    throw new Error("SEED_PASSWORD cần >=12 ký tự và <=72 byte");
  const password_hash = await bcrypt.hash(password, 12);
  return transaction(async (session) => {
    if (await User.exists({}).session(session))
      throw new Error(
        "Seed chỉ chạy khi chưa có người dùng; không xóa dữ liệu",
      );
    const [department] = await Department.create(
      [{ code: "SE", name: "Kỹ thuật phần mềm" }],
      { session, ordered: true },
    );
    const users = {};
    for (const role of ["STUDENT", "LECTURER", "HEAD", "STAFF"]) {
      const [row] = await User.create(
        [
          {
            user_code: `DEMO-${role}`,
            name: `Demo ${role}`,
            email: `${role.toLowerCase()}@myfap.local`,
            password_hash,
            role,
            department_id: department._id,
          },
        ],
        { session, ordered: true },
      );
      users[role] = row;
    }
    const [course] = await Course.create(
      [
        {
          code: "PRM393",
          name: "Flutter Mobile",
          department_id: department._id,
        },
      ],
      { session, ordered: true },
    );
    const now = new Date();
    const year = now.getUTCFullYear();
    const [semester] = await Semester.create(
      [
        {
          code: `DEMO-${year}`,
          name: `Học kỳ demo ${year}`,
          start_at: new Date(Date.UTC(year - 1, 0, 1)),
          end_at: new Date(Date.UTC(year + 2, 0, 1)),
        },
      ],
      { session, ordered: true },
    );
    const [room] = await Room.create([{ name: "BE-301", capacity: 30 }], {
      session,
    });
    await Room.create([{ name: "BE-302", capacity: 30 }], {
      session,
      ordered: true,
    });
    const [section] = await Section.create(
      [
        {
          code: "SE20A-PRM393",
          course_id: course._id,
          semester_id: semester._id,
          department_id: department._id,
          lecturer_id: users.LECTURER._id,
          capacity: 30,
        },
      ],
      { session, ordered: true },
    );
    const enrolled_at = new Date(now.getTime() - 7 * 86400000);
    await Enrollment.create(
      [
        {
          section_id: section._id,
          student_id: users.STUDENT._id,
          course_id: course._id,
          semester_id: semester._id,
          enrolled_at,
        },
      ],
      { session, ordered: true },
    );
    await EnrollmentPeriod.create(
      [
        {
          section_id: section._id,
          student_id: users.STUDENT._id,
          starts_at: enrolled_at,
        },
      ],
      { session, ordered: true },
    );
    await ClassSession.create(
      [
        {
          section_id: section._id,
          lecturer_id: users.LECTURER._id,
          room_id: room._id,
          ...slotTimes(localDate(new Date(now.getTime() - 86400000)), 1),
          status: "COMPLETED",
        },
        {
          section_id: section._id,
          lecturer_id: users.LECTURER._id,
          room_id: room._id,
          ...slotTimes(localDate(new Date(now.getTime() + 86400000)), 1),
        },
      ],
      { session, ordered: true },
    );
  });
}
if (process.argv[1]?.endsWith("seed.js")) {
  try {
    await connect();
    await initialize();
    await seed();
    console.log("Đã tạo 4 tài khoản demo, danh mục và lịch theo slot");
  } finally {
    await disconnect();
  }
}
