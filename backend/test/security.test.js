import test from "node:test";
import assert from "node:assert/strict";
import request from "supertest";
import { createApp } from "../src/app.js";
import { checkVersion } from "../src/utils/version.js";
import { hash, token } from "../src/utils/crypto.js";
import { parse, id } from "../src/validators/common.js";
import { disconnect } from "../src/config/database.js";
const app = createApp();
test.after(() => disconnect());
test("API riêng tư yêu cầu token", async () => {
  await request(app).get("/api/sections").expect(401);
});
test("Token sai định dạng bị chặn trước DB", async () => {
  await request(app)
    .get("/api/auth/me")
    .set("Authorization", "Bearer abc")
    .expect(401);
});
test("NoSQL operator trong email bị từ chối", async () => {
  await request(app)
    .post("/api/auth/login")
    .send({ email: { $ne: null }, password: "anything" })
    .expect(400);
});
test("Không tự gán role trong login", async () => {
  await request(app)
    .post("/api/auth/login")
    .send({ email: "a@demo.local", password: "x", role: "STAFF" })
    .expect(400);
});
test("JSON lỗi trả 400", async () => {
  await request(app)
    .post("/api/auth/login")
    .set("Content-Type", "application/json")
    .send("{")
    .expect(400);
});
test("Token 256 bit và hash khác token gốc", () => {
  const a = token(),
    b = token();
  assert.match(a, /^[a-f0-9]{64}$/);
  assert.notEqual(a, b);
  assert.notEqual(hash(a), a);
});
test("Version cũ trả conflict", () => {
  assert.throws(
    () => checkVersion({ version: 2 }, 1),
    (e) => e.status === 409,
  );
  checkVersion({ version: 2 }, 2);
});
test("Chỉ nhận ObjectId, chặn selector và ID dạng số", () => {
  assert.throws(() => parse(id, { $ne: null }));
  assert.throws(() => parse(id, "1 OR 1=1"));
  assert.throws(() => parse(id, 1));
  assert.equal(
    parse(id, "507f1f77bcf86cd799439011"),
    "507f1f77bcf86cd799439011",
  );
});
