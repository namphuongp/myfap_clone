import { Router } from "express";
import { z } from "zod";
import { ClassSession, Leave, Change, Enrollment } from "./models.js";
import {
  body,
  id,
  text,
  version,
  parse,
  get,
  roles,
  fail,
  clean,
  checkVersion,
  transaction,
  scopedSectionIds,
  audit,
} from "./core.js";
import { day, slotId, slotTimes } from "./slots.js";
import { authorizeLesson, reschedule, ensureSlot } from "./academic.js";
export function requestRoutes() {
  const router = Router();
  router.param("id", (req, res, next, key) => {
    try {
      req.resourceId = parse(id, key);
      next();
    } catch (e) {
      next(e);
    }
  });
  router.post("/leave-requests", roles("STUDENT"), async (req, res) => {
    const data = parse(body({ session_id: id, reason: text }), req.body);
    const result = await transaction(async (session) => {
      const lesson = await get(ClassSession, data.session_id, session);
      await authorizeLesson(lesson, req.user, session);
      if (
        lesson.status !== "SCHEDULED" ||
        lesson.start_at <= new Date() ||
        !lesson.slot_id
      )
        fail(409, "Chỉ xin nghỉ buổi tương lai có slot hợp lệ");
      const [row] = await Leave.create(
        [
          {
            ...data,
            requester_id: req.user._id,
            session_version: lesson.version,
            session_date: lesson.session_date,
            slot_id: lesson.slot_id,
            requested_start: lesson.start_at,
            requested_end: lesson.end_at,
          },
        ],
        { session },
      );
      await audit(
        session,
        req.user,
        "CREATE_LEAVE",
        "Leave",
        row._id,
        null,
        row,
      );
      return clean(row);
    });
    res.status(201).json(result);
  });
  router.post("/change-requests", roles("LECTURER"), async (req, res) => {
    const data = parse(
      body({
        session_id: id,
        reason: text,
        proposed_room_id: id,
        proposed_date: day,
        proposed_slot_id: slotId,
      }),
      req.body,
    );
    const result = await transaction(async (session) => {
      const lesson = await get(ClassSession, data.session_id, session);
      const section = await authorizeLesson(lesson, req.user, session);
      const timing = slotTimes(data.proposed_date, data.proposed_slot_id);
      if (
        lesson.status !== "SCHEDULED" ||
        lesson.start_at <= new Date() ||
        timing.start_at <= new Date() ||
        lesson.attendance_saved
      )
        fail(409, "Chỉ đổi buổi tương lai chưa điểm danh");
      if (
        String(lesson.room_id) === data.proposed_room_id &&
        timing.start_at.getTime() === lesson.start_at.getTime() &&
        timing.end_at.getTime() === lesson.end_at.getTime()
      )
        fail(400, "Lịch đề xuất không thay đổi");
      await ensureSlot(
        session,
        section,
        data.proposed_room_id,
        timing.start_at,
        timing.end_at,
        lesson._id,
      );
      const [row] = await Change.create(
        [
          {
            ...data,
            requester_id: req.user._id,
            session_version: lesson.version,
            proposed_start: timing.start_at,
            proposed_end: timing.end_at,
            original_room_id: lesson.room_id,
            original_date: lesson.session_date,
            original_slot_id: lesson.slot_id,
            original_start: lesson.start_at,
            original_end: lesson.end_at,
          },
        ],
        { session },
      );
      await audit(
        session,
        req.user,
        "CREATE_CHANGE",
        "Change",
        row._id,
        null,
        row,
      );
      return clean(row);
    });
    res.status(201).json(result);
  });
  for (const [path, Model, reviewer, statuses] of [
    [
      "leave-requests",
      Leave,
      "LECTURER",
      ["PENDING", "APPROVED", "REJECTED", "INVALIDATED", "CANCELLED"],
    ],
    [
      "change-requests",
      Change,
      "STAFF",
      ["PENDING", "APPROVED", "REJECTED", "CANCELLED"],
    ],
  ]) {
    router.get(`/${path}`, async (req, res) => {
      if (Model === Change && req.user.role === "STUDENT")
        fail(403, "Không có quyền");
      const q = parse(
        body({
          status: z.enum(statuses).optional(),
          page: z.coerce.number().int().min(1).max(10000).default(1),
        }),
        req.query,
      );
      const filter = {};
      if (q.status) filter.status = q.status;
      if (
        req.user.role === "STUDENT" ||
        (Model === Change && req.user.role === "LECTURER")
      )
        filter.requester_id = req.user._id;
      else if (req.user.role !== "STAFF") {
        const sections = await scopedSectionIds(req.user);
        filter.session_id = {
          $in: await ClassSession.distinct("_id", {
            section_id: { $in: sections },
          }),
        };
      }
      res.json({
        page: q.page,
        items: clean(
          await Model.find(filter)
            .sort({ created_at: -1, _id: -1 })
            .skip((q.page - 1) * 50)
            .limit(50),
        ),
      });
    });
    router.patch(`/${path}/:id/decision`, roles(reviewer), async (req, res) => {
      const data = parse(
        body({
          version,
          decision: z.enum(["APPROVED", "REJECTED"]),
          note: text,
        }),
        req.body,
      );
      const result = await transaction(async (session) => {
        const row = await get(Model, req.resourceId, session);
        const lesson = await get(ClassSession, row.session_id, session);
        if (Model === Leave) await authorizeLesson(lesson, req.user, session);
        checkVersion(row, data.version);
        if (row.status !== "PENDING") fail(409, "Đơn không còn chờ duyệt");
        if (data.decision === "APPROVED") {
          if (lesson.status !== "SCHEDULED" || lesson.start_at <= new Date())
            fail(409, "Buổi học đã bắt đầu hoặc không còn hiệu lực");
          if (Model === Leave) {
            if (
              row.requested_start.getTime() !== lesson.start_at.getTime() ||
              row.requested_end.getTime() !== lesson.end_at.getTime()
            )
              fail(409, "Slot đã đổi, đơn nghỉ không còn hiệu lực");
            if (
              !(await Enrollment.exists({
                section_id: lesson.section_id,
                student_id: row.requester_id,
                status: "ACTIVE",
              }).session(session))
            )
              fail(409, "Sinh viên không còn học lớp này");
          } else {
            checkVersion(lesson, row.session_version);
            if (!row.proposed_slot_id || !row.proposed_date)
              fail(409, "Đơn cũ chưa có slot; cần gửi đơn mới");
            await reschedule(
              session,
              req.user,
              lesson,
              {
                room_id: row.proposed_room_id,
                session_date: row.proposed_date,
                slot_id: row.proposed_slot_id,
              },
              row._id,
            );
          }
        }
        const before = clean(row);
        row.status = data.decision;
        row.reviewer_id = req.user._id;
        row.review_note = data.note;
        row.reviewed_at = new Date();
        await row.save({ session });
        await audit(
          session,
          req.user,
          "REVIEW_REQUEST",
          Model.modelName,
          row._id,
          before,
          row,
        );
        return clean(row);
      });
      res.json(result);
    });
  }
  return router;
}
