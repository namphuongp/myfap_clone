import {
  sectionRepository,
  classSessionRepository,
  courseRepository,
  userRepository,
  semesterRepository,
  enrollmentRepository,
  leaveRepository,
  changeRepository,
} from "../repositories/index.js";
import { majorTransferRepository } from "../repositories/student-affairs.repositories.js";
import { reportRepository } from "../repositories/report.repository.js";
import { get } from "../repositories/base.repository.js";
import { same } from "../utils/identity.js";
import { fail } from "../utils/api-error.js";
async function sectionsFor(actor, q) {
  if (q.semester_id) await get(semesterRepository, q.semester_id);
  for (const [key, repo] of [
    ["course_id", courseRepository],
    ["lecturer_id", userRepository],
    ["section_id", sectionRepository],
  ])
    if (q[key]) {
      const row = await get(repo, q[key]);
      if (!same(row.department_id, actor.department_id))
        fail(403, "Bộ lọc ngoài bộ môn");
      if (key === "lecturer_id" && row.role !== "LECTURER")
        fail(400, "Bộ lọc không phải giảng viên");
    }
  const filter = { department_id: actor.department_id };
  for (const key of ["semester_id", "course_id", "lecturer_id"])
    if (q[key]) filter[key] = q[key];
  if (q.section_id) filter._id = q.section_id;
  return sectionRepository.find(filter, { sort: { _id: 1 } });
}
const metrics = (row) => {
  const present = row?.present ?? 0,
    late = row?.late ?? 0,
    absent = row?.absent ?? 0,
    excused = row?.excused ?? 0;
  const total = present + late + absent + excused;
  return {
    sessions: row?.sessions ?? 0,
    cancelled_sessions: row?.cancelled_sessions ?? 0,
    completed_sessions: row?.completed_sessions ?? 0,
    recorded_sessions: row?.recorded_sessions ?? 0,
    attendance: {
      PRESENT: present,
      LATE: late,
      ABSENT: absent,
      EXCUSED: excused,
    },
    recorded_entries: total,
    presence_rate: total
      ? Math.round(((present + late) * 10000) / total) / 100
      : null,
  };
};
export async function attendanceReport(actor, q) {
  const sections = await sectionsFor(actor, q);
  const ids = sections.map((s) => s._id);
  const summaries = await reportRepository.attendanceBySections(ids);
  const counts = await enrollmentRepository.activeCounts(ids);
  const summaryMap = new Map(summaries.map((s) => [String(s._id), s])),
    countMap = new Map(counts.map((s) => [String(s._id), s.count]));
  const courses = await courseRepository.find({
      _id: { $in: sections.map((s) => s.course_id) },
    }),
    lecturers = await userRepository.find({
      _id: { $in: sections.map((s) => s.lecturer_id) },
    });
  const courseMap = new Map(courses.map((c) => [String(c._id), c])),
    lecturerMap = new Map(lecturers.map((u) => [String(u._id), u]));
  const details = sections.map((s) => ({
    section_id: String(s._id),
    section_code: s.code,
    course_id: String(s.course_id),
    course: courseMap.get(String(s.course_id))?.name,
    lecturer_id: String(s.lecturer_id),
    lecturer: lecturerMap.get(String(s.lecturer_id))?.name,
    active_enrollments: countMap.get(String(s._id)) ?? 0,
    ...metrics(summaryMap.get(String(s._id))),
  }));
  if (q.group_by === "SECTION")
    return {
      department_id: String(actor.department_id),
      group_by: q.group_by,
      items: details,
    };
  const grouped = new Map();
  for (const row of details) {
    const key = q.group_by === "COURSE" ? row.course_id : row.lecturer_id;
    let group = grouped.get(key);
    if (!group) {
      group = {
        id: key,
        name: q.group_by === "COURSE" ? row.course : row.lecturer,
        sections: 0,
        active_enrollments: 0,
        sessions: 0,
        cancelled_sessions: 0,
        completed_sessions: 0,
        recorded_sessions: 0,
        present: 0,
        late: 0,
        absent: 0,
        excused: 0,
      };
      grouped.set(key, group);
    }
    group.sections++;
    for (const field of [
      "active_enrollments",
      "sessions",
      "cancelled_sessions",
      "completed_sessions",
      "recorded_sessions",
    ])
      group[field] += row[field];
    for (const [key, status] of [
      ["present", "PRESENT"],
      ["late", "LATE"],
      ["absent", "ABSENT"],
      ["excused", "EXCUSED"],
    ])
      group[key] += row.attendance[status];
  }
  return {
    department_id: String(actor.department_id),
    group_by: q.group_by,
    items: [...grouped.values()].map((g) => ({
      id: g.id,
      name: g.name,
      sections: g.sections,
      active_enrollments: g.active_enrollments,
      ...metrics(g),
    })),
  };
}
export async function departmentSummary(actor, q) {
  const sections = await sectionsFor(actor, q);
  const rows = await reportRepository.attendanceBySections(
    sections.map((s) => s._id),
  );
  const total = {
    sessions: 0,
    cancelled_sessions: 0,
    completed_sessions: 0,
    recorded_sessions: 0,
    present: 0,
    late: 0,
    absent: 0,
    excused: 0,
  };
  for (const row of rows)
    for (const key of Object.keys(total)) total[key] += row[key] ?? 0;
  return {
    department_id: String(actor.department_id),
    sections: sections.length,
    ...metrics(total),
  };
}
export async function requestReport(actor, q) {
  const sections = await sectionsFor(actor, q);
  const ids = await classSessionRepository.distinct("_id", {
    section_id: { $in: sections.map((s) => s._id) },
  });
  const counts = async (repo, filter) =>
    repo
      .aggregate([
        { $match: filter },
        { $group: { _id: "$status", count: { $sum: 1 } } },
      ])
      .then((rows) => rows.map(({ _id, count }) => ({ status: _id, count })));
  const filter = { from_department_id: actor.department_id };
  if (q.semester_id)
    filter.effective_semester_id = (
      await get(semesterRepository, q.semester_id)
    )._id;
  return {
    department_id: String(actor.department_id),
    leave_requests: await counts(leaveRepository, { session_id: { $in: ids } }),
    change_requests: await counts(changeRepository, {
      session_id: { $in: ids },
    }),
    major_transfers: await counts(majorTransferRepository, filter),
  };
}
