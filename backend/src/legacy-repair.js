import { User, ClassSession, Section, Leave, Change } from "./models.js";
import { transaction, clean, get, fail, audit } from "./core.js";
import { ensureSlot, recordSession } from "./academic.js";
import { SLOTS, slotTimes, localDate } from "./slots.js";
class Preview extends Error {
  constructor(plan) {
    super("Preview");
    this.plan = plan;
  }
}
export async function normalizeLegacySessions({ apply = false } = {}) {
  try {
    return await transaction(async (session) => {
      const actor = await User.findOne({ role: "STAFF", active: true })
        .sort({ _id: 1 })
        .session(session);
      if (!actor) fail(409, "Cần tài khoản STAFF hoạt động");
      const now = new Date();
      const lessons = await ClassSession.find({
        $or: [
          { slot_id: null },
          { status: "SCHEDULED", end_at: { $lte: now } },
        ],
      })
        .sort({ start_at: 1, _id: 1 })
        .session(session);
      const plan = [];
      for (const row of lessons) {
        const before = clean(row);
        let timing = null;
        if (!row.slot_id) {
          const date = localDate(row.start_at);
          const local = new Date(row.start_at.getTime() + 7 * 3600000);
          const minute = local.getUTCHours() * 60 + local.getUTCMinutes();
          const section = await get(Section, row.section_id, session);
          const slots = [...SLOTS].sort(
            (a, b) =>
              Math.abs(a.start_minute - minute) -
                Math.abs(b.start_minute - minute) || a.id - b.id,
          );
          for (const slot of slots) {
            const candidate = slotTimes(date, slot.id);
            try {
              if (row.status !== "CANCELLED")
                await ensureSlot(
                  session,
                  section,
                  row.room_id,
                  candidate.start_at,
                  candidate.end_at,
                  row._id,
                );
              timing = candidate;
              break;
            } catch (error) {
              if (error.status !== 409) throw error;
            }
          }
          if (!timing)
            fail(
              409,
              `Buổi ${row._id} không có slot trống cùng ngày; không thay đổi dữ liệu`,
            );
        }
        const changed =
          timing &&
          (timing.start_at.getTime() !== row.start_at.getTime() ||
            timing.end_at.getTime() !== row.end_at.getTime());
        if (timing) Object.assign(row, { ...timing, legacy_unaligned: false });
        if (row.status !== "CANCELLED" && row.end_at <= now)
          row.status = "COMPLETED";
        await row.save({ session });
        if (changed) {
          const leaves = await Leave.find({
            session_id: row._id,
            status: { $in: ["PENDING", "APPROVED"] },
          }).session(session);
          for (const leave of leaves) {
            const old = clean(leave);
            leave.status = "INVALIDATED";
            await leave.save({ session });
            await audit(
              session,
              actor,
              "INVALIDATE_LEAVE_SLOT_REPAIR",
              "Leave",
              leave._id,
              old,
              leave,
            );
          }
        }
        const changes = await Change.find({
          session_id: row._id,
          status: "PENDING",
        }).session(session);
        for (const change of changes) {
          const old = clean(change);
          change.status = "CANCELLED";
          change.review_note = "Lịch gốc đã được chuẩn hóa theo slot";
          await change.save({ session });
          await audit(
            session,
            actor,
            "CANCEL_CHANGE_SLOT_REPAIR",
            "Change",
            change._id,
            old,
            change,
          );
        }
        await recordSession(
          session,
          actor,
          "NORMALIZE_LEGACY_SLOT",
          before,
          row,
        );
        plan.push({
          id: String(row._id),
          old_start: before.start_at,
          old_end: before.end_at,
          new_start: row.start_at,
          new_end: row.end_at,
          session_date: row.session_date,
          slot_id: row.slot_id,
          status: row.status,
          version: row.version,
        });
      }
      if (!apply) throw new Preview(plan);
      return plan;
    });
  } catch (error) {
    if (error instanceof Preview) return error.plan;
    throw error;
  }
}
