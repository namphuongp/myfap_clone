import test from "node:test";
import assert from "node:assert/strict";
import request from "supertest";
import { createApp } from "../src/app.js";
import { checkVersion, hash, token, parse, id } from "../src/core.js";
import { db } from "../src/db.js";
const app = createApp();
test.after(() => db.destroy());
test("Từ chối API riêng tư khi thiếu token", async () => {
  await request(app).get("/api/sections").expect(401);
});
test("Từ chối token sai định dạng trước truy vấn DB", async () => {
  await request(app)
    .get("/api/auth/me")
    .set("Authorization", "Bearer abc")
    .expect(401);
});
test("Từ chối NoSQL operator trong email", async () => {
  await request(app)
    .post("/api/auth/login")
    .send({ email: { $ne: null }, password: "anything" })
    .expect(400);
});
test("Từ chối role tự gán trong payload đăng nhập", async () => {
  await request(app)
    .post("/api/auth/login")
    .send({ email: "a@demo.local", password: "x", role: "STAFF" })
    .expect(400);
});
test("Từ chối JSON lỗi", async () => {
  await request(app)
    .post("/api/auth/login")
    .set("Content-Type", "application/json")
    .send("{")
    .expect(400);
});
test("Token ngẫu nhiên 256 bit và chỉ lưu hash", () => {
  const a = token(),
    b = token();
  assert.match(a, /^[a-f0-9]{64}$/);
  assert.notEqual(a, b);
  assert.notEqual(hash(a), a);
});
test("Phiên bản cũ bị từ chối", () => {
  assert.throws(
    () => checkVersion({ version: 2 }, 1),
    (e) => e.status === 409,
  );
  checkVersion({ version: 2 }, 2);
});
test("ID injection bị chặn", () => {
  assert.throws(() => parse(id, "1 OR 1=1"));
  assert.equal(parse(id, "12"), 12);
});
