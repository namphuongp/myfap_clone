import { Router } from "express";
import { z } from "zod";
import {
  User,
  Course,
  Semester,
  Room,
  Section,
  Enrollment,
  EnrollmentPeriod,
  ClassSession,
  Leave,
  Audit,
  SessionHistory,
} from "./models.js";
import {
  body,
  id,
  version,
  text,
  date,
  parse,
  roles,
  get,
  fail,
  same,
  clean,
  checkVersion,
  transaction,
  sectionFilter,
  authorizeSection,
  audit,
} from "./core.js";
import { day, slotId, slotTimes } from "./slots.js";
import {
  enroll,
  withdraw,
  ensureSlot,
  rosterIds,
  authorizeLesson,
  recordSession,
  reschedule,
  cancelRequests,
} from "./academic.js";
async function decorate(rows) {
  const courses = await Course.find({
    _id: { $in: rows.map((s) => s.course_id) },
  });
  const semesters = await Semester.find({
    _id: { $in: rows.map((s) => s.semester_id) },
  });
  return rows.map((s) => ({
    ...clean(s),
    course: courses.find((c) => same(c._id, s.course_id))?.name,
    course_code: courses.find((c) => same(c._id, s.course_id))?.code,
    semester_code: semesters.find((t) => same(t._id, s.semester_id))?.code,
  }));
}
export function academicRoutes() {
  const router = Router();
  router.param("id", (req, res, next, key) => {
    try {
      req.resourceId = parse(id, key);
      next();
    } catch (e) {
      next(e);
    }
  });
  router.get(
    "/sections/available",
    roles("STUDENT", "STAFF"),
    async (req, res) => {
      const q = parse(
        body({ semester_id: id.optional(), course_id: id.optional() }),
        req.query,
      );
      const future = await ClassSession.distinct("section_id", {
        status: "SCHEDULED",
        slot_id: { $ne: null },
        start_at: { $gt: new Date() },
      });
      const filter = { _id: { $in: future }, status: "OPEN" };
      if (q.course_id) filter.course_id = q.course_id;
      if (q.semester_id) filter.semester_id = q.semester_id;
      const rows = await Section.find(filter).sort({ _id: 1 }).limit(200);
      const result = await decorate(rows);
      for (const row of result) {
        row.enrolled = await Enrollment.countDocuments({
          section_id: row.id,
          status: "ACTIVE",
        });
        row.remaining = 30 - row.enrolled;
      }
      res.json(result);
    },
  );
  router.get("/sections", async (req, res) =>
    res.json(
      await decorate(
        await Section.find(await sectionFilter(req.user))
          .sort({ _id: 1 })
          .limit(200),
      ),
    ),
  );
  router.post("/sections", roles("STAFF"), async (req, res) => {
    const data = parse(
      body({
        code: z.string().trim().min(1).max(80),
        course_id: id,
        semester_id: id,
        lecturer_id: id,
      }),
      req.body,
    );
    const result = await transaction(async (session) => {
      const course = await get(Course, data.course_id, session);
      const lecturer = await get(User, data.lecturer_id, session);
      const semester = await get(Semester, data.semester_id, session);
      if (
        lecturer.role !== "LECTURER" ||
        !lecturer.active ||
        !same(lecturer.department_id, course.department_id)
      )
        fail(400, "Giảng viên phải hoạt động và thuộc bộ môn của môn học");
      if (semester.end_at <= new Date()) fail(409, "Học kỳ đã kết thúc");
      const [row] = await Section.create(
        [{ ...data, department_id: course.department_id, capacity: 30 }],
        { session },
      );
      await audit(
        session,
        req.user,
        "CREATE_SECTION",
        "Section",
        row._id,
        null,
        row,
      );
      return clean(row);
    });
    res.status(201).json(result);
  });
  router.patch("/sections/:id/status", roles("STAFF"), async (req, res) => {
    const data = parse(
      body({ version, status: z.enum(["OPEN", "CLOSED"]) }),
      req.body,
    );
    const row = await transaction(async (session) => {
      const row = await get(Section, req.resourceId, session);
      checkVersion(row, data.version);
      const before = clean(row);
      row.status = data.status;
      await row.save({ session });
      await audit(
        session,
        req.user,
        "SET_SECTION_STATUS",
        "Section",
        row._id,
        before,
        row,
      );
      return clean(row);
    });
    res.json(row);
  });
  router.get("/me/enrollments", roles("STUDENT"), async (req, res) =>
    res.json(
      clean(
        await Enrollment.find({ student_id: req.user._id })
          .sort({ enrolled_at: -1 })
          .limit(200),
      ),
    ),
  );
  router.get("/sections/:id/enrollments", async (req, res) => {
    const section = await get(Section, req.resourceId);
    await authorizeSection(section, req.user);
    const filter = { section_id: section._id };
    if (req.user.role === "STUDENT") filter.student_id = req.user._id;
    const rows = await Enrollment.find(filter).sort({ _id: 1 }).limit(500);
    const students = await User.find({
      _id: { $in: rows.map((r) => r.student_id) },
    });
    res.json(
      rows.map((r) => ({
        ...clean(r),
        name: students.find((s) => same(s._id, r.student_id))?.name,
        user_code: students.find((s) => same(s._id, r.student_id))?.user_code,
      })),
    );
  });
  router.post(
    "/sections/:id/enrollments",
    roles("STUDENT", "STAFF"),
    async (req, res) => {
      const data = parse(
        req.user.role === "STUDENT" ? body({}) : body({ student_id: id }),
        req.body ?? {},
      );
      const key = req.user.role === "STUDENT" ? req.user._id : data.student_id;
      res
        .status(201)
        .json(
          await transaction((session) =>
            enroll(session, req.user, req.resourceId, key),
          ),
        );
    },
  );
  router.post(
    "/sections/:id/enrollments/:studentId/withdraw",
    roles("STUDENT", "STAFF"),
    async (req, res) => {
      const key = parse(id, req.params.studentId);
      if (req.user.role === "STUDENT" && !same(key, req.user._id))
        fail(403, "Chỉ được rút đăng ký của mình");
      const data = parse(body({ version }), req.body);
      res.json(
        await transaction((session) =>
          withdraw(session, req.user, req.resourceId, key, data.version),
        ),
      );
    },
  );
  router.get("/schedule", async (req, res) => {
    const q = parse(body({ from: date, to: date }), req.query);
    if (q.to <= q.from || q.to - q.from > 93 * 86400000)
      fail(400, "Khoảng xem lịch tối đa 93 ngày");
    const sections = await Section.find(await sectionFilter(req.user));
    let rows = await ClassSession.find({
      section_id: { $in: sections.map((s) => s._id) },
      start_at: { $lt: q.to },
      end_at: { $gt: q.from },
    })
      .sort({ start_at: 1 })
      .limit(1000);
    if (req.user.role === "STUDENT") {
      const periods = await EnrollmentPeriod.find({ student_id: req.user._id });
      rows = rows.filter((s) =>
        periods.some(
          (p) =>
            same(p.section_id, s.section_id) &&
            p.starts_at <= s.start_at &&
            (!p.ends_at || p.ends_at > s.start_at),
        ),
      );
    }
    const courses = await Course.find({
      _id: { $in: sections.map((s) => s.course_id) },
    });
    const rooms = await Room.find({ _id: { $in: rows.map((s) => s.room_id) } });
    res.json(
      rows.map((s) => {
        const section = sections.find((c) => same(c._id, s.section_id));
        const dto = clean(s);
        delete dto.attendance;
        return {
          ...dto,
          section_code: section.code,
          course_id: String(section.course_id),
          semester_id: String(section.semester_id),
          course: courses.find((c) => same(c._id, section.course_id))?.name,
          room_name: rooms.find((r) => same(r._id, s.room_id))?.name,
        };
      }),
    );
  });
  router.get("/sections/:id/sessions", async (req, res) => {
    const section = await get(Section, req.resourceId);
    if (req.user.role !== "STUDENT") await authorizeSection(section, req.user);
    const rows = clean(
      await ClassSession.find({ section_id: section._id })
        .sort({ start_at: 1 })
        .limit(1000),
    );
    for (const row of rows) delete row.attendance;
    res.json(rows);
  });
  router.post("/sessions", roles("STAFF"), async (req, res) => {
    const data = parse(
      body({ section_id: id, room_id: id, session_date: day, slot_id: slotId }),
      req.body,
    );
    const row = await transaction(async (session) => {
      const section = await get(Section, data.section_id, session);
      const timing = slotTimes(data.session_date, data.slot_id);
      if (timing.start_at <= new Date())
        fail(409, "Chỉ tạo buổi học tương lai");
      await ensureSlot(
        session,
        section,
        data.room_id,
        timing.start_at,
        timing.end_at,
      );
      const [row] = await ClassSession.create(
        [
          {
            ...timing,
            section_id: section._id,
            lecturer_id: section.lecturer_id,
            room_id: data.room_id,
          },
        ],
        { session },
      );
      await recordSession(session, req.user, "CREATE_SESSION", null, row);
      const dto = clean(row);
      delete dto.attendance;
      return dto;
    });
    res.status(201).json(row);
  });
  router.patch("/sessions/:id/schedule", roles("STAFF"), async (req, res) => {
    const data = parse(
      body({
        version,
        room_id: id,
        session_date: day,
        slot_id: slotId,
        reason: text,
      }),
      req.body,
    );
    const row = await transaction(async (session) => {
      const lesson = await get(ClassSession, req.resourceId, session);
      checkVersion(lesson, data.version);
      const row = await reschedule(session, req.user, lesson, data);
      await audit(
        session,
        req.user,
        "SCHEDULE_REASON",
        "ClassSession",
        row._id,
        null,
        { reason: data.reason },
      );
      return clean(row);
    });
    res.json(row);
  });
  router.patch("/sessions/:id/status", roles("STAFF"), async (req, res) => {
    const data = parse(
      body({
        version,
        status: z.enum(["COMPLETED", "CANCELLED"]),
        reason: text,
      }),
      req.body,
    );
    const result = await transaction(async (session) => {
      const row = await get(ClassSession, req.resourceId, session);
      checkVersion(row, data.version);
      if (row.status !== "SCHEDULED") fail(409, "Buổi đã kết thúc hoặc hủy");
      if (data.status === "COMPLETED" && row.end_at > new Date())
        fail(409, "Buổi học chưa kết thúc");
      if (
        data.status === "CANCELLED" &&
        (row.start_at <= new Date() || row.attendance_saved)
      )
        fail(409, "Không hủy buổi đã bắt đầu hoặc có điểm danh");
      const before = clean(row);
      row.status = data.status;
      await row.save({ session });
      if (data.status === "CANCELLED")
        await cancelRequests(session, req.user, row);
      await recordSession(session, req.user, "SET_SESSION_STATUS", before, row);
      await audit(
        session,
        req.user,
        "STATUS_REASON",
        "ClassSession",
        row._id,
        null,
        { reason: data.reason },
      );
      return clean(row);
    });
    res.json(result);
  });
  router.get(
    "/sessions/:id/history",
    roles("LECTURER", "HEAD", "STAFF"),
    async (req, res) => {
      const lesson = await get(ClassSession, req.resourceId);
      await authorizeLesson(lesson, req.user);
      res.json(
        clean(
          await SessionHistory.find({ session_id: lesson._id })
            .sort({ created_at: -1, _id: -1 })
            .limit(200),
        ),
      );
    },
  );
  router.get(
    "/sessions/:id/attendance-history",
    roles("LECTURER", "HEAD", "STAFF"),
    async (req, res) => {
      const lesson = await get(ClassSession, req.resourceId);
      await authorizeLesson(lesson, req.user);
      res.json(
        clean(
          await Audit.find({
            entity: "ClassSession",
            entity_id: lesson._id,
            action: "SAVE_ATTENDANCE",
          })
            .sort({ created_at: -1, _id: -1 })
            .limit(200),
        ),
      );
    },
  );
  router.get("/sessions/:id/attendance", async (req, res) => {
    const lesson = await get(ClassSession, req.resourceId);
    await authorizeLesson(lesson, req.user);
    let ids = await rosterIds(lesson);
    if (req.user.role === "STUDENT")
      ids = ids.filter((s) => same(s, req.user._id));
    const students = await User.find({ _id: { $in: ids } }).sort({ _id: 1 });
    const leaves = await Leave.find({
      session_id: lesson._id,
      status: "APPROVED",
      requested_start: lesson.start_at,
      requested_end: lesson.end_at,
    });
    res.json({
      version: lesson.version,
      saved: lesson.attendance_saved,
      session_status: lesson.status,
      rows: students.map((s) => {
        const a = lesson.attendance.find((a) => same(a.student_id, s._id));
        const l = leaves.find((l) => same(l.requester_id, s._id));
        return {
          student_id: String(s._id),
          user_code: s.user_code,
          name: s.name,
          status: a?.status ?? "NOT_RECORDED",
          approved_leave_id: l ? String(l._id) : null,
          note: l ? "Nghỉ có phép" : null,
        };
      }),
    });
  });
  router.put(
    "/sessions/:id/attendance",
    roles("LECTURER"),
    async (req, res) => {
      const data = parse(
        body({
          version,
          rows: z
            .array(
              body({
                student_id: id,
                status: z.enum(["PRESENT", "ABSENT", "LATE", "EXCUSED"]),
              }),
            )
            .min(1)
            .max(30),
        }),
        req.body,
      );
      const result = await transaction(async (session) => {
        const lesson = await get(ClassSession, req.resourceId, session);
        await authorizeLesson(lesson, req.user, session);
        checkVersion(lesson, data.version);
        if (lesson.status === "CANCELLED" || lesson.start_at > new Date())
          fail(409, "Buổi chưa bắt đầu hoặc đã hủy");
        const students = await rosterIds(lesson, session);
        const ids = new Set(data.rows.map((r) => r.student_id));
        if (
          ids.size !== data.rows.length ||
          ids.size !== students.length ||
          !students.every((s) => ids.has(String(s)))
        )
          fail(400, "Cần đúng và đủ danh sách tại thời điểm buổi học");
        const before = {
          version: lesson.version,
          rows: clean(lesson.attendance),
        };
        const now = new Date();
        lesson.attendance = data.rows.map((r) => ({
          ...r,
          updated_by: req.user._id,
          updated_at: now,
        }));
        lesson.attendance_saved = true;
        await lesson.save({ session });
        await audit(
          session,
          req.user,
          "SAVE_ATTENDANCE",
          "ClassSession",
          lesson._id,
          before,
          { version: lesson.version, rows: clean(lesson.attendance) },
        );
        return { version: lesson.version };
      });
      res.json(result);
    },
  );
  router.get("/department/summary", roles("HEAD"), async (req, res) => {
    const q = parse(body({ semester_id: id.optional() }), req.query);
    const filter = { department_id: req.user.department_id };
    if (q.semester_id) filter.semester_id = q.semester_id;
    const ids = await Section.distinct("_id", filter);
    const lessons = await ClassSession.find({
      section_id: { $in: ids },
      status: { $ne: "CANCELLED" },
    });
    const counts = { PRESENT: 0, ABSENT: 0, LATE: 0, EXCUSED: 0 };
    for (const l of lessons) for (const a of l.attendance) counts[a.status]++;
    res.json({
      department_id: String(req.user.department_id),
      sections: ids.length,
      sessions: lessons.length,
      recorded_sessions: lessons.filter((s) => s.attendance_saved).length,
      attendance: counts,
    });
  });
  return router;
}
