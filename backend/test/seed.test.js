import test from "node:test";
import assert from "node:assert/strict";
import mongoose from "mongoose";
import { connect, initialize, disconnect } from "../src/config/database.js";
import { seedAllDemo } from "../src/services/seed-demo.service.js";
import {
  User,
  Section,
  ClassSession,
  Course,
  Semester,
  ClassMembership,
} from "../src/models/index.js";
import { slotTimes, localDate } from "../src/utils/slots.js";

test("Unified demo seed: repeatability, preserved history and academic dates", async (t) => {
  const uri = new URL(process.env.MONGODB_URI);
  assert.match(uri.pathname, /_test$/);
  await connect();
  assert.equal(await User.countDocuments(), 0, "Cần database test trống");
  process.env.SEED_PASSWORD = "Demo@12345678";
  const now = new Date("2026-11-12T07:00:00Z");
  try {
    await initialize();
    await t.test(
      "one call creates all demo data and per-session lecturer assignments",
      async () => {
        const result = await seedAllDemo({ now });
        assert.equal(result.initialized, true);
        assert.equal(result.semester, "FALL-2026");
        assert.equal(await User.countDocuments(), 8);
        assert.equal(await Section.countDocuments(), 2);
        assert.equal(await Course.countDocuments(), 3);
        assert.equal(await Semester.countDocuments(), 9);
        assert.equal(await ClassMembership.countDocuments(), 10);
        const lessons = await ClassSession.find();
        assert.equal(lessons.length, 8);
        assert.ok(lessons.every((lesson) => lesson.lecturer_id));
        assert.equal(
          lessons.filter((lesson) => lesson.session_date === localDate(now))
            .length,
          2,
        );
        assert.ok(
          lessons
            .filter((lesson) => lesson.session_date < localDate(now))
            .every(
              (lesson) =>
                lesson.attendance_saved && lesson.attendance.length === 5,
            ),
        );
      },
    );
    await t.test(
      "rerun preserves attendance, password hashes, versions and withdrawn enrollments",
      async () => {
        const account = await User.findOne({ role: "LECTURER" }).select(
          "+password_hash",
        );
        const section = await Section.findOne({ code: "SE20A-PRM393" });
        const past = await ClassSession.findOne({
          section_id: section._id,
          session_date: "2026-11-11",
        });
        past.attendance[0].status = "ABSENT";
        await past.save();
        const snapshot = JSON.stringify(past.toObject());
        const enrollment = await ClassMembership.findOne({
          section_id: section._id,
        });
        enrollment.ends_at = now;
        await enrollment.save();
        const result = await seedAllDemo({ now });
        assert.equal(result.sessions_created, 0);
        assert.equal(await User.countDocuments(), 8);
        assert.equal(await ClassMembership.countDocuments(), 10);
        assert.equal(
          +(await ClassMembership.findById(enrollment._id)).ends_at,
          +now,
        );
        assert.equal(
          JSON.stringify((await ClassSession.findById(past._id)).toObject()),
          snapshot,
        );
        assert.equal(
          (await User.findById(account._id).select("+password_hash"))
            .password_hash,
          account.password_hash,
        );
      },
    );
    await t.test(
      "legacy course name reuses its ID and stable section without duplicate data",
      async () => {
        const course = await Course.findOne({ code: "PRM393" });
        course.code = "LEGACY-1";
        await course.save();
        // Mô phỏng document import cũ chưa lưu trường active.
        await Course.collection.updateOne(
          { _id: course._id },
          { $unset: { active: "" } },
        );
        const beforeCourse = await Course.collection.findOne({
          _id: course._id,
        });
        const section = await Section.findOne({ code: "SE20A-PRM393" });
        const beforeSection = JSON.stringify(section.toObject());
        const beforeEnrollments = JSON.stringify(
          await ClassMembership.find({ section_id: section._id })
            .sort({ _id: 1 })
            .lean(),
        );
        const beforePeriods = JSON.stringify(
          await ClassMembership.find({ section_id: section._id })
            .sort({ _id: 1 })
            .lean(),
        );
        const beforeLessons = JSON.stringify(
          await ClassSession.find({ section_id: section._id })
            .sort({ _id: 1 })
            .lean(),
        );
        for (let pass = 0; pass < 2; pass++) {
          const result = await seedAllDemo({ now });
          assert.equal(result.sessions_created, 0);
          assert.equal(await Course.countDocuments(), 3);
          assert.equal(await Course.countDocuments({ code: "PRM393" }), 0);
          assert.equal(await Section.countDocuments(), 2);
          assert.equal(
            await Section.countDocuments({ code: "SE20A-LEGACY-1" }),
            0,
          );
          assert.deepEqual(
            await Course.collection.findOne({ _id: course._id }),
            beforeCourse,
          );
          assert.equal(
            JSON.stringify((await Section.findById(section._id)).toObject()),
            beforeSection,
          );
          assert.equal(
            JSON.stringify(
              await ClassMembership.find({ section_id: section._id })
                .sort({ _id: 1 })
                .lean(),
            ),
            beforeEnrollments,
          );
          assert.equal(
            JSON.stringify(
              await ClassMembership.find({ section_id: section._id })
                .sort({ _id: 1 })
                .lean(),
            ),
            beforePeriods,
          );
          assert.equal(
            JSON.stringify(
              await ClassSession.find({ section_id: section._id })
                .sort({ _id: 1 })
                .lean(),
            ),
            beforeLessons,
          );
        }
      },
    );
    await t.test(
      "non-demo account blocks seeding before data changes",
      async () => {
        const student = await User.findOne({ role: "STUDENT" }).select(
          "+password_hash",
        );
        await User.create({
          user_code: "REAL-USER",
          name: "Real User",
          email: "real@example.test",
          role: "STUDENT",
          department_id: student.department_id,
          major_id: student.major_id,
          password_hash: student.password_hash,
        });
        const counts = [
          await User.countDocuments(),
          await ClassMembership.countDocuments(),
          await ClassSession.countDocuments(),
        ];
        await assert.rejects(seedAllDemo({ now }), /ngoài bộ demo/);
        assert.deepEqual(
          [
            await User.countDocuments(),
            await ClassMembership.countDocuments(),
            await ClassSession.countDocuments(),
          ],
          counts,
        );
      },
    );
    for (const date of [
      "2026-09-01T07:00:00Z",
      "2026-11-30T07:00:00Z",
      "2026-12-12T07:00:00Z",
    ]) {
      await t.test(`semester boundaries and break: ${date}`, async () => {
        // Chỉ reset đúng database test của ca kiểm thử, không dùng database ứng dụng.
        assert.equal(mongoose.connection.name, uri.pathname.slice(1));
        await mongoose.connection.dropDatabase();
        await initialize();
        const result = await seedAllDemo({ now: new Date(date) });
        assert.equal(
          result.semester,
          date.includes("12-12") ? "SPRING-2027" : "FALL-2026",
        );
        assert.equal(result.in_term_break, date.includes("12-12"));
        for (const lesson of await ClassSession.find()) {
          const section = await Section.findById(lesson.section_id);
          const semester = await Semester.findById(section.semester_id);
          assert.ok(
            lesson.start_at >= semester.start_at &&
              lesson.end_at <= semester.end_at,
          );
          const timing = slotTimes(lesson.session_date, lesson.slot_id);
          assert.equal(+lesson.start_at, +timing.start_at);
          assert.equal(+lesson.end_at, +timing.end_at);
        }
      });
    }
    await t.test(
      "invalid seed password stops without creating users",
      async () => {
        assert.equal(mongoose.connection.name, uri.pathname.slice(1));
        await mongoose.connection.dropDatabase();
        await initialize();
        process.env.SEED_PASSWORD = "short";
        await assert.rejects(seedAllDemo({ now }), /SEED_PASSWORD/);
        assert.equal(await User.countDocuments(), 0);
      },
    );
  } finally {
    await disconnect();
  }
});
