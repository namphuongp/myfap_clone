import { bootstrapAcademicCalendar } from "../src/services/academic-bootstrap.service.js";
import test from "node:test";
import assert from "node:assert/strict";
import mongoose from "mongoose";
import bcrypt from "bcryptjs";
import request from "supertest";
import { connect, initialize, disconnect } from "../src/config/database.js";
import {
  User,
  Department,
  ClassSession,
  Section,
  Semester,
  Enrollment,
  EnrollmentPeriod,
  Leave,
  Change,
  SessionHistory,
  ImportBatch,
  AuthSession,
  Audit,
} from "../src/models/index.js";
import { importSnapshot } from "../src/services/import.service.js";
import { normalizeLegacySessions } from "../src/services/legacy-repair.service.js";
import { createApp } from "../src/app.js";
import { hash } from "../src/utils/crypto.js";
import { localDate, slotTimes } from "../src/utils/slots.js";
test("Import MySQL → MongoDB nguyên tử, giữ dữ liệu/hash, idempotent và chuẩn hóa buổi cũ", async () => {
  try {
    await connect();
    assert.match(mongoose.connection.name, /_test$/);
    assert.equal(await User.countDocuments(), 0, "Cần database test trống");
    await initialize();
    const password_hash = await bcrypt.hash("Demo@12345678", 4);
    const past = localDate(new Date(Date.now() - 86400000)),
      future = localDate(new Date(Date.now() + 86400000));
    const timing = slotTimes(future, 2);
    const oldStart = new Date(`${past}T08:11:00+07:00`),
      oldEnd = new Date(`${past}T10:11:00+07:00`);
    const oldToken = "a".repeat(64);
    const snapshot = {
      format: "myfap-mysql-v1",
      tables: {
        users: [
          {
            id: 1,
            name: "SV cũ",
            email: "student@legacy.local",
            password_hash,
            role: "STUDENT",
            department: "SE",
            active: 1,
          },
          {
            id: 2,
            name: "GV cũ",
            email: "lecturer@legacy.local",
            password_hash,
            role: "LECTURER",
            department: "SE",
            active: 1,
          },
          {
            id: 3,
            name: "Cán bộ",
            email: "staff@legacy.local",
            password_hash,
            role: "STAFF",
            department: "SE",
            active: 1,
          },
        ],
        rooms: [{ id: 1, name: "OLD-ROOM", capacity: 40 }],
        sections: [
          {
            id: 1,
            code: "OLD-CLASS",
            course: "Môn cũ",
            department: "SE",
            lecturer_id: 2,
          },
        ],
        enrollments: [{ section_id: 1, student_id: 1 }],
        class_sessions: [
          {
            id: 1,
            section_id: 1,
            room_id: 1,
            start_at: oldStart.toISOString(),
            end_at: oldEnd.toISOString(),
            attendance_saved: 1,
            version: 2,
          },
          {
            id: 2,
            section_id: 1,
            room_id: 1,
            start_at: timing.start_at.toISOString(),
            end_at: timing.end_at.toISOString(),
            attendance_saved: 0,
            version: 0,
          },
        ],
        attendance: [
          {
            session_id: 1,
            student_id: 1,
            status: "ABSENT",
            updated_by: 2,
            updated_at: new Date().toISOString(),
          },
        ],
        auth_sessions: [
          {
            id: 1,
            user_id: 1,
            token_hash: hash(oldToken),
            expires_at: new Date(Date.now() + 3600000).toISOString(),
          },
        ],
        leave_requests: [
          {
            id: 1,
            session_id: 1,
            requester_id: 1,
            reason: "Lý do cũ",
            status: "APPROVED",
            reviewer_id: 2,
            review_note: "Đồng ý",
            version: 1,
          },
        ],
        change_requests: [
          {
            id: 1,
            session_id: 2,
            requester_id: 2,
            reason: "Đơn cũ",
            status: "APPROVED",
            reviewer_id: 3,
            proposed_room_id: 1,
            proposed_start: timing.start_at.toISOString(),
            proposed_end: timing.end_at.toISOString(),
            session_version: 0,
          },
        ],
        audit_logs: [
          {
            id: 1,
            actor_id: 2,
            action: "SAVE_ATTENDANCE",
            entity: "class_sessions",
            entity_id: 1,
          },
        ],
      },
    };
    const broken = structuredClone(snapshot);
    broken.tables.class_sessions[0].room_id = 999;
    await assert.rejects(() => importSnapshot(broken), /thiếu tham chiếu/);
    assert.equal(await User.countDocuments(), 0);
    assert.equal(await Department.countDocuments(), 0);
    assert.equal(await ImportBatch.countDocuments(), 0);
    const result = await importSnapshot(snapshot);
    assert.equal(result.already_imported, false);
    assert.equal(result.counts.users, 3);
    assert.equal(await User.countDocuments(), 3);
    assert.equal(await Enrollment.countDocuments(), 1);
    assert.equal(await AuthSession.countDocuments(), 1);
    assert.equal(await Audit.countDocuments(), 1);
    const imported = await User.findOne({ legacy_id: 1 }).select(
      "+password_hash",
    );
    assert.equal(imported.password_hash, password_hash);
    assert.equal(
      (await EnrollmentPeriod.findOne()).starts_at.toISOString(),
      "1970-01-01T00:00:00.000Z",
    );
    let lesson = await ClassSession.findOne({ legacy_id: 1 });
    assert.equal(lesson.start_at.toISOString(), oldStart.toISOString());
    assert.equal(lesson.attendance[0].status, "ABSENT");
    assert.equal(lesson.version, 2);
    assert.equal(lesson.slot_id, null);
    assert.equal((await Change.findOne()).original_start, null);
    const app = createApp();
    await request(app)
      .post("/api/auth/login")
      .send({ email: "student@legacy.local", password: "Demo@12345678" })
      .expect(200);
    await request(app)
      .get("/api/auth/me")
      .set("Authorization", `Bearer ${oldToken}`)
      .expect(200);
    assert.equal((await importSnapshot(snapshot)).already_imported, true);
    assert.equal(await User.countDocuments(), 3);
    const preview = await normalizeLegacySessions();
    assert.equal(preview.length, 1);
    assert.equal(
      (await ClassSession.findById(lesson._id)).start_at.toISOString(),
      oldStart.toISOString(),
    );
    assert.equal(await SessionHistory.countDocuments(), 0);
    const applied = await normalizeLegacySessions({ apply: true });
    assert.equal(applied.length, 1);
    lesson = await ClassSession.findById(lesson._id);
    assert.equal(lesson.slot_id, 1);
    assert.equal(
      lesson.start_at.toISOString(),
      slotTimes(past, 1).start_at.toISOString(),
    );
    assert.equal(
      lesson.end_at.toISOString(),
      slotTimes(past, 1).end_at.toISOString(),
    );
    assert.equal(lesson.status, "COMPLETED");
    assert.equal(lesson.attendance[0].status, "ABSENT");
    assert.equal((await Leave.findOne()).status, "INVALIDATED");
    const history = await SessionHistory.findOne();
    assert.equal(
      history.before_data.start_at.toISOString(),
      oldStart.toISOString(),
    );
    assert.equal(await SessionHistory.countDocuments(), 1);
    assert.deepEqual(await normalizeLegacySessions({ apply: true }), []);
    const semesterCount = await Semester.countDocuments();
    const termPreview = await bootstrapAcademicCalendar();
    assert.equal(termPreview.length, 1);
    assert.equal(await Semester.countDocuments(), semesterCount);
    const normalized = await bootstrapAcademicCalendar({ apply: true });
    assert.equal(normalized.length, 1);
    const section = await Section.findOne();
    const semester = await Semester.findById(section.semester_id);
    assert.ok(semester.term);
    assert.equal(
      String((await Enrollment.findOne()).semester_id),
      String(semester._id),
    );
    assert.deepEqual(await bootstrapAcademicCalendar({ apply: true }), []);
  } finally {
    await disconnect();
  }
});
