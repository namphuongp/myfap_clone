import test from "node:test";
import assert from "node:assert/strict";
import request from "supertest";
import { connect, initialize, disconnect } from "../src/db.js";
import mongoose from "mongoose";
import {
  Department,
  Course,
  Semester,
  User,
  AuthSession,
  Room,
  Section,
  Enrollment,
  EnrollmentPeriod,
  ClassSession,
  Leave,
  Change,
} from "../src/models.js";
import { seed } from "../src/seed.js";
import { createApp } from "../src/app.js";
import { token, hash } from "../src/core.js";
import { localDate } from "../src/slots.js";

test("MongoDB replica set: đăng ký 30 chỗ, slot, duyệt đơn, lịch sử, phân quyền và đồng thời", async (t) => {
  try {
    await connect();
    assert.match(
      mongoose.connection.name,
      /_test$/,
      "Database phải có hậu tố _test",
    );
    assert.equal(await User.countDocuments(), 0, "Cần database test trống");
    await initialize();
    process.env.SEED_PASSWORD = "Demo@12345678";
    await seed();
    const app = createApp(),
      tokens = {},
      users = {};
    for (const role of ["student", "lecturer", "head", "staff"]) {
      const r = await request(app)
        .post("/api/auth/login")
        .send({
          email: `${role}@myfap.local`,
          password: process.env.SEED_PASSWORD,
        })
        .expect(200);
      tokens[role] = r.body.accessToken;
      users[role] = r.body.user;
      assert.equal(r.body.user.password_hash, undefined);
    }
    const as = (role, method, path) =>
      request(app)
        [method](`/api${path}`)
        .set("Authorization", `Bearer ${tokens[role]}`);
    const course = await Course.findOne(),
      semester = await Semester.findOne(),
      department = await Department.findOne(),
      rooms = await Room.find().sort({ _id: 1 });
    const lessons = await ClassSession.find().sort({ start_at: 1 });
    const [past, future] = lessons;
    const day = (offset) => localDate(new Date(Date.now() + offset * 86400000));
    const createSection = async (
      code,
      courseId = String(course._id),
      lecturerId = users.lecturer.id,
    ) => {
      const r = await as("staff", "post", "/sections")
        .send({
          code,
          course_id: courseId,
          semester_id: String(semester._id),
          lecturer_id: lecturerId,
        })
        .expect(201);
      return r.body;
    };
    const createLesson = async (
      section,
      date,
      slot,
      room = String(rooms[0]._id),
    ) => {
      const r = await as("staff", "post", "/sessions")
        .send({
          section_id: section.id,
          room_id: room,
          session_date: date,
          slot_id: slot,
        })
        .expect(201);
      return r.body;
    };
    let counter = 0;
    const password_hash = (await User.findOne().select("+password_hash"))
      .password_hash;
    const newStudent = async () => {
      counter++;
      const user = await User.create({
        user_code: `FIXTURE-${counter}`,
        name: `Sinh viên ${counter}`,
        email: `fixture${counter}@myfap.local`,
        password_hash,
        role: "STUDENT",
        department_id: department._id,
      });
      const accessToken = token();
      await AuthSession.create({
        user_id: user._id,
        token_hash: hash(accessToken),
        expires_at: new Date(Date.now() + 3600000),
      });
      const role = `fixture${counter}`;
      tokens[role] = accessToken;
      return { id: String(user._id), role };
    };
    await t.test(
      "Đúng 4 slot, lớp 30 chỗ, phòng đủ sức chứa và giờ UTC+7",
      async () => {
        const r = await as("student", "get", "/time-slots").expect(200);
        assert.deepEqual(
          r.body.map((s) => [s.start_minute, s.end_minute]),
          [
            [450, 590],
            [600, 740],
            [770, 910],
            [920, 1060],
          ],
        );
        const section = await createSection("FIXED30");
        assert.equal(section.capacity, 30);
        await as("staff", "post", "/sections")
          .send({
            code: "BAD",
            course_id: String(course._id),
            semester_id: String(semester._id),
            lecturer_id: users.lecturer.id,
            capacity: 31,
          })
          .expect(400);
        const small = await as("staff", "post", "/rooms")
          .send({ name: "SMALL", capacity: 29 })
          .expect(201);
        await as("staff", "post", "/sessions")
          .send({
            section_id: section.id,
            room_id: small.body.id,
            session_date: day(2),
            slot_id: 1,
          })
          .expect(409);
        const lesson = await createLesson(section, day(2), 1);
        assert.equal(lesson.start_at, `${day(2)}T00:30:00.000Z`);
        assert.equal(lesson.end_at, `${day(2)}T02:50:00.000Z`);
        await as("staff", "post", "/sessions")
          .send({
            section_id: section.id,
            room_id: String(rooms[0]._id),
            session_date: day(2),
            slot_id: 5,
          })
          .expect(400);
      },
    );
    await t.test(
      "Đăng ký sau khi có lịch; chặn giả mạo và trùng môn trong kỳ",
      async () => {
        const section = await createSection("ENROLL_AFTER_SCHEDULE");
        const student = await newStudent();
        await as(student.role, "post", `/sections/${section.id}/enrollments`)
          .send({})
          .expect(409);
        await createLesson(section, day(3), 1);
        await as(student.role, "post", `/sections/${section.id}/enrollments`)
          .send({ student_id: users.student.id })
          .expect(400);
        await as(student.role, "post", `/sections/${section.id}/enrollments`)
          .send({})
          .expect(201);
        const r = await as(
          student.role,
          "get",
          `/sections/available?semester_id=${semester._id}`,
        ).expect(200);
        assert.equal(r.body.find((s) => s.id === section.id).remaining, 29);
        const other = await createSection("OTHER_SAME_COURSE");
        await createLesson(other, day(3), 2);
        await as(student.role, "post", `/sections/${other.id}/enrollments`)
          .send({})
          .expect(409);
      },
    );
    await t.test(
      "Chặn đăng ký trùng lịch, chọn lịch khác thành công",
      async () => {
        const c = await as("staff", "post", "/courses")
          .send({
            code: "SECOND",
            name: "Môn khác",
            department_id: String(department._id),
          })
          .expect(201);
        const gv = await User.create({
          user_code: "GV2",
          name: "Giảng viên hai",
          email: "gv2@myfap.local",
          password_hash,
          role: "LECTURER",
          department_id: department._id,
        });
        const section = await createSection(
          "COLLISION",
          c.body.id,
          String(gv._id),
        );
        const lesson = await createLesson(
          section,
          future.session_date,
          1,
          String(rooms[1]._id),
        );
        await as("student", "post", `/sections/${section.id}/enrollments`)
          .send({})
          .expect(409);
        await as("staff", "patch", `/sessions/${lesson.id}/schedule`)
          .send({
            version: 0,
            room_id: String(rooms[1]._id),
            session_date: day(4),
            slot_id: 1,
            reason: "Chọn lịch khác",
          })
          .expect(200);
        await as("student", "post", `/sections/${section.id}/enrollments`)
          .send({})
          .expect(201);
      },
    );
    await t.test(
      "Hai đăng ký đồng thời tranh chỗ thứ 30: đúng một thành công",
      async () => {
        const c = await as("staff", "post", "/courses")
          .send({
            code: "CAPACITY",
            name: "Kiểm tra chỗ",
            department_id: String(department._id),
          })
          .expect(201);
        const section = await createSection("LAST_SEAT", c.body.id);
        await createLesson(section, day(5), 1);
        for (let i = 0; i < 29; i++) {
          const student = await newStudent();
          await as(student.role, "post", `/sections/${section.id}/enrollments`)
            .send({})
            .expect(201);
        }
        const a = await newStudent(),
          b = await newStudent();
        const results = await Promise.all(
          [a, b].map((s) =>
            as(s.role, "post", `/sections/${section.id}/enrollments`).send({}),
          ),
        );
        assert.deepEqual(results.map((r) => r.status).sort(), [201, 409]);
        assert.equal(
          await Enrollment.countDocuments({
            section_id: section.id,
            status: "ACTIVE",
          }),
          30,
        );
      },
    );
    await t.test(
      "Nghỉ có phép: đổi phòng giữ đơn, đổi slot vô hiệu đơn và được gửi mới",
      async () => {
        const leave = await as("student", "post", "/leave-requests")
          .send({ session_id: String(future._id), reason: "Khám bệnh" })
          .expect(201);
        await as("staff", "patch", `/leave-requests/${leave.body.id}/decision`)
          .send({ version: 0, decision: "APPROVED", note: "OK" })
          .expect(403);
        await as(
          "lecturer",
          "patch",
          `/leave-requests/${leave.body.id}/decision`,
        )
          .send({ version: 0, decision: "APPROVED", note: "Đồng ý" })
          .expect(200);
        let attendance = await as(
          "student",
          "get",
          `/sessions/${future._id}/attendance`,
        ).expect(200);
        assert.equal(attendance.body.rows[0].note, "Nghỉ có phép");
        assert.equal(attendance.body.rows[0].status, "NOT_RECORDED");
        const change = await as("lecturer", "post", "/change-requests")
          .send({
            session_id: String(future._id),
            reason: "Đổi phòng",
            proposed_room_id: String(rooms[1]._id),
            proposed_date: future.session_date,
            proposed_slot_id: 1,
          })
          .expect(201);
        await as(
          "staff",
          "patch",
          `/change-requests/${change.body.id}/decision`,
        )
          .send({ version: 0, decision: "APPROVED", note: "OK" })
          .expect(200);
        assert.equal((await Leave.findById(leave.body.id)).status, "APPROVED");
        const change2 = await as("lecturer", "post", "/change-requests")
          .send({
            session_id: String(future._id),
            reason: "Đổi slot",
            proposed_room_id: String(rooms[1]._id),
            proposed_date: future.session_date,
            proposed_slot_id: 2,
          })
          .expect(201);
        await as(
          "staff",
          "patch",
          `/change-requests/${change2.body.id}/decision`,
        )
          .send({ version: 0, decision: "APPROVED", note: "OK" })
          .expect(200);
        assert.equal(
          (await Leave.findById(leave.body.id)).status,
          "INVALIDATED",
        );
        attendance = await as(
          "student",
          "get",
          `/sessions/${future._id}/attendance`,
        ).expect(200);
        assert.equal(attendance.body.rows[0].note, null);
        await as(
          "lecturer",
          "patch",
          `/leave-requests/${leave.body.id}/decision`,
        )
          .send({
            version: 1,
            decision: "APPROVED",
            note: "Không được duyệt lại",
          })
          .expect(409);
        await as("student", "post", "/leave-requests")
          .send({ session_id: String(future._id), reason: "Nghỉ slot mới" })
          .expect(201);
        const history = await as(
          "head",
          "get",
          `/sessions/${future._id}/history`,
        ).expect(200);
        assert.equal(history.body.length, 2);
        assert.ok(history.body[0].before_data);
        assert.ok(history.body[0].after_data);
        const stored = await Change.findById(change2.body.id);
        assert.equal(stored.original_slot_id, 1);
        assert.equal(stored.proposed_slot_id, 2);
      },
    );
    await t.test(
      "Điểm danh đủ lớp, lưu before/after và chống ghi đè đồng thời",
      async () => {
        await as("lecturer", "put", `/sessions/${future._id}/attendance`)
          .send({
            version: 2,
            rows: [{ student_id: users.student.id, status: "PRESENT" }],
          })
          .expect(409);
        const writes = await Promise.all(
          [1, 2].map(() =>
            as("lecturer", "put", `/sessions/${past._id}/attendance`).send({
              version: 0,
              rows: [{ student_id: users.student.id, status: "ABSENT" }],
            }),
          ),
        );
        assert.deepEqual(writes.map((r) => r.status).sort(), [200, 409]);
        await as("lecturer", "put", `/sessions/${past._id}/attendance`)
          .send({
            version: 1,
            rows: [{ student_id: users.student.id, status: "PRESENT" }],
          })
          .expect(200);
        const history = await as(
          "head",
          "get",
          `/sessions/${past._id}/attendance-history`,
        ).expect(200);
        assert.equal(history.body.length, 2);
        assert.equal(history.body[0].before_data.rows[0].status, "ABSENT");
        await as(
          "student",
          "get",
          `/sessions/${past._id}/attendance-history`,
        ).expect(403);
      },
    );
    await t.test(
      "Rút/đăng ký lại giữ điểm danh cũ và khoảng lịch sử",
      async () => {
        const e = await Enrollment.findOne({
          section_id: past.section_id,
          student_id: users.student.id,
        });
        await as(
          "student",
          "post",
          `/sections/${past.section_id}/enrollments/${users.student.id}/withdraw`,
        )
          .send({ version: e.version })
          .expect(200);
        const r = await as(
          "student",
          "get",
          `/sessions/${past._id}/attendance`,
        ).expect(200);
        assert.equal(r.body.rows[0].status, "PRESENT");
        await as("student", "post", `/sections/${past.section_id}/enrollments`)
          .send({})
          .expect(201);
        const periods = await EnrollmentPeriod.find({
          section_id: past.section_id,
          student_id: users.student.id,
        }).sort({ starts_at: 1 });
        assert.equal(periods.length, 2);
        assert.ok(periods[0].ends_at);
        assert.equal(periods[1].ends_at, null);
      },
    );
    await t.test(
      "Hủy buổi giải phóng slot; HEAD chỉ thấy bộ môn mình; lịch không lộ điểm danh",
      async () => {
        const section = await createSection("CANCEL");
        const lesson = await createLesson(section, day(6), 1);
        await as("staff", "patch", `/sessions/${lesson.id}/status`)
          .send({ version: 0, status: "CANCELLED", reason: "Nghỉ" })
          .expect(200);
        await as("lecturer", "put", `/sessions/${lesson.id}/attendance`)
          .send({
            version: 1,
            rows: [{ student_id: users.student.id, status: "PRESENT" }],
          })
          .expect(409);
        await createLesson(section, day(6), 1);
        const other = await Department.create({
          code: "OTHER",
          name: "Bộ môn khác",
        });
        await User.updateOne(
          { _id: users.head.id },
          { $set: { department_id: other._id } },
        );
        const list = await as("head", "get", "/sections").expect(200);
        assert.equal(list.body.length, 0);
        await as("head", "get", `/sessions/${past._id}/attendance`).expect(403);
        await User.updateOne(
          { _id: users.head.id },
          { $set: { department_id: department._id } },
        );
        const schedule = await as(
          "student",
          "get",
          `/schedule?from=${encodeURIComponent(new Date(Date.now() - 7 * 86400000).toISOString())}&to=${encodeURIComponent(new Date(Date.now() + 30 * 86400000).toISOString())}`,
        ).expect(200);
        assert.ok(schedule.body.length > 0);
        assert.equal(schedule.body[0].attendance, undefined);
      },
    );
    await t.test(
      "Một môn có nhiều kỳ/lớp và logout thu hồi token",
      async () => {
        const sem = await as("staff", "post", "/semesters")
          .send({
            code: "NEXT",
            name: "Kỳ sau",
            start_at: new Date(Date.now() + 100 * 86400000).toISOString(),
            end_at: new Date(Date.now() + 200 * 86400000).toISOString(),
          })
          .expect(201);
        await as("staff", "post", "/sections")
          .send({
            code: "SE20A-PRM393",
            course_id: String(course._id),
            semester_id: sem.body.id,
            lecturer_id: users.lecturer.id,
          })
          .expect(201);
        await as("student", "post", "/auth/logout").expect(204);
        await as("student", "get", "/auth/me").expect(401);
      },
    );
  } finally {
    await disconnect();
  }
});
