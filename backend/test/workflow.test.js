import test from "node:test";
import assert from "node:assert/strict";
import { fixture } from "./fixtures.js";
import {
  ClassSession,
  Course,
  Department,
  Enrollment,
  EnrollmentPeriod,
  Leave,
  Change,
  Section,
  Audit,
  SessionHistory,
} from "../src/models/index.js";
import { databaseRepository } from "../src/repositories/database.repository.js";
test("Scope MVP: HEAD, phân công theo buổi, lịch sử, đăng ký, điểm danh và đơn", async (t) => {
  let f;
  try {
    f = await fixture();
    const {
      as,
      users,
      course,
      semester,
      department,
      rooms,
      section,
      past,
      future,
    } = f;
    const otherDept = await Department.create({
      code: "OTHER",
      name: "Bộ môn khác",
    });
    const b = await f.person("LECTURER"),
      outsider = await f.person("LECTURER", otherDept._id);
    let one, two, first, second;
    const assign = async (target, rows, expected = 200) =>
      as("head", "put", `/sections/${target}/assignments`)
        .send({ reason: "Phân công kiểm thử", assignments: rows })
        .expect(expected);
    await t.test(
      "API ngoài phạm vi trả 404, hồ sơ chỉ đọc ở server",
      async () => {
        for (const [method, path] of [
          ["patch", "/profile"],
          ["patch", "/profile/password"],
          ["get", "/auth/me"],
          ["post", "/majors"],
          ["get", "/major-transfer-requests"],
          ["post", "/major-transfer-requests"],
          ["get", "/departments"],
          ["post", "/departments"],
          ["post", "/semesters"],
          ["post", "/rooms"],
          ["post", "/users"],
          ["post", "/sessions"],
          ["patch", `/sessions/${future._id}/schedule`],
          ["patch", `/sessions/${future._id}/status`],
          ["get", `/sessions/${past._id}/history`],
          ["get", `/sessions/${past._id}/attendance-history`],
          ["get", `/sections/${section._id}/enrollments`],
          ["get", "/reports/requests"],
        ]) {
          let r = as("staff", method, path);
          if (method !== "get") r = r.send({});
          await r.expect(404);
        }
        for (const role of ["student", "lecturer", "head", "staff"]) {
          const r = await as(role, "get", "/profile").expect(200);
          assert.equal(r.body.role, role.toUpperCase());
          assert.equal(r.body.password_hash, undefined);
          assert.equal(r.body.phone, undefined);
          assert.equal(r.body.department, undefined);
          assert.equal(r.body.pending_major_transfer, undefined);
        }
      },
    );
    await t.test(
      "HEAD CRUD môn trong bộ môn, chặn giả mạo quyền và version cũ",
      async () => {
        await as("staff", "post", "/courses")
          .send({ code: "DENY", name: "Denied" })
          .expect(403);
        await as("head", "post", "/courses")
          .send({
            code: "SPOOF",
            name: "Spoof",
            department_id: String(otherDept._id),
          })
          .expect(400);
        const r = await as("head", "post", "/courses")
          .send({
            code: "NEW",
            name: "Môn mới",
            major_ids: [String(f.major._id)],
          })
          .expect(201);
        assert.equal(r.body.department_id, String(department._id));
        assert.ok(
          (await f.major.constructor.findById(f.major._id)).course_ids.some(
            (id) => String(id) === r.body.id,
          ),
        );
        const majors = await as("head", "get", "/majors").expect(200);
        assert.ok(majors.body.some((m) => m.id === String(f.major._id)));
        await as("student", "get", "/majors").expect(403);
        await as("head", "patch", `/courses/${r.body.id}`)
          .send({ version: 0, name: "Đã sửa" })
          .expect(200);
        await as("head", "patch", `/courses/${r.body.id}`)
          .send({ version: 0, name: "Ghi đè" })
          .expect(409);
        const membership = await as("head", "patch", `/courses/${r.body.id}`)
          .send({ version: 1, major_ids: [] })
          .expect(200);
        assert.equal(membership.body.version, 2);
        assert.ok(
          !(await f.major.constructor.findById(f.major._id)).course_ids.some(
            (id) => String(id) === r.body.id,
          ),
        );
        await as("head", "patch", `/courses/${r.body.id}`)
          .send({ version: 1, major_ids: [String(f.major._id)] })
          .expect(409);
        const foreign = await Course.create({
          code: "OTHER",
          name: "Môn ngoài",
          department_id: otherDept._id,
        });
        await as("head", "patch", `/courses/${foreign._id}`)
          .send({ version: 0, active: false })
          .expect(403);
        const list = await as("head", "get", "/courses").expect(200);
        assert.ok(
          list.body.every((c) => c.department_id === String(department._id)),
        );
      },
    );
    await t.test(
      "Migration chỉ thay index giảng viên, không thay document hoặc index khác",
      async () => {
        const before = await ClassSession.find().lean();
        await ClassSession.collection.dropIndex(
          "session_lecturer_slot_assigned",
        );
        await ClassSession.collection.createIndex(
          { lecturer_id: 1, session_date: 1, slot_id: 1 },
          {
            unique: true,
            partialFilterExpression: {
              status: { $in: ["SCHEDULED", "COMPLETED"] },
              slot_id: { $type: "number" },
            },
          },
        );
        await databaseRepository.initialize();
        await databaseRepository.initialize();
        assert.deepEqual(await ClassSession.find().lean(), before);
        const indexes = await ClassSession.collection.indexes();
        assert.ok(
          indexes.some((i) => i.name === "session_lecturer_slot_assigned"),
        );
        assert.ok(indexes.some((i) => i.key.room_id));
      },
    );
    await t.test(
      "Tạo lớp chưa có giảng viên, chỉ mở đăng ký sau khi có lịch; null không trùng nhau",
      async () => {
        const make = async (code) =>
          (
            await as("head", "post", "/sections")
              .send({
                code,
                course_id: String(course._id),
                semester_id: String(semester._id),
              })
              .expect(201)
          ).body;
        one = await make("UNASSIGNED-A");
        two = await make("UNASSIGNED-B");
        assert.equal(one.status, "CLOSED");
        assert.equal(one.lecturer_id, undefined);
        assert.equal(one.capacity, 30);
        await as("head", "post", "/sections")
          .send({
            code: "BAD",
            course_id: String(course._id),
            semester_id: String(semester._id),
            lecturer_id: String(users.lecturer._id),
          })
          .expect(400);
        await as("head", "patch", `/sections/${one.id}/status`)
          .send({ version: 0, status: "OPEN" })
          .expect(409);
        first = await f.lesson(one.id, 3, 3);
        second = await f.lesson(two.id, 3, 3, rooms[1]._id);
        const unassignedStudent = await f.person("STUDENT");
        await as(
          unassignedStudent.key,
          "post",
          `/sections/${two.id}/enrollments`,
        )
          .send({})
          .expect(409);
        assert.equal(first.lecturer_id, null);
        assert.equal(second.lecturer_id, null);
        await assert.rejects(
          f.lesson(two.id, 3, 3, rooms[0]._id),
          (e) => e.status === 409,
        );
        await as("head", "patch", `/sections/${one.id}/status`)
          .send({ version: 0, status: "OPEN" })
          .expect(200);
        await as("head", "patch", `/sections/${two.id}/status`)
          .send({ version: 0, status: "OPEN" })
          .expect(200);
        await as("staff", "get", "/sections").expect(403);
        await as(
          unassignedStudent.key,
          "post",
          `/sections/${two.id}/enrollments`,
        )
          .send({})
          .expect(201);
        await as(
          unassignedStudent.key,
          "post",
          `/sections/${two.id}/enrollments/${unassignedStudent.row._id}/withdraw`,
        )
          .send({ version: 0 })
          .expect(200);
      },
    );
    await t.test(
      "Phân công theo buổi: quyền, giới hạn bộ môn, version, buổi quá khứ",
      async () => {
        await as("lecturer", "put", `/sections/${one.id}/assignments`)
          .send({
            reason: "Không có quyền",
            assignments: [
              {
                session_id: first.id,
                lecturer_id: String(users.lecturer._id),
                version: 0,
              },
            ],
          })
          .expect(403);
        await assign(
          one.id,
          [
            {
              session_id: first.id,
              lecturer_id: String(outsider.row._id),
              version: 0,
            },
          ],
          400,
        );
        await assign(
          one.id,
          [
            {
              session_id: second.id,
              lecturer_id: String(users.lecturer._id),
              version: 0,
            },
          ],
          403,
        );
        await assign(
          section._id,
          [
            {
              session_id: String(past._id),
              lecturer_id: String(b.row._id),
              version: 0,
            },
          ],
          409,
        );
        await assign(one.id, [
          {
            session_id: first.id,
            lecturer_id: String(users.lecturer._id),
            version: 0,
          },
        ]);
        await assign(
          one.id,
          [
            {
              session_id: first.id,
              lecturer_id: String(b.row._id),
              version: 0,
            },
          ],
          409,
        );
        const people = await as("head", "get", "/lecturers").expect(200);
        assert.ok(!people.body.some((p) => p.id === String(outsider.row._id)));
        assert.ok(people.body.every((p) => !p.password_hash && !p.email));
      },
    );
    await t.test(
      "Đổi phân công kiểm tra trùng lịch và rollback toàn bộ đợt",
      async () => {
        const another = await f.lesson(two.id, 4, 2, rooms[1]._id);
        await assign(
          two.id,
          [
            {
              session_id: another.id,
              lecturer_id: String(users.lecturer._id),
              version: 0,
            },
            {
              session_id: second.id,
              lecturer_id: String(users.lecturer._id),
              version: 0,
            },
          ],
          409,
        );
        const stored = await ClassSession.findById(another.id);
        assert.equal(stored.lecturer_id, null);
        assert.equal(stored.version, 0);
        await assign(two.id, [
          { session_id: second.id, lecturer_id: String(b.row._id), version: 0 },
        ]);
      },
    );
    await t.test(
      "Hai người phân công cùng version chỉ một thay đổi thành công",
      async () => {
        const results = await Promise.all(
          [b.row._id, null].map((lecturer_id) =>
            as("head", "put", `/sections/${one.id}/assignments`).send({
              reason: "Đồng thời",
              assignments: [
                {
                  session_id: first.id,
                  lecturer_id: lecturer_id ? String(lecturer_id) : null,
                  version: 1,
                },
              ],
            }),
          ),
        );
        assert.deepEqual(results.map((r) => r.status).sort(), [200, 409]);
        const stored = await ClassSession.findById(first.id);
        await assign(one.id, [
          {
            session_id: first.id,
            lecturer_id: String(users.lecturer._id),
            version: stored.version,
          },
        ]);
      },
    );
    await t.test(
      "Cùng lớp nhiều giảng viên; dữ liệu cũ trên Section không cấp quyền buổi khác",
      async () => {
        const another = await f.lesson(
          one.id,
          4,
          1,
          rooms[0]._id,
          String(b.row._id),
        );
        await Section.updateOne(
          { _id: one.id },
          { $set: { lecturer_id: users.lecturer._id } },
        );
        await as(
          "lecturer",
          "get",
          `/sessions/${another.id}/attendance`,
        ).expect(403);
        await as(b.key, "get", `/sessions/${another.id}/attendance`).expect(
          200,
        );
        const list = await as(
          "lecturer",
          "get",
          `/sections/${one.id}/sessions`,
        ).expect(200);
        assert.ok(
          list.body.every((s) => s.lecturer_id === String(users.lecturer._id)),
        );
        const own = await as(
          b.key,
          "get",
          `/schedule?from=${new Date(Date.now() - 86400000).toISOString()}&to=${new Date(Date.now() + 7 * 86400000).toISOString()}`,
        ).expect(200);
        assert.ok(own.body.every((s) => s.lecturer_id === String(b.row._id)));
      },
    );
    await t.test(
      "Điểm danh đủ lớp, giữ legacy, chặn tương lai và ghi đè đồng thời",
      async () => {
        await as("lecturer", "put", `/sessions/${future._id}/attendance`)
          .send({
            version: 0,
            rows: [
              { student_id: String(users.student._id), status: "PRESENT" },
            ],
          })
          .expect(409);
        const results = await Promise.all(
          ["PRESENT", "ABSENT"].map((status) =>
            as("lecturer", "put", `/sessions/${past._id}/attendance`).send({
              version: 0,
              rows: [{ student_id: String(users.student._id), status }],
            }),
          ),
        );
        assert.deepEqual(results.map((r) => r.status).sort(), [200, 409]);
        assert.equal(
          await Audit.countDocuments({
            action: "SAVE_ATTENDANCE",
            entity_id: past._id,
          }),
          1,
        );
        await as("lecturer", "put", `/sessions/${past._id}/attendance`)
          .send({
            version: 1,
            rows: [{ student_id: String(users.student._id), status: "LATE" }],
          })
          .expect(400);
        await ClassSession.updateOne(
          { _id: past._id },
          { $set: { "attendance.0.status": "EXCUSED" } },
        );
        await as("lecturer", "put", `/sessions/${past._id}/attendance`)
          .send({
            version: 1,
            rows: [
              { student_id: String(users.student._id), status: "EXCUSED" },
            ],
          })
          .expect(200);
      },
    );
    await t.test(
      "Đổi người phụ trách giữ đơn nghỉ, hủy đề xuất cũ, lịch sử người cũ vẫn xem được",
      async () => {
        const leave = await as("student", "post", "/leave-requests")
          .send({ session_id: String(future._id), reason: "Khám bệnh" })
          .expect(201);
        await as(
          "lecturer",
          "patch",
          `/leave-requests/${leave.body.id}/decision`,
        )
          .send({ version: 0, decision: "APPROVED", note: "Đồng ý" })
          .expect(200);
        const change = await as("lecturer", "post", "/change-requests")
          .send({
            session_id: String(future._id),
            proposed_room_id: String(rooms[1]._id),
            proposed_date: future.session_date,
            proposed_slot_id: 1,
            reason: "Đổi phòng",
          })
          .expect(201);
        await assign(section._id, [
          {
            session_id: String(future._id),
            lecturer_id: String(b.row._id),
            version: 0,
          },
        ]);
        assert.equal((await Leave.findById(leave.body.id)).status, "APPROVED");
        assert.equal(
          (await Change.findById(change.body.id)).status,
          "CANCELLED",
        );
        const old = await as("lecturer", "get", "/change-requests").expect(200);
        assert.ok(
          old.body.items.some(
            (r) => r.id === change.body.id && r.status === "CANCELLED",
          ),
        );
        await as(
          "lecturer",
          "get",
          `/sessions/${future._id}/attendance`,
        ).expect(403);
        await as("lecturer", "get", `/sessions/${past._id}/attendance`).expect(
          200,
        );
        const current = await as(
          b.key,
          "get",
          `/sessions/${future._id}/attendance`,
        ).expect(200);
        assert.equal(current.body.rows[0].note, "Nghỉ có phép");
        const summary = await as(
          "head",
          "get",
          "/reports/attendance?group_by=LECTURER",
        ).expect(200);
        const a = summary.body.items.find(
            (r) => r.id === String(users.lecturer._id),
          ),
          rb = summary.body.items.find((r) => r.id === String(b.row._id));
        assert.ok(a.sessions > 0 && rb.sessions > 0);
        assert.ok(a.recorded_sessions > 0);
        assert.equal(rb.recorded_sessions, 0);
        assert.ok(
          await SessionHistory.exists({
            session_id: future._id,
            action: "ASSIGN_LECTURER",
          }),
        );
      },
    );
    await t.test(
      "Cán bộ duyệt đổi phòng giữ nghỉ phép; đổi slot vô hiệu đơn, có tên hiển thị",
      async () => {
        for (const slot of [1, 2]) {
          const r = await as(b.key, "post", "/change-requests")
            .send({
              session_id: String(future._id),
              proposed_room_id: String(rooms[1]._id),
              proposed_date: future.session_date,
              proposed_slot_id: slot,
              reason: "Thay đổi",
            })
            .expect(201);
          await as("head", "patch", `/change-requests/${r.body.id}/decision`)
            .send({ version: 0, decision: "APPROVED", note: "Sai quyền" })
            .expect(403);
          await as("staff", "patch", `/change-requests/${r.body.id}/decision`)
            .send({ version: 0, decision: "APPROVED", note: "Đã kiểm tra" })
            .expect(200);
          const l = await Leave.findOne({ session_id: future._id });
          assert.equal(l.status, slot === 1 ? "APPROVED" : "INVALIDATED");
        }
        const list = await as(b.key, "get", "/change-requests").expect(200);
        assert.ok(list.body.items[0].lesson.course);
        assert.ok(list.body.items[0].proposed_room_name);
      },
    );
    await t.test("Rút/đăng ký lại giữ lịch và điểm danh quá khứ", async () => {
      const enrollment = await Enrollment.findOne({
        student_id: users.student._id,
        section_id: section._id,
      });
      await as(
        "student",
        "post",
        `/sections/${section._id}/enrollments/${users.student._id}/withdraw`,
      )
        .send({ version: enrollment.version })
        .expect(200);
      assert.equal(
        (await ClassSession.findById(past._id)).attendance.length,
        1,
      );
      const range = `from=${new Date(Date.now() - 3 * 86400000).toISOString()}&to=${new Date(Date.now() + 3 * 86400000).toISOString()}`;
      const old = await as("student", "get", `/schedule?${range}`).expect(200);
      assert.ok(old.body.some((s) => s.id === String(past._id)));
      assert.ok(!old.body.some((s) => s.id === String(future._id)));
      await as("student", "post", `/sections/${section._id}/enrollments`)
        .send({})
        .expect(201);
      assert.equal(
        await EnrollmentPeriod.countDocuments({
          student_id: users.student._id,
          section_id: section._id,
        }),
        2,
      );
    });
    await t.test(
      "Lớp 30 chỗ, không cần giảng viên để đăng ký, tranh chỗ cuối nguyên tử",
      async () => {
        for (let i = 0; i < 29; i++) {
          const p = await f.person("STUDENT");
          await as(p.key, "post", `/sections/${one.id}/enrollments`)
            .send({})
            .expect(201);
        }
        const x = await f.person("STUDENT"),
          y = await f.person("STUDENT");
        const results = await Promise.all(
          [x, y].map((p) =>
            as(p.key, "post", `/sections/${one.id}/enrollments`).send({}),
          ),
        );
        assert.deepEqual(results.map((r) => r.status).sort(), [201, 409]);
        assert.equal(
          await Enrollment.countDocuments({
            section_id: one.id,
            status: "ACTIVE",
          }),
          30,
        );
        const p = await f.person("STUDENT");
        await as(p.key, "post", `/sections/${two.id}/enrollments`)
          .send({})
          .expect(201);
        await as(p.key, "post", `/sections/${one.id}/enrollments`)
          .send({})
          .expect(409);
      },
    );
    await t.test(
      "Ngừng môn chặn đăng ký mới, giữ lớp và lịch sử; báo cáo không vượt bộ môn",
      async () => {
        await as("head", "patch", `/courses/${course._id}`)
          .send({ version: 0, active: false })
          .expect(200);
        const p = await f.person("STUDENT");
        await as(p.key, "post", `/sections/${two.id}/enrollments`)
          .send({})
          .expect(409);
        const list = await as(p.key, "get", "/sections/available").expect(200);
        assert.ok(list.body.every((s) => s.course_id !== String(course._id)));
        assert.ok(await ClassSession.exists({ _id: past._id }));
        await as(
          "head",
          "get",
          `/reports/attendance?lecturer_id=${outsider.row._id}`,
        ).expect(403);
        await as("student", "get", "/reports/attendance").expect(403);
      },
    );
  } finally {
    if (f) await f.disconnect();
  }
});
