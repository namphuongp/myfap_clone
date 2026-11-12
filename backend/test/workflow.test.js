import test from "node:test";
import assert from "node:assert/strict";
import { fixture } from "./fixtures.js";
import { ClassSession, Department, Leave } from "../src/models/index.js";
import { localDate } from "../src/utils/slots.js";
test("Remaining workflows: attendance, lecturer requests and reports", async (t) => {
  let f;
  try {
    f = await fixture();
    const { as, users, rooms, past, future, section } = f;
    const attendanceNow = new Date();
    const attendanceSlot = {
      session_date: localDate(attendanceNow),
      start_at: new Date(attendanceNow.getTime() - 2 * 60 * 60 * 1000),
      end_at: new Date(attendanceNow.getTime() - 60 * 60 * 1000),
      legacy_unaligned: true,
    };
    await ClassSession.updateOne({ _id: past._id }, { $set: attendanceSlot });
    Object.assign(past, attendanceSlot);
    await t.test(
      "private profile remains read only and removed management APIs stay unavailable",
      async () => {
        await as("head", "post", "/courses").send({}).expect(404);
        await as("head", "put", `/sections/${section._id}/assignments`)
          .send({})
          .expect(404);
        for (const role of ["head", "student", "lecturer", "staff"]) {
          await as(role, "get", "/profile").expect(200);
          await as(role, "patch", "/profile").send({}).expect(404);
        }
      },
    );
    await t.test(
      "lecturer attendance is complete, versioned and unavailable before start",
      async () => {
        const roster = (
          await as(
            "lecturer",
            "get",
            `/sessions/${past._id}/attendance`,
          ).expect(200)
        ).body;
        const rows = roster.rows.map((r) => ({
          student_id: r.student_id,
          status: "PRESENT",
        }));
        await as("lecturer", "put", `/sessions/${future._id}/attendance`)
          .send({ version: future.version, rows })
          .expect(409);
        await as("lecturer", "put", `/sessions/${past._id}/attendance`)
          .send({ version: roster.version, rows })
          .expect(200);
        await as("lecturer", "put", `/sessions/${past._id}/attendance`)
          .send({ version: roster.version, rows })
          .expect(409);
        await as("head", "put", `/sessions/${past._id}/attendance`)
          .send({ version: 0, rows })
          .expect(403);
      },
    );
    await t.test(
      "lecturer submits room/time change, STAFF approves and room-only change preserves leave",
      async () => {
        const leave = (
          await as("student", "post", "/leave-requests")
            .send({
              session_id: String(future._id),
              reason: "Medical appointment",
            })
            .expect(201)
        ).body;
        await as("lecturer", "patch", `/leave-requests/${leave.id}/decision`)
          .send({ version: leave.version, decision: "APPROVED", note: "OK" })
          .expect(200);
        for (const slot of [1, 2]) {
          const change = (
            await as("lecturer", "post", "/change-requests")
              .send({
                session_id: String(future._id),
                proposed_date: future.session_date,
                proposed_slot_id: slot,
                proposed_room_id: String(rooms[1]._id),
                reason: "Room maintenance",
              })
              .expect(201)
          ).body;
          await as("head", "patch", `/change-requests/${change.id}/decision`)
            .send({ version: 0, decision: "APPROVED", note: "No access" })
            .expect(403);
          await as("staff", "patch", `/change-requests/${change.id}/decision`)
            .send({ version: 0, decision: "APPROVED", note: "OK" })
            .expect(200);
          assert.equal(
            (await Leave.findById(leave.id)).status,
            slot === 1 ? "APPROVED" : "INVALIDATED",
          );
        }
        const history = (
          await as("lecturer", "get", "/change-requests").expect(200)
        ).body;
        assert.ok(history.items[0].lesson.course);
        assert.ok(history.items[0].proposed_room_name);
      },
    );
    await t.test("Removed registration APIs are unavailable", async () => {
      await as("student", "get", "/sections/available").expect(404);
      await as("student", "get", "/me/enrollments").expect(404);
      await as("student", "post", `/sections/${section._id}/enrollments`)
        .send({})
        .expect(404);
      await as(
        "student",
        "post",
        `/sections/${section._id}/enrollments/${users.student._id}/withdraw`,
      )
        .send({ version: 0 })
        .expect(404);
      await as("head", "patch", `/sections/${section._id}/status`)
        .send({ version: 0, status: "OPEN" })
        .expect(404);
    });
    await t.test(
      "department reports do not expose other departments",
      async () => {
        const dept = await Department.create({ code: "OTHER", name: "Other" }),
          outsider = await f.person("LECTURER", dept._id);
        await as(
          "head",
          "get",
          `/reports/attendance?lecturer_id=${outsider.row._id}`,
        ).expect(403);
        await as("head", "get", "/department/summary").expect(200);
        await as("student", "get", "/reports/attendance").expect(403);
      },
    );
  } finally {
    if (f) await f.disconnect();
  }
});
