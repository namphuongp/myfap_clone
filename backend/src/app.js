import express from "express";
import helmet from "helmet";
import cors from "cors";
import { rateLimit } from "express-rate-limit";
import bcrypt from "bcryptjs";
import { z } from "zod";
import { db } from "./db.js";
import {
  ApiError,
  fail,
  id,
  version,
  text,
  date,
  body,
  parse,
  hash,
  token,
  roles,
  get,
  checkVersion,
  authenticate,
  audit,
  academicTransaction,
  sectionScope,
  authorizeSection,
} from "./core.js";
import { ensureSlot } from "./scheduling.js";

export function createApp() {
  const app = express();
  app.disable("x-powered-by");
  app.use(helmet());
  const origins = (process.env.CORS_ORIGINS ?? "").split(",").filter(Boolean);
  app.use(
    cors({
      origin: (origin, cb) => cb(null, !origin || origins.includes(origin)),
    }),
  );
  app.use(express.json({ limit: "64kb" }));
  app.use(
    "/api",
    rateLimit({
      windowMs: 60000,
      limit: 300,
      standardHeaders: "draft-8",
      legacyHeaders: false,
    }),
  );
  app.get("/api/health", async (req, res) => {
    await db.raw("SELECT 1");
    res.json({ status: "ok" });
  });
  app.post(
    "/api/auth/login",
    rateLimit({ windowMs: 900000, limit: 20, legacyHeaders: false }),
    async (req, res) => {
      const data = parse(
        body({
          email: z
            .email()
            .max(254)
            .transform((v) => v.toLowerCase()),
          password: z.string().min(1).max(128),
        }),
        req.body,
      );
      const user = await db("users").where({ email: data.email }).first();
      const valid = await bcrypt.compare(
        data.password,
        user?.password_hash ??
          "$2b$12$YgJE9YWOVcrTGLlX7ybzXu5xFxIx7Kf1T7QmZvJ6VCCbZz04HfA3O",
      );
      if (!user?.active || !valid) fail(401, "Email hoặc mật khẩu không đúng");
      const accessToken = token();
      const hours = Number(process.env.SESSION_HOURS ?? 8);
      const expiresAt = new Date(
        Date.now() +
          (Number.isFinite(hours) && hours > 0 ? hours : 8) * 3600000,
      );
      await db("auth_sessions").insert({
        user_id: user.id,
        token_hash: hash(accessToken),
        expires_at: expiresAt,
      });
      delete user.password_hash;
      res.json({ accessToken, expiresAt, user });
    },
  );
  app.use("/api", authenticate);
  app.post("/api/auth/logout", async (req, res) => {
    await db("auth_sessions").where({ id: req.auth.id }).del();
    res.status(204).end();
  });
  app.get("/api/auth/me", (req, res) => res.json(req.user));
  app.param("id", (req, res, next, value) => {
    try {
      req.resourceId = parse(id, value);
      next();
    } catch (error) {
      next(error);
    }
  });
  app.get("/api/rooms", async (req, res) =>
    res.json(await db("rooms").orderBy("name").limit(200)),
  );
  app.post("/api/users", roles("STAFF"), async (req, res) => {
    const data = parse(
      body({
        name: z.string().trim().min(1).max(120),
        email: z
          .email()
          .max(254)
          .transform((v) => v.toLowerCase()),
        password: z
          .string()
          .min(12)
          .refine(
            (v) => Buffer.byteLength(v, "utf8") <= 72,
            "Mật khẩu tối đa 72 byte",
          ),
        role: z.enum(["STUDENT", "LECTURER", "HEAD", "STAFF"]),
        department: z.string().trim().min(1).max(60),
      }),
      req.body,
    );
    const { password, ...fields } = data;
    const password_hash = await bcrypt.hash(password, 12);
    const result = await academicTransaction(async (trx) => {
      const [key] = await trx("users").insert({ ...fields, password_hash });
      await audit(trx, req.user, "CREATE_USER", "users", key);
      return { id: key, ...fields };
    });
    res.status(201).json(result);
  });
  app.post("/api/rooms", roles("STAFF"), async (req, res) => {
    const data = parse(
      body({
        name: z.string().trim().min(1).max(60),
        capacity: z.number().int().min(1).max(500),
      }),
      req.body,
    );
    const result = await academicTransaction(async (trx) => {
      const [key] = await trx("rooms").insert(data);
      await audit(trx, req.user, "CREATE_ROOM", "rooms", key);
      return { id: key, ...data };
    });
    res.status(201).json(result);
  });
  app.post("/api/sections", roles("STAFF"), async (req, res) => {
    const data = parse(
      body({
        code: z.string().trim().min(1).max(80),
        course: z.string().trim().min(1).max(120),
        department: z.string().trim().min(1).max(60),
        lecturer_id: id,
      }),
      req.body,
    );
    const result = await academicTransaction(async (trx) => {
      const lecturer = await get("users", data.lecturer_id, trx);
      if (
        lecturer.role !== "LECTURER" ||
        !lecturer.active ||
        lecturer.department !== data.department
      )
        fail(400, "Giảng viên phải hoạt động và thuộc bộ môn");
      const [key] = await trx("sections").insert(data);
      await audit(trx, req.user, "CREATE_SECTION", "sections", key);
      return { id: key, ...data };
    });
    res.status(201).json(result);
  });
  app.post(
    "/api/sections/:id/enrollments",
    roles("STAFF"),
    async (req, res) => {
      const data = parse(body({ student_id: id }), req.body);
      await academicTransaction(async (trx) => {
        await get("sections", req.resourceId, trx);
        const student = await get("users", data.student_id, trx);
        if (student.role !== "STUDENT" || !student.active)
          fail(400, "Sinh viên không hợp lệ");
        if (
          await trx("class_sessions")
            .where({ section_id: req.resourceId })
            .first()
        )
          fail(
            409,
            "MVP chỉ thêm sinh viên trước khi xếp lịch để giữ tính toàn vẹn lịch và điểm danh",
          );
        await trx("enrollments").insert({
          section_id: req.resourceId,
          ...data,
        });
        await audit(
          trx,
          req.user,
          "ENROLL_STUDENT",
          "sections",
          req.resourceId,
        );
      });
      res.status(201).json({ section_id: req.resourceId, ...data });
    },
  );
  app.get("/api/sections", async (req, res) =>
    res.json(
      await sectionScope(db("sections as s"), req.user)
        .select("s.*")
        .orderBy("s.id")
        .limit(200),
    ),
  );
  app.get("/api/schedule", async (req, res) => {
    const q = parse(body({ from: date, to: date }), req.query);
    if (q.to <= q.from || q.to - q.from > 93 * 86400000)
      fail(400, "Khoảng xem lịch tối đa 93 ngày");
    const query = db("class_sessions as cs")
      .join("sections as s", "s.id", "cs.section_id")
      .join("rooms as r", "r.id", "cs.room_id")
      .where("cs.start_at", "<", q.to)
      .where("cs.end_at", ">", q.from);
    sectionScope(query, req.user);
    res.json(
      await query
        .select(
          "cs.*",
          "s.code as section_code",
          "s.course",
          "s.lecturer_id",
          "r.name as room_name",
        )
        .orderBy("cs.start_at")
        .limit(1000),
    );
  });
  app.get("/api/sessions/:id/attendance", async (req, res) => {
    const lesson = await get("class_sessions", req.resourceId);
    const section = await get("sections", lesson.section_id);
    await authorizeSection(section, req.user);
    const query = db("enrollments as e")
      .join("users as u", "u.id", "e.student_id")
      .leftJoin("attendance as a", function () {
        this.on("a.student_id", "=", "e.student_id").andOnVal(
          "a.session_id",
          "=",
          lesson.id,
        );
      })
      .leftJoin("leave_requests as lr", function () {
        this.on("lr.requester_id", "=", "e.student_id")
          .andOnVal("lr.session_id", "=", lesson.id)
          .andOnVal("lr.status", "=", "APPROVED");
      })
      .where("e.section_id", section.id);
    if (req.user.role === "STUDENT") query.where("u.id", req.user.id);
    const rows = await query
      .select(
        "u.id as student_id",
        "u.name",
        "u.email",
        "a.status",
        "lr.id as approved_leave_id",
      )
      .orderBy("u.id");
    res.json({
      version: lesson.version,
      saved: !!lesson.attendance_saved,
      rows: rows.map((row) => ({
        ...row,
        status: row.status ?? "NOT_RECORDED",
        note: row.approved_leave_id ? "Nghỉ có phép" : null,
      })),
    });
  });
  app.put(
    "/api/sessions/:id/attendance",
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
            .max(500),
        }),
        req.body,
      );
      const result = await academicTransaction(async (trx) => {
        const lesson = await get("class_sessions", req.resourceId, trx);
        const section = await get("sections", lesson.section_id, trx);
        await authorizeSection(section, req.user, trx);
        checkVersion(lesson, data.version);
        if (lesson.start_at > new Date()) fail(409, "Buổi học chưa bắt đầu");
        const students = await trx("enrollments")
          .where({ section_id: section.id })
          .pluck("student_id");
        const ids = new Set(data.rows.map((r) => r.student_id));
        if (
          ids.size !== data.rows.length ||
          ids.size !== students.length ||
          !students.every((s) => ids.has(s))
        )
          fail(400, "Cần đúng và đủ danh sách sinh viên");
        await trx("attendance").where({ session_id: lesson.id }).del();
        await trx("attendance").insert(
          data.rows.map((r) => ({
            ...r,
            session_id: lesson.id,
            updated_by: req.user.id,
          })),
        );
        await trx("class_sessions")
          .where({ id: lesson.id })
          .update({ attendance_saved: true, version: lesson.version + 1 });
        await audit(
          trx,
          req.user,
          "SAVE_ATTENDANCE",
          "class_sessions",
          lesson.id,
        );
        return { version: lesson.version + 1 };
      });
      res.json(result);
    },
  );
  app.post("/api/sessions", roles("STAFF"), async (req, res) => {
    const data = parse(
      body({ section_id: id, room_id: id, start_at: date, end_at: date }),
      req.body,
    );
    const result = await academicTransaction(async (trx) => {
      if (data.start_at <= new Date()) fail(400, "Chỉ tạo buổi học tương lai");
      const section = await get("sections", data.section_id, trx);
      await ensureSlot(trx, section, data.room_id, data.start_at, data.end_at);
      const [key] = await trx("class_sessions").insert(data);
      await audit(trx, req.user, "CREATE_SESSION", "class_sessions", key);
      return get("class_sessions", key, trx);
    });
    res.status(201).json(result);
  });
  app.post("/api/leave-requests", roles("STUDENT"), async (req, res) => {
    const data = parse(body({ session_id: id, reason: text }), req.body);
    const result = await academicTransaction(async (trx) => {
      const lesson = await get("class_sessions", data.session_id, trx);
      const section = await get("sections", lesson.section_id, trx);
      await authorizeSection(section, req.user, trx);
      if (lesson.start_at <= new Date())
        fail(409, "Phải gửi đơn trước buổi học");
      const [key] = await trx("leave_requests").insert({
        ...data,
        requester_id: req.user.id,
      });
      await audit(trx, req.user, "CREATE_LEAVE", "leave_requests", key);
      return get("leave_requests", key, trx);
    });
    res.status(201).json(result);
  });
  app.post("/api/change-requests", roles("LECTURER"), async (req, res) => {
    const data = parse(
      body({
        session_id: id,
        reason: text,
        proposed_room_id: id,
        proposed_start: date,
        proposed_end: date,
      }),
      req.body,
    );
    const result = await academicTransaction(async (trx) => {
      const lesson = await get("class_sessions", data.session_id, trx);
      const section = await get("sections", lesson.section_id, trx);
      await authorizeSection(section, req.user, trx);
      if (lesson.start_at <= new Date() || data.proposed_start <= new Date())
        fail(409, "Chỉ đổi buổi học tương lai");
      await ensureSlot(
        trx,
        section,
        data.proposed_room_id,
        data.proposed_start,
        data.proposed_end,
        lesson.id,
      );
      const [key] = await trx("change_requests").insert({
        ...data,
        requester_id: req.user.id,
        session_version: lesson.version,
      });
      await audit(trx, req.user, "CREATE_CHANGE", "change_requests", key);
      return get("change_requests", key, trx);
    });
    res.status(201).json(result);
  });
  for (const [path, table, reviewer] of [
    ["leave-requests", "leave_requests", "LECTURER"],
    ["change-requests", "change_requests", "STAFF"],
  ]) {
    app.get(`/api/${path}`, async (req, res) => {
      if (table === "change_requests" && req.user.role === "STUDENT")
        fail(403, "Không có quyền");
      const q = parse(
        body({
          status: z.enum(["PENDING", "APPROVED", "REJECTED"]).optional(),
          page: z.coerce.number().int().min(1).max(10000).default(1),
        }),
        req.query,
      );
      const query = db(`${table} as r`)
        .join("class_sessions as cs", "cs.id", "r.session_id")
        .join("sections as s", "s.id", "cs.section_id")
        .join("users as u", "u.id", "r.requester_id");
      sectionScope(query, req.user);
      if (
        req.user.role === "STUDENT" ||
        (table === "change_requests" && req.user.role === "LECTURER")
      )
        query.where("r.requester_id", req.user.id);
      if (q.status) query.where("r.status", q.status);
      res.json({
        page: q.page,
        items: await query
          .select("r.*", "u.name as requester_name", "s.code as section_code")
          .orderBy("r.id", "desc")
          .offset((q.page - 1) * 50)
          .limit(50),
      });
    });
    app.patch(
      `/api/${path}/:id/decision`,
      roles(reviewer),
      async (req, res) => {
        const data = parse(
          body({
            version,
            decision: z.enum(["APPROVED", "REJECTED"]),
            note: text,
          }),
          req.body,
        );
        const result = await academicTransaction(async (trx) => {
          const row = await get(table, req.resourceId, trx);
          const lesson = await get("class_sessions", row.session_id, trx);
          const section = await get("sections", lesson.section_id, trx);
          if (table === "leave_requests")
            await authorizeSection(section, req.user, trx);
          checkVersion(row, data.version);
          if (row.status !== "PENDING") fail(409, "Đơn đã được xử lý");
          if (data.decision === "APPROVED") {
            if (lesson.start_at <= new Date()) fail(409, "Buổi học đã bắt đầu");
            if (table === "change_requests") {
              checkVersion(lesson, row.session_version);
              if (row.proposed_start <= new Date() || lesson.attendance_saved)
                fail(409, "Không thể đổi buổi học này");
              await ensureSlot(
                trx,
                section,
                row.proposed_room_id,
                row.proposed_start,
                row.proposed_end,
                lesson.id,
              );
              await trx("class_sessions")
                .where({ id: lesson.id })
                .update({
                  room_id: row.proposed_room_id,
                  start_at: row.proposed_start,
                  end_at: row.proposed_end,
                  version: lesson.version + 1,
                });
            }
          }
          await trx(table)
            .where({ id: row.id })
            .update({
              status: data.decision,
              reviewer_id: req.user.id,
              review_note: data.note,
              reviewed_at: new Date(),
              version: row.version + 1,
            });
          await audit(trx, req.user, "REVIEW_REQUEST", table, row.id);
          return get(table, row.id, trx);
        });
        res.json(result);
      },
    );
  }
  app.get("/api/department/summary", roles("HEAD"), async (req, res) => {
    const sections = await db("sections")
      .where({ department: req.user.department })
      .pluck("id");
    const sessions = await db("class_sessions").whereIn("section_id", sections);
    const counts = await db("attendance as a")
      .join("class_sessions as cs", "cs.id", "a.session_id")
      .whereIn("cs.section_id", sections)
      .groupBy("a.status")
      .select("a.status")
      .count("* as count");
    res.json({
      department: req.user.department,
      sections: sections.length,
      sessions: sessions.length,
      recorded_sessions: sessions.filter((s) => s.attendance_saved).length,
      attendance: counts,
    });
  });
  app.use((req, res) => res.status(404).json({ message: "API không tồn tại" }));
  app.use((error, req, res, next) => {
    if (error instanceof z.ZodError)
      return res
        .status(400)
        .json({ message: "Dữ liệu không hợp lệ", issues: error.issues });
    if (error.code === "ER_DUP_ENTRY")
      return res
        .status(409)
        .json({ message: "Đã tồn tại đơn hoặc dữ liệu này" });
    if (error instanceof ApiError)
      return res.status(error.status).json({ message: error.message });
    if (
      error.type === "entity.parse.failed" ||
      error.type === "entity.too.large"
    )
      return res
        .status(error.status)
        .json({ message: "JSON không hợp lệ hoặc quá lớn" });
    console.error(error.code ?? error.name);
    res.status(500).json({ message: "Lỗi máy chủ" });
  });
  return app;
}
