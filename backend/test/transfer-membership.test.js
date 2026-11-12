import test from "node:test";
import assert from "node:assert/strict";
import { fixture } from "./fixtures.js";
import {
  ClassMembership,
  ClassSession,
  Course,
  Department,
  Leave,
  Major,
  Section,
  Semester,
  User,
} from "../src/models/index.js";
import { applyDueMajorTransfers } from "../src/modules/shared/services/major-transfer.service.js";
import { nextTerm } from "../src/utils/academic-calendar.js";
import { slotTimes, localDate } from "../src/utils/slots.js";

test("Chuyển ngành đúng kỳ: giữ môn chung, kết thúc lớp ngoài ngành và giữ lịch sử", async () => {
  let f;
  try {
    f = await fixture();
    const { as, users, department, course, past, rooms } = f;
    const originalMembership = await ClassMembership.findOne({
      student_id: users.student._id,
    });
    const originalAttendance = JSON.stringify(
      (await ClassSession.findById(past._id)).attendance,
    );
    const targetDepartment = await Department.create({
      code: "NEW-DEPT",
      name: "Bộ môn mới",
    });
    const target = await Major.create({
      code: "NEW-MAJOR",
      name: "Ngành mới",
      department_id: targetDepartment._id,
      course_ids: [course._id],
    });
    const futureTermData = nextTerm();
    const term =
      (await Semester.findOne({ code: futureTermData.code })) ??
      (await Semester.create(futureTermData));
    const oldCourse = await Course.create({
      code: "OLD-ONLY",
      name: "Môn chỉ thuộc ngành cũ",
      department_id: department._id,
    });
    const oldSection = await Section.create({
      code: "OLD-NEXT-TERM",
      course_id: oldCourse._id,
      semester_id: term._id,
      department_id: department._id,
    });
    const member = await ClassMembership.create({
      section_id: oldSection._id,
      student_id: users.student._id,
      course_id: oldCourse._id,
      semester_id: term._id,
      starts_at: new Date(),
    });
    const timing = slotTimes(localDate(new Date(+term.start_at + 86400000)), 1);
    const lesson = await ClassSession.create({
      ...timing,
      section_id: oldSection._id,
      room_id: rooms[1]._id,
      lecturer_id: users.lecturer._id,
    });
    const leave = (
      await as("student", "post", "/leave-requests")
        .send({
          session_id: String(lesson._id),
          reason: "Xin nghỉ buổi học kỳ tới",
        })
        .expect(201)
    ).body;
    await as("lecturer", "patch", `/leave-requests/${leave.id}/decision`)
      .send({ version: 0, decision: "APPROVED", note: "Đồng ý" })
      .expect(200);
    const request = (
      await as("student", "post", "/major-transfer-requests")
        .send({
          to_major_id: String(target._id),
          reason: "Xin chuyển ngành học",
        })
        .expect(201)
    ).body;
    const approved = (
      await as(
        "staff",
        "patch",
        `/major-transfer-requests/${request.id}/decision`,
      )
        .send({ version: 0, decision: "APPROVED", note: "Đồng ý từ kỳ tới" })
        .expect(200)
    ).body;
    assert.equal(approved.applied_at, null);
    assert.equal(
      String((await User.findById(users.student._id)).major_id),
      String(f.major._id),
    );
    assert.equal((await ClassMembership.findById(member._id)).ends_at, null);
    await as("student", "post", "/major-transfer-requests")
      .send({
        to_major_id: String(target._id),
        reason: "Không được gửi đơn thứ hai khi chờ áp dụng",
      })
      .expect(409);
    await applyDueMajorTransfers(
      new Date(+term.start_at - 1),
      users.student._id,
    );
    assert.equal((await ClassMembership.findById(member._id)).ends_at, null);
    await applyDueMajorTransfers(term.start_at, users.student._id);
    const changed = await User.findById(users.student._id);
    assert.equal(String(changed.major_id), String(target._id));
    assert.equal(String(changed.department_id), String(targetDepartment._id));
    assert.equal(
      +(await ClassMembership.findById(member._id)).ends_at,
      +term.start_at,
    );
    assert.equal(
      (await ClassMembership.findById(originalMembership._id)).ends_at,
      null,
    );
    assert.equal((await Leave.findById(leave.id)).status, "CANCELLED");
    assert.equal(
      JSON.stringify((await ClassSession.findById(past._id)).attendance),
      originalAttendance,
    );
    assert.equal(
      await applyDueMajorTransfers(term.start_at, users.student._id),
      0,
    );
  } finally {
    if (f) await f.disconnect();
  }
});
