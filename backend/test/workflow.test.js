import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import request from "supertest";
import { db } from "../src/db.js";
import { createApp } from "../src/app.js";
import { seed } from "../src/seed.js";

// Chỉ chạy trên database riêng có hậu tố _test; không đụng schema đang sử dụng.
test(
  "MySQL: 4 vai trò, duyệt nghỉ, ghi chú, điểm danh, đổi lịch, đồng thời và logout",
  { skip: process.env.RUN_MYSQL_TESTS !== "1" },
  async () => {
    assert.match(
      process.env.DB_NAME ?? "",
      /_test$/,
      "DB_NAME phải kết thúc bằng _test",
    );
    assert.equal(
      await db.schema.hasTable("users"),
      false,
      "Cần database test trống",
    );
    try {
      const sql = await readFile(
        new URL("../schema.sql", import.meta.url),
        "utf8",
      );
      for (const statement of sql
        .split(";")
        .map((s) => s.trim())
        .filter(Boolean))
        await db.raw(statement);
      process.env.SEED_PASSWORD = "Demo@12345678";
      await seed();
      const app = createApp();
      const tokens = {};
      for (const role of ["student", "lecturer", "head", "staff"]) {
        const result = await request(app)
          .post("/api/auth/login")
          .send({
            email: `${role}@myfap.local`,
            password: process.env.SEED_PASSWORD,
          })
          .expect(200);
        tokens[role] = result.body.accessToken;
        assert.equal(result.body.user.password_hash, undefined);
      }
      const as = (role, method, path) =>
        request(app)
          [method](`/api${path}`)
          .set("Authorization", `Bearer ${tokens[role]}`);
      const lessons = await db("class_sessions").orderBy("id");
      const past = lessons[0],
        future = lessons[1];
      const student = await db("users").where({ role: "STUDENT" }).first();
      await as("student", "post", "/sessions").send({}).expect(403);
      await as("head", "get", "/department/summary").expect(200);
      const leave = await as("student", "post", "/leave-requests")
        .send({ session_id: future.id, reason: "Khám bệnh" })
        .expect(201);
      await as("staff", "patch", `/leave-requests/${leave.body.id}/decision`)
        .send({ version: 0, decision: "APPROVED", note: "Đồng ý" })
        .expect(403);
      await as("lecturer", "patch", `/leave-requests/${leave.body.id}/decision`)
        .send({ version: 0, decision: "APPROVED", note: "Đồng ý" })
        .expect(200);
      const attendance = await as(
        "student",
        "get",
        `/sessions/${future.id}/attendance`,
      ).expect(200);
      assert.equal(attendance.body.rows[0].note, "Nghỉ có phép");
      assert.equal(attendance.body.rows[0].status, "NOT_RECORDED");
      await as("lecturer", "put", `/sessions/${future.id}/attendance`)
        .send({
          version: 0,
          rows: [{ student_id: student.id, status: "PRESENT" }],
        })
        .expect(409);
      const writes = await Promise.all(
        [1, 2].map(() =>
          as("lecturer", "put", `/sessions/${past.id}/attendance`).send({
            version: 0,
            rows: [{ student_id: student.id, status: "ABSENT" }],
          }),
        ),
      );
      assert.deepEqual(writes.map((r) => r.status).sort(), [200, 409]);
      const room = await db("rooms").orderBy("id", "desc").first();
      const change = await as("lecturer", "post", "/change-requests")
        .send({
          session_id: future.id,
          reason: "Đổi phòng",
          proposed_room_id: room.id,
          proposed_start: future.start_at.toISOString(),
          proposed_end: future.end_at.toISOString(),
        })
        .expect(201);
      await as("staff", "patch", `/change-requests/${change.body.id}/decision`)
        .send({ version: 0, decision: "APPROVED", note: "Đồng ý" })
        .expect(200);
      assert.equal(
        (await db("class_sessions").where({ id: future.id }).first()).room_id,
        room.id,
      );
      await as("staff", "post", "/sessions")
        .send({
          section_id: future.section_id,
          room_id: room.id,
          start_at: future.start_at.toISOString(),
          end_at: future.end_at.toISOString(),
        })
        .expect(409);
      await as("student", "post", "/auth/logout").expect(204);
      await as("student", "get", "/auth/me").expect(401);
    } finally {
      await db.destroy();
    }
  },
);
