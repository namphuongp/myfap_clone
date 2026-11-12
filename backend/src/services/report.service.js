import {
  sectionRepository,
  courseRepository,
  userRepository,
  semesterRepository,
  classMembershipRepository,
  classSessionRepository,
  leaveRepository,
  changeRepository,
} from "../repositories/index.js";
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
  for (const key of ["semester_id", "course_id"])
    if (q[key]) filter[key] = q[key];
  if (q.section_id) filter._id = q.section_id;
  return sectionRepository.find(filter);
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
  const sections = await sectionsFor(actor, q),
    ids = sections.map((s) => s._id);
  const counts = await classMembershipRepository.activeCounts(ids),
    countMap = new Map(counts.map((c) => [String(c._id), c.count]));
  const rows = await reportRepository.attendanceBySections(ids, {
    lecturerId: q.lecturer_id,
    byLecturer: q.group_by === "LECTURER",
  });
  if (q.group_by === "LECTURER") {
    const people = await userRepository.find(
      { _id: { $in: rows.map((r) => r._id).filter(Boolean) } },
      { select: "name" },
    );
    return {
      department_id: String(actor.department_id),
      group_by: q.group_by,
      items: rows.map((r) => ({
        id: r._id ? String(r._id) : null,
        name: people.find((p) => same(p._id, r._id))?.name ?? "Chưa phân công",
        sections: r.section_ids.length,
        active_enrollments: r.section_ids.reduce(
          (n, id) => n + (countMap.get(String(id)) ?? 0),
          0,
        ),
        ...metrics(r),
      })),
    };
  }
  const courses = await courseRepository.find({
      _id: { $in: sections.map((s) => s.course_id) },
    }),
    summaryMap = new Map(rows.map((r) => [String(r._id), r]));
  const details = sections
    .filter((s) => !q.lecturer_id || summaryMap.has(String(s._id)))
    .map((s) => ({
      section_id: String(s._id),
      section_code: s.code,
      course_id: String(s.course_id),
      course: courses.find((c) => same(c._id, s.course_id))?.name,
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
    const g = grouped.get(row.course_id) ?? {
      id: row.course_id,
      name: row.course,
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
    g.sections++;
    for (const key of [
      "active_enrollments",
      "sessions",
      "cancelled_sessions",
      "completed_sessions",
      "recorded_sessions",
    ])
      g[key] += row[key];
    for (const key of ["present", "late", "absent", "excused"])
      g[key] += row.attendance[key.toUpperCase()];
    grouped.set(row.course_id, g);
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
  const sections = await sectionsFor(actor, q),
    rows = await reportRepository.attendanceBySections(
      sections.map((s) => s._id),
    );
  const sum = {};
  for (const row of rows)
    for (const key of [
      "sessions",
      "cancelled_sessions",
      "completed_sessions",
      "recorded_sessions",
      "present",
      "late",
      "absent",
      "excused",
    ])
      sum[key] = (sum[key] ?? 0) + row[key];
  return {
    department_id: String(actor.department_id),
    sections: sections.length,
    ...metrics(sum),
  };
}

export async function requestReport(actor, q) {
  const sections = await sectionsFor(actor, q);
  const sessions = await classSessionRepository.distinct("_id", {
    section_id: { $in: sections.map((s) => s._id) },
  });
  const counts = (repo) =>
    repo
      .aggregate([
        { $match: { session_id: { $in: sessions } } },
        { $group: { _id: "$status", count: { $sum: 1 } } },
      ])
      .then((rows) => rows.map((r) => ({ status: r._id, count: r.count })));
  return {
    department_id: String(actor.department_id),
    leave_requests: await counts(leaveRepository),
    change_requests: await counts(changeRepository),
  };
}
