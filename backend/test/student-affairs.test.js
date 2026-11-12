import { applyDueMajorTransfers } from "../src/services/major-transfer.service.js";
import test from "node:test";
import assert from "node:assert/strict";
import { fixture } from "./fixtures.js";
import {
  ActivityLog,
  Major,
  MajorTransfer,
  Notice,
  User,
} from "../src/models/index.js";
import { semesterData, nextTerm } from "../src/utils/academic-calendar.js";
import { disconnect } from "../src/config/database.js";
import { databaseRepository } from "../src/repositories/database.repository.js";
test("Scope học vụ: hồ sơ chỉ đọc, thông báo và workflow chuyển ngành", async (t) => {
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
      "Không áp dụng lại đơn đã chuyển ngành trong quá khứ",
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
          applied_at: new Date(Date.now() - 86400000),
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
        assert.ok((await MajorTransfer.findById(old._id)).applied_at);
      },
    );
    await t.test(
      "Duyệt chuyển ngành chờ kỳ tới, chỉ áp dụng đúng hạn và không chạy lại",
      async () => {
        const target = await Major.create({
          code: "TRANSFER-TARGET",
          name: "Ngành đích",
          department_id: department._id,
          course_ids: [],
        });
        await as("student", "get", "/major-transfer-options")
          .expect(200)
          .then((r) =>
            assert.ok(r.body.some((row) => row.id === String(target._id))),
          );
        await as("staff", "post", "/major-transfer-requests")
          .send({ to_major_id: String(target._id), reason: "Lý do hợp lệ" })
          .expect(403);
        const created = await as("student", "post", "/major-transfer-requests")
          .send({
            to_major_id: String(target._id),
            reason: "Xin chuyển sang ngành đích",
          })
          .expect(201);
        assert.equal(created.body.status, "PENDING");
        const studentList = await as(
          "student",
          "get",
          "/major-transfer-requests?page=1",
        ).expect(200);
        assert.ok(
          studentList.body.items.some((row) => row.id === created.body.id),
        );
        const staffList = await as(
          "staff",
          "get",
          "/major-transfer-requests?status=PENDING",
        ).expect(200);
        assert.equal(
          staffList.body.items[0].student.user_code,
          users.student.user_code,
        );
        await as(
          "staff",
          "patch",
          `/major-transfer-requests/${created.body.id}/decision`,
        )
          .send({ version: 0, decision: "APPROVED", note: "Đã kiểm tra" })
          .expect(200);
        const updated = await User.findById(users.student._id);
        assert.equal(String(updated.major_id), String(major._id));
        const request = await MajorTransfer.findById(created.body.id);
        assert.equal(request.applied_at, null);
        assert.equal(+request.effective_at, +nextTerm().start_at);
        await applyDueMajorTransfers(
          new Date(+request.effective_at - 1),
          users.student._id,
        );
        assert.equal(
          String((await User.findById(users.student._id)).major_id),
          String(major._id),
        );
        await applyDueMajorTransfers(request.effective_at, users.student._id);
        assert.equal(
          String((await User.findById(users.student._id)).major_id),
          String(target._id),
        );
        assert.equal(
          await applyDueMajorTransfers(request.effective_at, users.student._id),
          0,
        );
        assert.equal(request.status, "APPROVED");
        assert.ok(
          await ActivityLog.exists({
            entity: "MajorTransfer",
            entity_id: request._id,
          }),
        );
        assert.ok(
          await ActivityLog.exists({
            action: "APPLY_MAJOR_TRANSFER",
            entity_id: users.student._id,
          }),
        );
        await as(
          "student",
          "patch",
          `/major-transfer-requests/${created.body.id}/decision`,
        )
          .send({ version: request.version, decision: "APPROVED", note: "No" })
          .expect(403);
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
    await t.test(
      "Migration index chuyển ngành giữ dữ liệu và chạy lặp lại an toàn",
      async () => {
        const student = await f.person("STUDENT");
        const legacyTransfer = await MajorTransfer.create({
          student_id: student.row._id,
          from_major_id: major._id,
          to_major_id: major._id,
          from_department_id: department._id,
          to_department_id: department._id,
          effective_at: new Date(),
          status: "APPROVED",
          reason: "Dữ liệu index cũ",
        });
        await MajorTransfer.collection.dropIndex(
          "major_transfer_one_pending_per_student",
        );
        await MajorTransfer.collection.createIndex(
          { student_id: 1 },
          {
            unique: true,
            partialFilterExpression: {
              status: { $in: ["PENDING", "APPROVED"] },
              applied_at: null,
            },
          },
        );

        await databaseRepository.initialize();
        await databaseRepository.initialize();

        assert.ok(await MajorTransfer.exists({ _id: legacyTransfer._id }));
        const index = (await MajorTransfer.collection.indexes()).find(
          (row) => row.name === "major_transfer_one_pending_per_student",
        );
        assert.deepEqual(index.partialFilterExpression, {
          status: "PENDING",
        });
      },
    );
  } finally {
    if (f) await f.disconnect();
    else await disconnect();
  }
});
