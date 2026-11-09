import bcrypt from "bcryptjs";
import { db } from "./db.js";
export async function seed() {
  const password = process.env.SEED_PASSWORD;
  if (!password || password.length < 12)
    throw new Error("SEED_PASSWORD cần ít nhất 12 ký tự");
  const password_hash = await bcrypt.hash(password, 12);
  await db.transaction(async (trx) => {
    await trx("academic_lock").where({ id: 1 }).forUpdate().first();
    if (await trx("users").first())
      throw new Error(
        "Seed chỉ chạy khi chưa có người dùng; không xóa dữ liệu hiện có",
      );
    const ids = {};
    for (const role of ["STUDENT", "LECTURER", "HEAD", "STAFF"]) {
      const [key] = await trx("users").insert({
        name: `Demo ${role}`,
        email: `${role.toLowerCase()}@myfap.local`,
        password_hash,
        role,
        department: "SE",
      });
      ids[role] = key;
    }
    const [room] = await trx("rooms").insert({ name: "BE-301", capacity: 40 });
    await trx("rooms").insert({ name: "BE-302", capacity: 40 });
    const [section] = await trx("sections").insert({
      code: "SE20A-PRM393",
      course: "Flutter Mobile",
      department: "SE",
      lecturer_id: ids.LECTURER,
    });
    await trx("enrollments").insert({
      section_id: section,
      student_id: ids.STUDENT,
    });
    const now = Date.now();
    await trx("class_sessions").insert([
      {
        section_id: section,
        room_id: room,
        start_at: new Date(now - 7200000),
        end_at: new Date(now - 3600000),
      },
      {
        section_id: section,
        room_id: room,
        start_at: new Date(now + 86400000),
        end_at: new Date(now + 90000000),
      },
    ]);
  });
}
if (process.argv[1]?.endsWith("seed.js")) {
  try {
    await seed();
    console.log("Đã tạo tài khoản 4 vai trò và lịch mẫu");
  } finally {
    await db.destroy();
  }
}
