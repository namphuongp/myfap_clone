import test from "node:test";
import assert from "node:assert/strict";
import request from "supertest";
import mongoose from "mongoose";
import { connect, initialize, disconnect } from "../src/config/database.js";
import { seed } from "../src/services/seed.service.js";
import { createApp } from "../src/app.js";
import {
  User,
  Major,
  MajorTransfer,
  Semester,
  Course,
  Enrollment,
  EnrollmentPeriod,
  ClassSession,
  NoticeRead,
  Audit,
  Department,
} from "../src/models/index.js";
import { applyDueTransfers } from "../src/services/major.service.js";
import {
  semesterData,
  currentTerm,
  nextTerm,
} from "../src/utils/academic-calendar.js";

test("Học vụ: profile 4 role, lịch 3 kỳ, thông báo, chuyển ngành và báo cáo", async (t) => {
  try {
    await connect();
    assert.match(mongoose.connection.name, /_test$/);
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
    }
    const as = (role, method, path) =>
      request(app)
        [method](`/api${path}`)
        .set("Authorization", `Bearer ${tokens[role]}`);
    const source = await Major.findOne(),
      department = await Department.findOne(),
      oldCourse = await Course.findOne();
    const seededLessons = await ClassSession.find().sort({ start_at: 1 });
    let target,
      shared,
      nextSemester,
      oldUpcoming,
      sharedUpcoming,
      transferId,
      allNotice;
    await t.test(
      "Năm học Fall/Spring/Summer 3 tháng, nghỉ một tháng, xác định kỳ kế tiếp",
      async () => {
        const fall = semesterData("FALL", 2026);
        assert.equal(fall.start_at.toISOString(), "2026-08-31T17:00:00.000Z");
        assert.equal(fall.end_at.toISOString(), "2026-11-30T17:00:00.000Z");
        assert.equal(fall.academic_year, "2026-2027");
        assert.equal(currentTerm(new Date("2026-12-15T00:00:00Z")), null);
        assert.equal(
          nextTerm(new Date("2026-11-09T00:00:00Z")).code,
          "SPRING-2027",
        );
        assert.equal(
          nextTerm(new Date("2027-03-01T00:00:00Z")).code,
          "SUMMER-2027",
        );
        assert.equal(
          nextTerm(new Date("2027-07-01T00:00:00Z")).code,
          "FALL-2027",
        );
        await as("staff", "post", "/semesters")
          .send({
            code: "FREE",
            name: "Tự do",
            start_at: new Date().toISOString(),
            end_at: new Date().toISOString(),
          })
          .expect(400);
      },
    );
    await t.test(
      "Cả 4 role xem/sửa liên hệ; cấm sửa định danh/quyền/ngành/ảnh và version cũ",
      async () => {
        for (const role of ["student", "lecturer", "head", "staff"]) {
          const p = await as(role, "get", "/profile").expect(200);
          assert.equal(p.body.role, role.toUpperCase());
          assert.equal(p.body.password_hash, undefined);
          assert.equal(p.body.avatar_url, undefined);
          const update = await as(role, "patch", "/profile")
            .send({
              version: p.body.version,
              phone: "0901234567",
              address: `Liên hệ ${role}`,
              date_of_birth: "2000-01-01",
            })
            .expect(200);
          assert.equal(update.body.phone, "0901234567");
          await as(role, "patch", "/profile")
            .send({ version: p.body.version, phone: "0912345678" })
            .expect(409);
          await as(role, "patch", "/profile")
            .send({ version: update.body.version, role: "STAFF" })
            .expect(400);
          await as(role, "patch", "/profile")
            .send({
              version: update.body.version,
              avatar_url: "https://invalid.local/x",
            })
            .expect(400);
        }
        const p = await as("student", "get", "/profile").expect(200);
        await as("student", "patch", "/profile")
          .send({ version: p.body.version, major_id: String(source._id) })
          .expect(400);
        await as("student", "patch", "/profile")
          .send({ version: p.body.version, date_of_birth: "2999-01-01" })
          .expect(400);
      },
    );
    await t.test(
      "HEAD xem lịch bộ môn và đơn chuyển phòng riêng; không nhận quyền cán bộ hoặc duyệt nghỉ",
      async () => {
        await as(
          "head",
          "get",
          "/schedule?from=2026-11-01T00:00:00Z&to=2026-12-01T00:00:00Z",
        ).expect(200);
        await as("head", "get", "/sections").expect(403);
        await as("head", "get", "/leave-requests").expect(403);
        await as("head", "get", "/change-requests").expect(200);
        await as("head", "get", "/notices").expect(403);
        await as("student", "get", "/reports/attendance").expect(403);
        await as("lecturer", "post", "/notices").send({}).expect(403);
        await as(
          "student",
          "patch",
          "/major-transfer-requests/507f1f77bcf86cd799439011/decision",
        )
          .send({})
          .expect(403);
      },
    );
    await t.test(
      "Cán bộ cấu hình ngành và môn chung; tạo ngành không trao quyền cho sinh viên",
      async () => {
        const c = await as("staff", "post", "/courses")
          .send({
            code: "COMMON",
            name: "Môn dùng chung",
            department_id: String(department._id),
          })
          .expect(201);
        shared = c.body;
        const s = await Major.findById(source._id);
        await as("staff", "patch", `/majors/${source._id}/curriculum`)
          .send({
            version: s.version,
            course_ids: [String(oldCourse._id), shared.id],
          })
          .expect(200);
        const dep = await as("staff", "post", "/departments")
          .send({ code: "AI", name: "Trí tuệ nhân tạo" })
          .expect(201);
        const m = await as("staff", "post", "/majors")
          .send({
            code: "AI",
            name: "Ngành AI",
            department_id: dep.body.id,
            course_ids: [shared.id],
          })
          .expect(201);
        target = m.body;
        await as("student", "post", "/majors")
          .send({ code: "SPOOF", name: "X", department_id: dep.body.id })
          .expect(403);
        const list = await as("student", "get", "/majors").expect(200);
        assert.ok(list.body.some((m) => m.id === target.id));
      },
    );
    await t.test(
      "Thông báo: nháp ẩn, đúng đối tượng, đọc idempotent, lưu trữ và quá hạn",
      async () => {
        const draft = await as("staff", "post", "/notices")
          .send({
            title: "Thông báo học vụ",
            content: "Nội dung chung",
            audience: "ALL_STUDENTS",
          })
          .expect(201);
        allNotice = draft.body.id;
        await as("student", "get", `/notices/${allNotice}`).expect(404);
        await as("staff", "post", `/notices/${allNotice}/publish`)
          .send({ version: 0 })
          .expect(200);
        await as("student", "get", `/notices/${allNotice}`).expect(200);
        const reads = await Promise.all(
          [1, 2].map(() => as("student", "post", `/notices/${allNotice}/read`)),
        );
        assert.deepEqual(
          reads.map((r) => r.status),
          [200, 200],
        );
        assert.equal(
          await NoticeRead.countDocuments({
            notice_id: allNotice,
            user_id: users.student.id,
          }),
          1,
        );
        const targeted = await as("staff", "post", "/notices")
          .send({
            title: "Dành cho AI",
            content: "Nội dung ngành",
            audience: "MAJOR",
            major_ids: [target.id],
          })
          .expect(201);
        await as("staff", "post", `/notices/${targeted.body.id}/publish`)
          .send({ version: 0 })
          .expect(200);
        await as("student", "get", `/notices/${targeted.body.id}`).expect(404);
        await as("staff", "patch", `/notices/${allNotice}`)
          .send({ version: 1, title: "Sửa bản đã phát hành", content: "Sai" })
          .expect(409);
        await as("staff", "post", `/notices/${allNotice}/archive`)
          .send({ version: 1 })
          .expect(200);
        await as("student", "get", `/notices/${allNotice}`).expect(404);
        await as("student", "post", `/notices/${allNotice}/read`).expect(404);
        const expired = await as("staff", "post", "/notices")
          .send({
            title: "Cũ",
            content: "Đã hết hạn",
            expires_at: new Date(Date.now() - 86400000).toISOString(),
          })
          .expect(400);
        assert.equal(expired.status, 400);
      },
    );
    await t.test(
      "Đăng ký kỳ sau trước khi chuyển ngành: môn riêng và môn chung",
      async () => {
        const calendar = nextTerm();
        const r = await as("staff", "post", "/semesters")
          .send({ term: calendar.term, year: calendar.year })
          .expect(201);
        nextSemester = r.body;
        const room = (await as("staff", "get", "/rooms").expect(200)).body[0];
        const date = new Date(
          new Date(calendar.start_at).getTime() + 7 * 3600000 + 2 * 86400000,
        )
          .toISOString()
          .slice(0, 10);
        const section = async (code, courseId, slot) => {
          const s = await as("staff", "post", "/sections")
            .send({
              code,
              course_id: courseId,
              semester_id: nextSemester.id,
              lecturer_id: users.lecturer.id,
            })
            .expect(201);
          await as("staff", "post", "/sessions")
            .send({
              section_id: s.body.id,
              room_id: room.id,
              session_date: date,
              slot_id: slot,
            })
            .expect(201);
          await as("student", "post", `/sections/${s.body.id}/enrollments`)
            .send({})
            .expect(201);
          return s.body;
        };
        oldUpcoming = await section("OLD-NEXT", String(oldCourse._id), 1);
        sharedUpcoming = await section("SHARED-NEXT", shared.id, 2);
        const foreign = await as("staff", "post", "/courses")
          .send({
            code: "OTHER",
            name: "Môn ngoài ngành",
            department_id: String(department._id),
          })
          .expect(201);
        const s = await as("staff", "post", "/sections")
          .send({
            code: "OUTSIDE",
            course_id: foreign.body.id,
            semester_id: nextSemester.id,
            lecturer_id: users.lecturer.id,
          })
          .expect(201);
        await as("staff", "post", "/sessions")
          .send({
            section_id: s.body.id,
            room_id: room.id,
            session_date: date,
            slot_id: 3,
          })
          .expect(201);
        await as("student", "post", `/sections/${s.body.id}/enrollments`)
          .send({})
          .expect(409);
      },
    );
    await t.test(
      "Đơn chuyển ngành: kỳ sau do server xác định, chỉ một đơn, đúng quyền và duyệt đồng thời",
      async () => {
        await as("student", "post", "/major-transfer-requests")
          .send({ to_major_id: String(source._id), reason: "Giống ngành" })
          .expect(400);
        await as("student", "post", "/major-transfer-requests")
          .send({
            to_major_id: target.id,
            reason: "Tự chọn hiệu lực",
            effective_at: new Date().toISOString(),
          })
          .expect(400);
        const r = await as("student", "post", "/major-transfer-requests")
          .send({ to_major_id: target.id, reason: "Muốn đổi chuyên ngành" })
          .expect(201);
        transferId = r.body.id;
        assert.equal(r.body.effective_semester_id, nextSemester.id);
        await as("student", "post", "/major-transfer-requests")
          .send({ to_major_id: target.id, reason: "Gửi trùng" })
          .expect(409);
        await as(
          "lecturer",
          "patch",
          `/major-transfer-requests/${transferId}/decision`,
        )
          .send({ version: 0, decision: "APPROVED", note: "Không được duyệt" })
          .expect(403);
        const responses = await Promise.all(
          [1, 2].map(() =>
            as(
              "staff",
              "patch",
              `/major-transfer-requests/${transferId}/decision`,
            ).send({ version: 0, decision: "APPROVED", note: "Đồng ý kỳ sau" }),
          ),
        );
        assert.deepEqual(responses.map((r) => r.status).sort(), [200, 409]);
        assert.equal(
          String((await User.findById(users.student.id)).major_id),
          String(source._id),
        );
      },
    );
    await t.test(
      "Đúng đầu kỳ mới áp dụng, hủy môn riêng kỳ sau; giữ môn chung và lịch sử cũ",
      async () => {
        const transfer = await MajorTransfer.findById(transferId);
        assert.deepEqual(
          await applyDueTransfers({
            studentId: users.student.id,
            now: new Date(transfer.effective_at.getTime() - 1),
          }),
          [],
        );
        const applied = await applyDueTransfers({
          studentId: users.student.id,
          now: transfer.effective_at,
        });
        assert.equal(applied.length, 1);
        const user = await User.findById(users.student.id);
        assert.equal(String(user.major_id), target.id);
        assert.equal(String(user.department_id), target.department_id);
        assert.equal(
          (
            await Enrollment.findOne({
              section_id: oldUpcoming.id,
              student_id: user._id,
            })
          ).status,
          "WITHDRAWN",
        );
        assert.equal(
          (
            await Enrollment.findOne({
              section_id: sharedUpcoming.id,
              student_id: user._id,
            })
          ).status,
          "ACTIVE",
        );
        assert.equal(
          (
            await Enrollment.findOne({
              section_id: seededLessons[0].section_id,
              student_id: user._id,
            })
          ).status,
          "ACTIVE",
        );
        const period = await EnrollmentPeriod.findOne({
          section_id: oldUpcoming.id,
          student_id: user._id,
        });
        assert.equal(
          period.ends_at.toISOString(),
          transfer.effective_at.toISOString(),
        );
        assert.deepEqual(
          await applyDueTransfers({
            studentId: user._id,
            now: transfer.effective_at,
          }),
          [],
        );
        const p = await as("student", "get", "/profile").expect(200);
        assert.equal(p.body.major.name, "Ngành AI");
        const notices = await as("student", "get", "/notices").expect(200);
        assert.ok(notices.body.items.some((n) => n.title === "Dành cho AI"));
      },
    );
    await t.test(
      "Báo cáo theo lớp/môn/giảng viên và đơn, không vượt phạm vi bộ môn",
      async () => {
        await as("head", "get", "/reports/attendance?group_by=SECTION").expect(
          200,
        );
        await as("head", "get", "/reports/attendance?group_by=COURSE").expect(
          200,
        );
        await as("head", "get", "/reports/attendance?group_by=LECTURER").expect(
          200,
        );
        const r = await as("head", "get", "/reports/requests").expect(200);
        assert.ok(
          r.body.major_transfers.some(
            (x) => x.status === "APPROVED" && x.count === 1,
          ),
        );
        const summary = await as("head", "get", "/department/summary").expect(
          200,
        );
        assert.ok(summary.body.sections > 0);
        assert.equal(summary.body.presence_rate, null);
        const dep = await Department.create({
          code: "OTHER",
          name: "Bộ môn ngoài",
        });
        const course = await Course.create({
          code: "OUT",
          name: "Môn ngoài",
          department_id: dep._id,
        });
        await as(
          "head",
          "get",
          `/reports/attendance?course_id=${course._id}`,
        ).expect(403);
      },
    );
    await t.test(
      "Đổi mật khẩu thu hồi mọi phiên, không lộ bí mật trong profile/audit",
      async () => {
        await as("student", "patch", "/profile/password")
          .send({ current_password: "Sai", new_password: "Changed@12345678" })
          .expect(400);
        await as("student", "patch", "/profile/password")
          .send({
            current_password: "Demo@12345678",
            new_password: "Changed@12345678",
          })
          .expect(200);
        await as("student", "get", "/profile").expect(401);
        await request(app)
          .post("/api/auth/login")
          .send({ email: "student@myfap.local", password: "Demo@12345678" })
          .expect(401);
        await request(app)
          .post("/api/auth/login")
          .send({ email: "student@myfap.local", password: "Changed@12345678" })
          .expect(200);
        const audits = await Audit.find({ action: "CHANGE_PASSWORD" }).lean();
        assert.equal(audits.length, 1);
        assert.ok(!JSON.stringify(audits).includes("Changed@12345678"));
        assert.ok(!JSON.stringify(audits).includes("password_hash"));
      },
    );
  } finally {
    await disconnect();
  }
});
