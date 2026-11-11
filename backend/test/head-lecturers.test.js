import test from "node:test";
import assert from "node:assert/strict";
import request from "supertest";
import bcrypt from "bcryptjs";
import { fixture } from "./fixtures.js";
import { disconnect } from "../src/config/database.js";
import { User, Department, Audit } from "../src/models/index.js";
test("Department lecturer management: scope, validation, lifecycle and session safety", async (t) => {
  try {
    assert.match(new URL(process.env.MONGODB_URI).pathname, /_test$/);
    const f = await fixture();
    const { as, users, app } = f;
    let lecturer, bearer;
    const password = "Lecturer@12345678";
    await t.test(
      "create fixes role/department, hashes password and redacts credentials from audit",
      async () => {
        const data = {
          user_code: "GV-NEW",
          name: "Giảng viên mới",
          email: "New.Lecturer@test.local",
          password,
          phone: "0901234567",
          address: "Hồ Chí Minh",
        };
        await as("student", "post", "/head/lecturers").send(data).expect(403);
        await as("staff", "get", "/head/lecturers").expect(403);
        await as("head", "post", "/head/lecturers")
          .send({ ...data, role: "HEAD" })
          .expect(400);
        await as("head", "post", "/head/lecturers")
          .send({ ...data, department_id: String(f.department._id) })
          .expect(400);
        await as("head", "post", "/head/lecturers")
          .send({ ...data, phone: "abc" })
          .expect(400);
        lecturer = (
          await as("head", "post", "/head/lecturers").send(data).expect(201)
        ).body;
        assert.equal(lecturer.email, "new.lecturer@test.local");
        assert.equal(lecturer.department_id, String(users.head.department_id));
        assert.equal(lecturer.active, true);
        assert.equal(lecturer.password_hash, undefined);
        assert.equal(lecturer.password, undefined);
        const stored = await User.findById(lecturer.id).select(
          "+password_hash",
        );
        assert.equal(stored.role, "LECTURER");
        assert.ok(await bcrypt.compare(password, stored.password_hash));
        const audit = await Audit.findOne({
          entity_id: lecturer.id,
          action: "HEAD_CREATE_LECTURER",
        });
        assert.ok(audit);
        assert.equal(audit.after_data.password_hash, undefined);
        assert.equal(audit.after_data.password, undefined);
        await as("head", "post", "/head/lecturers").send(data).expect(409);
        bearer = (
          await request(app)
            .post("/api/auth/login")
            .send({ email: lecturer.email, password })
            .expect(200)
        ).body.accessToken;
      },
    );
    await t.test(
      "search/filter/page and detail expose only lecturers of the account department",
      async () => {
        const foreign = await Department.create({
            code: "OTHER",
            name: "Bộ môn khác",
          }),
          other = await f.person("LECTURER", foreign._id);
        const list = (
          await as(
            "head",
            "get",
            "/head/lecturers?search=GV-NEW&status=ACTIVE&page=1",
          ).expect(200)
        ).body;
        assert.equal(list.total, 1);
        assert.equal(list.has_more, false);
        assert.equal(list.items[0].id, lecturer.id);
        assert.equal(
          (await as("head", "get", "/head/lecturers?search=.*").expect(200))
            .body.total,
          0,
        );
        assert.equal(
          (await as("head", "get", "/head/lecturers?page=2").expect(200)).body
            .items.length,
          0,
        );
        await as("head", "get", `/head/lecturers/${other.row._id}`).expect(404);
        await as("head", "patch", `/head/lecturers/${other.row._id}`)
          .send({ version: 0, name: "Forbidden" })
          .expect(404);
        await as("head", "get", `/head/lecturers/${users.student._id}`).expect(
          404,
        );
        await as("head", "patch", `/head/lecturers/${lecturer.id}`)
          .send({ version: 0, user_code: "CHANGED" })
          .expect(400);
        const detail = (
          await as(
            "head",
            "get",
            `/head/lecturers/${users.lecturer._id}`,
          ).expect(200)
        ).body;
        assert.equal(detail.teaching.total_sessions, 2);
        assert.equal(detail.teaching.upcoming_sessions, 1);
        assert.equal(detail.teaching.completed_sessions, 1);
        await as("head", "delete", `/head/lecturers/${lecturer.id}`).expect(
          404,
        );
      },
    );
    await t.test(
      "editing email revokes login, future teaching blocks deactivation, history remains",
      async () => {
        const updated = (
          await as("head", "patch", `/head/lecturers/${lecturer.id}`)
            .send({
              version: lecturer.version,
              email: "changed@test.local",
              name: "Tên cập nhật",
              phone: null,
            })
            .expect(200)
        ).body;
        assert.equal(updated.version, 1);
        assert.equal(updated.phone, null);
        await request(app)
          .get("/api/profile")
          .set("Authorization", `Bearer ${bearer}`)
          .expect(401);
        await as("head", "patch", `/head/lecturers/${lecturer.id}`)
          .send({ version: 0, name: "Stale" })
          .expect(409);
        await as("head", "patch", `/head/lecturers/${users.lecturer._id}`)
          .send({ version: users.lecturer.version, active: false })
          .expect(409);
        bearer = (
          await request(app)
            .post("/api/auth/login")
            .send({ email: "changed@test.local", password })
            .expect(200)
        ).body.accessToken;
        const inactive = (
          await as("head", "patch", `/head/lecturers/${lecturer.id}`)
            .send({ version: updated.version, active: false })
            .expect(200)
        ).body;
        await request(app)
          .get("/api/profile")
          .set("Authorization", `Bearer ${bearer}`)
          .expect(401);
        await request(app)
          .post("/api/auth/login")
          .send({ email: "changed@test.local", password })
          .expect(401);
        assert.equal(
          (
            await as("head", "get", "/head/lecturers?status=INACTIVE").expect(
              200,
            )
          ).body.total,
          1,
        );
        const active = (
          await as("head", "patch", `/head/lecturers/${lecturer.id}`)
            .send({ version: inactive.version, active: true })
            .expect(200)
        ).body;
        assert.equal(active.active, true);
        await request(app)
          .post("/api/auth/login")
          .send({ email: "changed@test.local", password })
          .expect(200);
        await request(app)
          .get("/api/profile")
          .set("Authorization", `Bearer ${bearer}`)
          .expect(401);
        assert.ok(await User.exists({ _id: lecturer.id }));
      },
    );
  } finally {
    await disconnect();
  }
});
