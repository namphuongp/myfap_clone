import assert from "node:assert/strict";
import request from "supertest";
import mongoose from "mongoose";
import { connect, initialize, disconnect } from "../src/config/database.js";
import { seed } from "../src/services/seed.service.js";
import { createApp } from "../src/app.js";
import {
  User,
  AuthSession,
  Department,
  Course,
  Semester,
  Room,
  Section,
  ClassSession,
  Major,
} from "../src/models/index.js";
import { token, hash } from "../src/utils/crypto.js";
import { localDate } from "../src/utils/slots.js";
import { createSession } from "../src/services/session.service.js";
export async function fixture() {
  await connect();
  assert.match(mongoose.connection.name, /_test$/, "Chỉ dùng DB test riêng");
  assert.equal(await User.countDocuments(), 0, "Cần DB test trống");
  await initialize();
  process.env.SEED_PASSWORD = "Demo@12345678";
  await seed();
  const app = createApp(),
    users = {},
    tokens = {};
  for (const role of ["student", "lecturer", "head", "staff"])
    users[role] = await User.findOne({ role: role.toUpperCase() });
  async function authenticate(key, user) {
    const bearer = token();
    await AuthSession.create({
      user_id: user._id,
      token_hash: hash(bearer),
      expires_at: new Date(Date.now() + 3600000),
    });
    users[key] = user;
    tokens[key] = bearer;
  }
  for (const key of Object.keys(users)) await authenticate(key, users[key]);
  const as = (role, method, path) =>
    request(app)
      [method](`/api${path}`)
      .set("Authorization", `Bearer ${tokens[role]}`);
  const department = await Department.findOne(),
    course = await Course.findOne(),
    semester = await Semester.findOne(),
    rooms = await Room.find().sort({ _id: 1 }),
    section = await Section.findOne(),
    major = await Major.findOne();
  const [past, future] = await ClassSession.find().sort({ start_at: 1 });
  let serial = 0;
  const password_hash = (
    await User.findById(users.student._id).select("+password_hash")
  ).password_hash;
  async function person(role, dept = department._id) {
    serial++;
    const row = await User.create({
      user_code: `FIX-${serial}`,
      name: `Fixture ${serial}`,
      email: `fixture${serial}@myfap.local`,
      password_hash,
      role,
      department_id: dept,
      ...(role === "STUDENT" ? { major_id: major._id } : {}),
    });
    const key = `fixture${serial}`;
    await authenticate(key, row);
    return { key, row };
  }
  const day = (offset) => localDate(new Date(Date.now() + offset * 86400000));
  // Buổi học được chuẩn bị bởi công cụ thiết lập, không khôi phục API xếp lịch đã bỏ.
  const lesson = (
    sectionId,
    offset,
    slot,
    roomId = rooms[0]._id,
    lecturerId = null,
  ) =>
    createSession(users.head, {
      section_id: String(sectionId),
      session_date: day(offset),
      slot_id: slot,
      room_id: String(roomId),
      lecturer_id: lecturerId,
    });
  return {
    app,
    as,
    users,
    tokens,
    authenticate,
    person,
    day,
    lesson,
    department,
    course,
    semester,
    rooms,
    section,
    major,
    past,
    future,
    disconnect,
  };
}
