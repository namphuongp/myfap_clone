import {
  semesterRepository,
  sectionRepository,
  classMembershipRepository,
  classSessionRepository,
  userRepository,
} from "../repositories/index.js";
import { get, saveDocument } from "../repositories/base.repository.js";
import { transaction } from "../repositories/transaction.js";
import { currentTerm, semesterData } from "../utils/academic-calendar.js";
import { audit } from "./audit.service.js";
import { clean } from "../utils/serialize.js";
import { same } from "../utils/identity.js";
import { fail } from "../utils/api-error.js";
class Preview extends Error {
  constructor(plan) {
    super("Preview");
    this.plan = plan;
  }
}
export async function bootstrapAcademicCalendar({ apply = false } = {}) {
  try {
    return await transaction(async (session) => {
      const actor = await userRepository.findOne(
        { role: "STAFF", active: true },
        { session },
      );
      if (!actor) fail(409, "Cần tài khoản STAFF");
      const year = new Date().getUTCFullYear();
      const years = new Set([year - 1, year, year + 1]);
      const all = await classSessionRepository.find({}, { session });
      for (const s of all)
        years.add(
          new Date(s.start_at.getTime() + 7 * 3600000).getUTCFullYear(),
        );
      const semesterMap = new Map();
      for (const y of years)
        for (const term of ["SPRING", "SUMMER", "FALL"]) {
          const fields = semesterData(term, y);
          let row = await semesterRepository.findOne(
            { code: fields.code },
            { session },
          );
          if (!row) row = await semesterRepository.create(fields, { session });
          if (
            row.start_at.getTime() !== fields.start_at.getTime() ||
            row.end_at.getTime() !== fields.end_at.getTime()
          )
            fail(409, `Học kỳ ${fields.code} có lịch không khớp; cần kiểm tra`);
          semesterMap.set(fields.code, row);
        }
      const sections = await sectionRepository.find({}, { session });
      const plan = [];
      for (const section of sections) {
        const old = await get(semesterRepository, section.semester_id, session);
        if (old.term && !old.legacy) continue;
        const sessions = all.filter(
          (s) => same(s.section_id, section._id) && s.status !== "CANCELLED",
        );
        if (!sessions.length) continue;
        const terms = sessions.map((s) => currentTerm(s.start_at));
        if (terms.some((t) => !t))
          fail(
            409,
            `Lớp ${section.code} có buổi nằm trong tháng nghỉ; cần chỉnh lịch trước`,
          );
        const codes = [...new Set(terms.map((t) => t.code))];
        if (codes.length !== 1)
          fail(
            409,
            `Lớp ${section.code} có buổi ở nhiều kỳ; cần tách lớp trước`,
          );
        const target = semesterMap.get(codes[0]);
        const before = clean(section);
        section.semester_id = target._id;
        await saveDocument(section, { session });
        const enrollments = await classMembershipRepository.find(
          { section_id: section._id },
          { session },
        );
        for (const e of enrollments) {
          e.semester_id = target._id;
          await saveDocument(e, { session });
        }
        await audit(
          session,
          actor,
          "NORMALIZE_SECTION_SEMESTER",
          "Section",
          section._id,
          before,
          section,
        );
        plan.push({
          section_id: String(section._id),
          code: section.code,
          old_semester_id: String(old._id),
          semester: target.code,
        });
      }
      const legacy = await semesterRepository.find({ term: null }, { session });
      for (const row of legacy) {
        row.legacy = true;
        await saveDocument(row, { session });
      }
      if (!apply) throw new Preview(plan);
      return plan;
    });
  } catch (error) {
    if (error instanceof Preview) return error.plan;
    throw error;
  }
}
