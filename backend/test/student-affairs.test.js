import test from "node:test";
import assert from "node:assert/strict";
import { fixture } from "./fixtures.js";
import { Major, MajorTransfer, Notice, User } from "../src/models/index.js";
import { semesterData, nextTerm } from "../src/utils/academic-calendar.js";
test("Scope học vụ: hồ sơ chỉ đọc, thông báo và lưu trữ chuyển ngành cũ", async (t) => {
  let f;
  try {
    f = await fixture();
    const { as, users, major, department, semester } = f;
    await t.test("Calendar 3 kỳ và 4 slot giữ nguyên", async () => {
      assert.equal(
        semesterData("FALL", 2026).start_at.toISOString(),
        "2026-08-31T17:00:00.000Z",
      );
      assert.equal(
        semesterData("SPRING", 2027).end_at.toISOString(),
        "2027-03-31T17:00:00.000Z",
      );
      assert.equal(
        nextTerm(new Date("2026-11-10T00:00:00Z")).code,
        "SPRING-2027",
      );
      const r = await as("student", "get", "/time-slots").expect(200);
      assert.equal(r.body.length, 4);
    });
    await t.test(
      "Không tự áp dụng chuyển ngành đã duyệt cũ khi đăng nhập/xác thực",
      async () => {
        const target = await Major.create({
          code: "ARCHIVE",
          name: "Ngành lưu trữ",
          department_id: department._id,
          course_ids: [],
        });
        const old = await MajorTransfer.create({
          student_id: users.student._id,
          from_major_id: major._id,
          to_major_id: target._id,
          from_department_id: department._id,
          to_department_id: department._id,
          effective_semester_id: semester._id,
          effective_at: new Date(Date.now() - 86400000),
          status: "APPROVED",
          reason: "Dữ liệu trước thu gọn",
          reviewer_id: users.staff._id,
        });
        await as("student", "get", "/profile").expect(200);
        const login = await (
          await import("supertest")
        )
          .default(f.app)
          .post("/api/auth/login")
          .send({ email: users.student.email, password: "Demo@12345678" })
          .expect(200);
        assert.ok(login.body.accessToken);
        assert.equal(
          String((await User.findById(users.student._id)).major_id),
          String(major._id),
        );
        assert.equal((await MajorTransfer.findById(old._id)).applied_at, null);
      },
    );
    await t.test(
      "STAFF nháp/phát hành, đúng đối tượng; API ngoài scope bị gỡ",
      async () => {
        await as("lecturer", "post", "/notices")
          .send({ title: "Denied", content: "Denied" })
          .expect(403);
        const draft = await as("staff", "post", "/notices")
          .send({
            title: "Đăng ký môn",
            content: "Kiểm tra lịch",
            audience: "ALL_STUDENTS",
          })
          .expect(201);
        const before = await as("student", "get", "/notices").expect(200);
        assert.equal(before.body.items.length, 0);
        await as("student", "get", `/notices/${draft.body.id}`).expect(404);
        await as("staff", "post", `/notices/${draft.body.id}/publish`)
          .send({ version: 0 })
          .expect(200);
        const list = await as("student", "get", "/notices").expect(200);
        assert.equal(list.body.items[0].status, "PUBLISHED");
        await as("student", "post", `/notices/${draft.body.id}/read`)
          .send({})
          .expect(404);
        await as("staff", "patch", `/notices/${draft.body.id}`)
          .send({})
          .expect(404);
        await as("staff", "post", `/notices/${draft.body.id}/archive`)
          .send({})
          .expect(404);
        const hidden = await Notice.create({
          title: "Ngành khác",
          content: "Không cho xem",
          status: "PUBLISHED",
          audience: "MAJOR",
          major_ids: [],
          department_ids: [],
          created_by: users.staff._id,
          published_at: new Date(),
        });
        await as("student", "get", `/notices/${hidden._id}`).expect(404);
        const expired = await Notice.create({
          title: "Hết hạn",
          content: "Không cho xem",
          status: "PUBLISHED",
          audience: "ALL_STUDENTS",
          created_by: users.staff._id,
          published_at: new Date(Date.now() - 86400000),
          expires_at: new Date(Date.now() - 1000),
        });
        await as("student", "get", `/notices/${expired._id}`).expect(404);
      },
    );
  } finally {
    if (f) await f.disconnect();
  }
});
