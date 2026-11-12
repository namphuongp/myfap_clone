import test from "node:test";
import assert from "node:assert/strict";
import mongoose from "mongoose";
import { fixture } from "./fixtures.js";
import {
  ClassMembership,
  ActivityLog,
  ClassSession,
  Notice,
} from "../src/models/index.js";
import { databaseRepository } from "../src/repositories/database.repository.js";
import {
  migrateCollections,
  legacyCollections,
} from "../src/repositories/collection-migration.repository.js";

test("Migration 20 → 17 collection giữ khoảng lịch sử, version, log và điểm danh", async () => {
  let f;
  try {
    f = await fixture();
    assert.match(mongoose.connection.name, /_test$/);
    const db = mongoose.connection.db,
      member = await ClassMembership.findOne();
    const snapshot = JSON.stringify(
      (await ClassSession.findById(f.past._id)).toObject(),
    );
    const oldEnrollment = {
      _id: new mongoose.Types.ObjectId(),
      section_id: member.section_id,
      student_id: member.student_id,
      course_id: member.course_id,
      semester_id: member.semester_id,
      status: "ACTIVE",
      enrolled_at: member.starts_at,
      withdrawn_at: null,
      version: 7,
    };
    const closed = {
      _id: new mongoose.Types.ObjectId(),
      section_id: member.section_id,
      student_id: member.student_id,
      starts_at: new Date(+member.starts_at - 86400000),
      ends_at: new Date(+member.starts_at - 43200000),
      version: 0,
    };
    const open = {
      _id: member._id,
      section_id: member.section_id,
      student_id: member.student_id,
      starts_at: member.starts_at,
      ends_at: null,
      version: 0,
    };
    await ClassMembership.deleteMany({});
    await ActivityLog.deleteMany({});
    await db.collection("enrollments").insertOne(oldEnrollment);
    await db.collection("enrollmentperiods").insertMany([closed, open]);
    await db.collection("audits").insertOne({
      _id: new mongoose.Types.ObjectId(),
      actor_id: f.users.staff._id,
      action: "LEGACY_ACTION",
      entity: "User",
      entity_id: f.users.student._id,
      before_data: null,
      after_data: { kept: true },
      version: 0,
    });
    await db.collection("sessionhistories").insertOne({
      _id: new mongoose.Types.ObjectId(),
      session_id: f.past._id,
      actor_id: f.users.lecturer._id,
      action: "LEGACY_SESSION",
      before_data: null,
      after_data: { room_id: f.rooms[0]._id },
      version: 0,
    });
    const notice = await Notice.create({
      title: "Thông báo cũ",
      content: "Nội dung thông báo",
      created_by: f.users.staff._id,
    });
    await db.collection("noticereads").insertOne({
      _id: new mongoose.Types.ObjectId(),
      notice_id: notice._id,
      user_id: f.users.student._id,
      read_at: new Date(),
    });
    assert.equal((await migrateCollections()).sources.enrollmentperiods, 2);
    await assert.rejects(() => databaseRepository.initialize(), /db:migrate/);
    const result = await migrateCollections({ apply: true });
    assert.equal(result.collections.length, 17);
    for (const name of legacyCollections)
      assert.ok(!result.collections.includes(name));
    assert.equal(await ClassMembership.countDocuments(), 2);
    assert.equal((await ClassMembership.findById(open._id)).version, 7);
    assert.equal(
      String(
        (await ClassMembership.findById(open._id)).legacy_data.enrollment._id,
      ),
      String(oldEnrollment._id),
    );
    assert.equal(await ActivityLog.countDocuments(), 3);
    assert.equal(
      await ActivityLog.countDocuments({ category: "SESSION_HISTORY" }),
      1,
    );
    assert.ok(await ActivityLog.exists({ action: "READ_NOTICE" }));
    assert.equal(
      JSON.stringify((await ClassSession.findById(f.past._id)).toObject()),
      snapshot,
    );
    assert.equal(
      (await migrateCollections({ apply: true })).already_migrated,
      true,
    );
    await databaseRepository.initialize();
  } finally {
    if (f) await f.disconnect();
  }
});
