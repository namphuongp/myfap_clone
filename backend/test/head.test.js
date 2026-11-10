import test from "node:test";
import assert from "node:assert/strict";
import request from "supertest";
import mongoose from "mongoose";
import { connect, initialize, disconnect } from "../src/config/database.js";
import { seed } from "../src/services/seed.service.js";
import { createApp } from "../src/app.js";
import {
  User,
  Department,
  Course,
  Section,
  ClassSession,
  Room,
  Audit,
  Leave,
  Change,
} from "../src/models/index.js";

test("HEAD: scoped courses, assignments and STAFF-approved room changes", async (t) => {
  try {
    // Guard before connecting/initializing so this suite never writes to a non-test database.
    const uri = process.env.MONGODB_URI;
    assert.match(new URL(uri).pathname, /_test$/);
    await connect();
    assert.equal(await User.countDocuments(), 0, "Use a fresh test database");
    await initialize();
    process.env.SEED_PASSWORD = "Demo@12345678";
    await seed();
    const app = createApp(),
      tokens = {},
      users = {};
    for (const role of ["head", "staff", "lecturer", "student"]) {
      const response = await request(app)
        .post("/api/auth/login")
        .send({
          email: `${role}@myfap.local`,
          password: process.env.SEED_PASSWORD,
        })
        .expect(200);
      tokens[role] = response.body.accessToken;
      users[role] = response.body.user;
    }
    const as = (role, method, path) =>
      request(app)
        [method](`/api${path}`)
        .set("Authorization", `Bearer ${tokens[role]}`);
    const ownCourse = await Course.findOne();
    const otherDepartment = await Department.create({
      code: "OTHER",
      name: "Bộ môn khác",
    });
    const otherCourse = await Course.create({
      code: "OTHER",
      name: "Ngoài bộ môn",
      department_id: otherDepartment._id,
    });
    const password_hash = (await User.findOne().select("+password_hash"))
      .password_hash;
    const newLecturer = await User.create({
      user_code: "GV002",
      name: "Giảng viên hai",
      email: "gv2@test.local",
      role: "LECTURER",
      active: true,
      password_hash,
      department_id: users.head.department_id,
    });
    const foreignLecturer = await User.create({
      user_code: "GV003",
      name: "Ngoài bộ môn",
      email: "gv3@test.local",
      role: "LECTURER",
      password_hash,
      department_id: otherDepartment._id,
    });
    const inactiveLecturer = await User.create({
      user_code: "GV004",
      name: "Ngừng hoạt động",
      email: "gv4@test.local",
      role: "LECTURER",
      active: false,
      password_hash,
      department_id: users.head.department_id,
    });
    const future = await ClassSession.findOne({
      start_at: { $gt: new Date() },
    });
    const existingSection = await Section.findById(future.section_id);
    const rooms = await Room.find().sort({ _id: 1 });
    let created, unplanned;
    await t.test(
      "course create/edit/search/pagination is department scoped, versioned and audited",
      async () => {
        await as("lecturer", "post", "/head/courses")
          .send({ code: "DENY", name: "Không có quyền" })
          .expect(403);
        await as("head", "post", "/head/courses")
          .send({
            code: "FORGE",
            name: "Fake",
            department_id: String(otherDepartment._id),
          })
          .expect(400);
        created = (
          await as("head", "post", "/head/courses")
            .send({ code: "HEAD101", name: "Học phần mới" })
            .expect(201)
        ).body;
        assert.equal(created.department_id, users.head.department_id);
        await as("head", "post", "/head/courses")
          .send({ code: "HEAD101", name: "Trùng mã" })
          .expect(409);
        const result = (
          await as("head", "get", "/head/courses?search=HEAD101&page=1").expect(
            200,
          )
        ).body;
        assert.equal(result.total, 1);
        assert.equal(result.has_more, false);
        assert.equal(
          (await as("head", "get", "/head/courses?search=.*").expect(200)).body
            .total,
          0,
        );
        assert.equal(
          (await as("head", "get", "/head/courses?page=2").expect(200)).body
            .items.length,
          0,
        );
        await as("head", "patch", `/head/courses/${created.id}`)
          .send({ version: 0, code: "HEAD101", name: "Tên mới" })
          .expect(200);
        await as("head", "patch", `/head/courses/${created.id}`)
          .send({ version: 0, code: "HEAD101", name: "Ghi đè" })
          .expect(409);
        await as("head", "patch", `/head/courses/${otherCourse._id}`)
          .send({ version: 0, code: "OTHER", name: "Xâm phạm" })
          .expect(403);
        await as("head", "patch", `/head/courses/${ownCourse._id}`)
          .send({ version: 0, code: "CHANGED", name: ownCourse.name })
          .expect(409);
        assert.ok(
          await Audit.exists({
            action: "HEAD_UPDATE_COURSE",
            entity_id: created.id,
          }),
        );
        const catalog = (await as("head", "get", "/courses").expect(200)).body;
        assert.ok(
          catalog.every((r) => r.department_id === users.head.department_id),
        );
      },
    );
    await t.test(
      "HEAD assigns same-department active lecturers before sessions; STAFF retains scheduling",
      async () => {
        unplanned = (
          await as("staff", "post", "/sections")
            .send({
              code: "HEAD-CLASS",
              course_id: created.id,
              semester_id: String(existingSection.semester_id),
              lecturer_id: users.lecturer.id,
            })
            .expect(201)
        ).body;
        const options = (await as("head", "get", "/head/options").expect(200))
          .body;
        assert.ok(
          options.courses.every(
            (r) => r.department_id === users.head.department_id,
          ),
        );
        assert.ok(
          options.lecturers.every(
            (r) =>
              r.department_id === users.head.department_id &&
              r.password_hash === undefined,
          ),
        );
        const rows = (
          await as("head", "get", "/head/sections?search=HEAD-CLASS").expect(
            200,
          )
        ).body.items;
        assert.equal(rows[0].session_count, 0);
        assert.equal(rows[0].lecturer, users.lecturer.name);
        await as("head", "patch", `/head/sections/${unplanned.id}/lecturer`)
          .send({ version: 0, lecturer_id: String(foreignLecturer._id) })
          .expect(403);
        await as("head", "patch", `/head/sections/${unplanned.id}/lecturer`)
          .send({ version: 0, lecturer_id: String(inactiveLecturer._id) })
          .expect(400);
        await as("head", "patch", `/head/sections/${unplanned.id}/lecturer`)
          .send({ version: 0, lecturer_id: String(newLecturer._id) })
          .expect(200);
        await as("head", "patch", `/head/sections/${unplanned.id}/lecturer`)
          .send({ version: 0, lecturer_id: users.lecturer.id })
          .expect(409);
        await as(
          "head",
          "patch",
          `/head/sections/${existingSection._id}/lecturer`,
        )
          .send({
            version: existingSection.version,
            lecturer_id: String(newLecturer._id),
          })
          .expect(409);
        const foreignSection = await Section.create({
          code: "FOREIGN",
          course_id: otherCourse._id,
          department_id: otherDepartment._id,
          semester_id: existingSection.semester_id,
          lecturer_id: foreignLecturer._id,
        });
        const foreignRoom = await Room.create({
          name: "FOREIGN-ROOM",
          capacity: 30,
        });
        const foreignLesson = await ClassSession.create({
          section_id: foreignSection._id,
          lecturer_id: foreignLecturer._id,
          room_id: foreignRoom._id,
          session_date: future.session_date,
          slot_id: future.slot_id,
          start_at: future.start_at,
          end_at: future.end_at,
        });
        await as("head", "post", "/change-requests")
          .send({
            session_id: String(foreignLesson._id),
            reason: "Không được gửi ngoài bộ môn",
            proposed_room_id: String(rooms[1]._id),
            proposed_date: future.session_date,
            proposed_slot_id: future.slot_id,
          })
          .expect(403);
        await as(
          "head",
          "patch",
          `/head/sections/${foreignSection._id}/lecturer`,
        )
          .send({ version: 0, lecturer_id: String(newLecturer._id) })
          .expect(403);
        await as(
          "head",
          "get",
          `/head/sections?course_id=${otherCourse._id}`,
        ).expect(403);
        await as("head", "post", "/sessions").send({}).expect(403);
        assert.ok(
          await Audit.exists({
            action: "HEAD_ASSIGN_LECTURER",
            entity_id: unplanned.id,
          }),
        );
      },
    );
    await t.test(
      "HEAD room request preserves timing, pending has no schedule effect, STAFF approval preserves approved leave",
      async () => {
        const leave = (
          await as("student", "post", "/leave-requests")
            .send({ session_id: String(future._id), reason: "Khám bệnh" })
            .expect(201)
        ).body;
        await as("lecturer", "patch", `/leave-requests/${leave.id}/decision`)
          .send({ version: 0, decision: "APPROVED", note: "Đồng ý" })
          .expect(200);
        const payload = {
          session_id: String(future._id),
          reason: "Cần chuyển phòng",
          proposed_room_id: String(rooms[1]._id),
          proposed_date: future.session_date,
          proposed_slot_id: future.slot_id,
        };
        await as("head", "post", "/change-requests")
          .send({ ...payload, proposed_slot_id: future.slot_id === 1 ? 2 : 1 })
          .expect(403);
        const small = await Room.create({ name: "SMALL", capacity: 20 });
        await as("head", "post", "/change-requests")
          .send({ ...payload, proposed_room_id: String(small._id) })
          .expect(409);
        const req = (
          await as("head", "post", "/change-requests").send(payload).expect(201)
        ).body;
        assert.equal(
          String((await ClassSession.findById(future._id)).room_id),
          String(future.room_id),
        );
        await as("head", "post", "/change-requests").send(payload).expect(409);
        assert.equal(
          (await as("head", "get", "/change-requests").expect(200)).body
            .items[0].requester_name,
          users.head.name,
        );
        assert.equal(
          (await as("lecturer", "get", "/change-requests").expect(200)).body
            .total,
          0,
        );
        await as("head", "patch", `/change-requests/${req.id}/decision`)
          .send({ version: 0, decision: "APPROVED", note: "Tự duyệt" })
          .expect(403);
        await as("staff", "patch", `/change-requests/${req.id}/decision`)
          .send({ version: 0, decision: "APPROVED", note: "Đồng ý đổi phòng" })
          .expect(200);
        const changed = await ClassSession.findById(future._id);
        assert.equal(String(changed.room_id), String(rooms[1]._id));
        assert.equal(changed.start_at.getTime(), future.start_at.getTime());
        assert.equal((await Leave.findById(leave.id)).status, "APPROVED");
        const start = future.start_at.getTime() - 86400000,
          end = future.end_at.getTime() + 86400000;
        const query = `?from=${encodeURIComponent(new Date(start).toISOString())}&to=${encodeURIComponent(new Date(end).toISOString())}`;
        for (const role of ["student", "lecturer", "head"]) {
          const rows = (await as(role, "get", `/schedule${query}`).expect(200))
            .body;
          assert.equal(
            rows.find((r) => r.id === String(future._id)).room_name,
            rooms[1].name,
          );
          assert.ok(rows.every((r) => r.attendance === undefined));
        }
        const second = (
          await as("head", "post", "/change-requests")
            .send({ ...payload, proposed_room_id: String(rooms[0]._id) })
            .expect(201)
        ).body;
        await as("staff", "patch", `/change-requests/${second.id}/decision`)
          .send({ version: 0, decision: "REJECTED", note: "Không cần đổi" })
          .expect(200);
        assert.equal(
          String((await ClassSession.findById(future._id)).room_id),
          String(rooms[1]._id),
        );
        assert.equal((await Change.findById(second.id)).status, "REJECTED");
      },
    );
    await t.test(
      "reports scope filters and HEAD cannot read or edit student attendance",
      async () => {
        const summary = (
          await as("head", "get", "/department/summary").expect(200)
        ).body;
        assert.equal(summary.sections, 2);
        await as(
          "head",
          "get",
          `/reports/attendance?course_id=${otherCourse._id}`,
        ).expect(403);
        await as("head", "get", `/sessions/${future._id}/attendance`).expect(
          403,
        );
        await as("head", "put", `/sessions/${future._id}/attendance`)
          .send({})
          .expect(403);
        await as("head", "get", "/leave-requests").expect(403);
        await as("head", "get", "/reports/requests").expect(200);
      },
    );
  } finally {
    await disconnect();
  }
});
