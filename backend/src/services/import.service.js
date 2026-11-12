import { fail } from "../utils/api-error.js";
import { hash } from "../utils/crypto.js";
import { newId } from "../utils/identity.js";
import { get } from "../repositories/base.repository.js";
import { transaction } from "../repositories/transaction.js";
import { SLOTS, slotTimes, localDate } from "../utils/slots.js";
import { z } from "zod";
import {
  departmentRepository,
  courseRepository,
  semesterRepository,
  userRepository,
  authSessionRepository,
  roomRepository,
  sectionRepository,
  classMembershipRepository,
  classSessionRepository,
  leaveRepository,
  changeRepository,
  activityLogRepository,
  importBatchRepository,
} from "../repositories/index.js";
const sourceSchema = z.object({
  format: z.literal("myfap-mysql-v1"),
  tables: z.record(z.string(), z.array(z.record(z.string(), z.unknown()))),
});
const date = (value) => new Date(value);
const requireRef = (map, key, label) => {
  const result = map.get(Number(key));
  if (!result) throw new Error(`Snapshot thiếu tham chiếu ${label} ${key}`);
  return result;
};
function matchingSlot(start, end) {
  return (
    SLOTS.find((s) => {
      const t = slotTimes(localDate(start), s.id);
      return (
        t.start_at.getTime() === start.getTime() &&
        t.end_at.getTime() === end.getTime()
      );
    })?.id ?? null
  );
}
export async function importSnapshot(input) {
  const source = sourceSchema.parse(input);
  const sourceHash = hash(JSON.stringify(source));
  const tables = source.tables;
  for (const name of [
    "users",
    "rooms",
    "sections",
    "enrollments",
    "class_sessions",
    "attendance",
    "leave_requests",
    "change_requests",
    "auth_sessions",
    "audit_logs",
  ])
    if (!Array.isArray(tables[name])) throw new Error(`Snapshot thiếu ${name}`);
  return transaction(async (session) => {
    const existing = await importBatchRepository.findOne(
      {
        source_hash: sourceHash,
      },
      { session: session },
    );
    if (existing) return { already_imported: true, counts: existing.counts };
    if (await userRepository.exists({}, { session: session }))
      fail(
        409,
        "Chỉ import vào database chưa có người dùng, không ghi đè dữ liệu",
      );
    const maps = {};
    for (const table of [
      "users",
      "rooms",
      "sections",
      "class_sessions",
      "leave_requests",
      "change_requests",
      "auth_sessions",
    ])
      maps[table] = new Map(
        tables[table].map((row) => [Number(row.id), newId()]),
      );
    const departments = new Map();
    for (const code of new Set([
      ...tables.users.map((u) => u.department),
      ...tables.sections.map((s) => s.department),
    ])) {
      if (typeof code !== "string" || !code.trim())
        throw new Error("Bộ môn cũ không hợp lệ");
      const [row] = await departmentRepository.create([{ code, name: code }], {
        session,
      });
      departments.set(code, row._id);
    }
    const years = tables.class_sessions.flatMap((row) => [
      date(row.start_at).getUTCFullYear(),
      date(row.end_at).getUTCFullYear(),
    ]);
    const now = new Date().getUTCFullYear();
    const [semester] = await semesterRepository.create(
      [
        {
          code: "LEGACY",
          name: "Học kỳ dữ liệu cũ",
          start_at: new Date(Date.UTC(Math.min(now, ...years), 0, 1)),
          end_at: new Date(Date.UTC(Math.max(now, ...years) + 1, 0, 1)),
        },
      ],
      { session },
    );
    const courses = new Map();
    for (const section of tables.sections) {
      const key = JSON.stringify([section.department, section.course]);
      if (!courses.has(key)) {
        const [row] = await courseRepository.create(
          [
            {
              code: `LEGACY-${courses.size + 1}`,
              name: section.course,
              department_id: departments.get(section.department),
            },
          ],
          { session },
        );
        courses.set(key, row._id);
      }
    }
    for (const row of tables.users)
      await userRepository.create(
        [
          {
            _id: maps.users.get(row.id),
            legacy_id: row.id,
            user_code: row.user_code ?? `${row.role}-${row.id}`,
            name: row.name,
            email: row.email,
            password_hash: row.password_hash,
            role: row.role,
            department_id: departments.get(row.department),
            active: !!row.active,
            created_at: row.created_at ? date(row.created_at) : new Date(),
          },
        ],
        { session },
      );
    for (const row of tables.rooms)
      await roomRepository.create(
        [
          {
            _id: maps.rooms.get(row.id),
            legacy_id: row.id,
            name: row.name,
            capacity: row.capacity,
          },
        ],
        { session },
      );
    for (const row of tables.sections) {
      if (tables.enrollments.filter((e) => e.section_id === row.id).length > 30)
        fail(409, `Lớp ${row.id} vượt 30 người; không tự loại sinh viên`);
      const lecturer = tables.users.find((u) => u.id === row.lecturer_id);
      if (
        lecturer?.role !== "LECTURER" ||
        lecturer.department !== row.department
      )
        throw new Error("Phân công giảng viên cũ không hợp lệ");
      await sectionRepository.create(
        [
          {
            _id: maps.sections.get(row.id),
            legacy_id: row.id,
            code: row.code,
            course_id: courses.get(
              JSON.stringify([row.department, row.course]),
            ),
            semester_id: semester._id,
            department_id: departments.get(row.department),
            lecturer_id: requireRef(maps.users, row.lecturer_id, "giảng viên"),
            capacity: 30,
          },
        ],
        { session },
      );
    }
    for (const row of tables.enrollments) {
      const section = await sectionRepository.findById(
        requireRef(maps.sections, row.section_id, "lớp"),
        { session: session },
      );
      const student = tables.users.find((u) => u.id === row.student_id);
      if (student?.role !== "STUDENT")
        throw new Error("Dữ liệu lớp cũ không thuộc sinh viên");
      const enrolled_at = row.enrolled_at ? date(row.enrolled_at) : new Date(0);
      const fields = {
        section_id: section._id,
        student_id: requireRef(maps.users, row.student_id, "sinh viên"),
        course_id: section.course_id,
        semester_id: section.semester_id,
        starts_at: enrolled_at,
      };
      await classMembershipRepository.create([fields], { session });
    }
    for (const row of tables.class_sessions) {
      const section = await sectionRepository.findById(
        requireRef(maps.sections, row.section_id, "lớp"),
        { session: session },
      );
      const start = date(row.start_at),
        end = date(row.end_at);
      const slot = matchingSlot(start, end);
      const attendance = [];
      for (const a of tables.attendance.filter(
        (a) => a.session_id === row.id,
      )) {
        const studentId = requireRef(maps.users, a.student_id, "sinh viên");
        if (
          !(await classMembershipRepository.exists(
            {
              section_id: section._id,
              student_id: studentId,
            },
            { session: session },
          ))
        )
          throw new Error("Điểm danh cũ không có sinh viên thuộc lớp");
        attendance.push({
          student_id: studentId,
          status: a.status,
          updated_by: requireRef(maps.users, a.updated_by, "người điểm danh"),
          updated_at: a.updated_at ? date(a.updated_at) : new Date(),
        });
      }
      await classSessionRepository.create(
        [
          {
            _id: maps.class_sessions.get(row.id),
            legacy_id: row.id,
            section_id: section._id,
            lecturer_id: section.lecturer_id,
            room_id: requireRef(maps.rooms, row.room_id, "phòng"),
            start_at: start,
            end_at: end,
            session_date: localDate(start),
            slot_id: slot,
            legacy_unaligned: !slot,
            status:
              row.status ?? (end <= new Date() ? "COMPLETED" : "SCHEDULED"),
            attendance_saved: !!row.attendance_saved,
            attendance,
            version: row.version ?? 0,
          },
        ],
        { session },
      );
    }
    for (const row of tables.class_sessions) {
      if (
        row.version !== undefined &&
        (!Number.isSafeInteger(row.version) || row.version < 0)
      )
        throw new Error("Version snapshot không hợp lệ");
      if (row.version > 0)
        await classSessionRepository.updateOne(
          { _id: maps.class_sessions.get(row.id) },
          { $set: { version: row.version } },
          { session, runValidators: true },
        );
    }
    for (const row of tables.auth_sessions)
      await authSessionRepository.create(
        [
          {
            _id: maps.auth_sessions.get(row.id),
            user_id: requireRef(maps.users, row.user_id, "tài khoản"),
            token_hash: row.token_hash,
            expires_at: date(row.expires_at),
          },
        ],
        { session },
      );
    const requestData = (row) => ({
      legacy_id: row.id,
      session_id: requireRef(maps.class_sessions, row.session_id, "buổi học"),
      requester_id: requireRef(maps.users, row.requester_id, "người gửi"),
      reason: row.reason,
      status: row.status,
      reviewer_id: row.reviewer_id
        ? requireRef(maps.users, row.reviewer_id, "người duyệt")
        : null,
      review_note: row.review_note ?? null,
      reviewed_at: row.reviewed_at ? date(row.reviewed_at) : null,
      created_at: row.created_at ? date(row.created_at) : new Date(),
      version: row.version ?? 0,
    });
    for (const row of tables.leave_requests) {
      const lesson = await classSessionRepository.findById(
        requireRef(maps.class_sessions, row.session_id, "buổi học"),
        { session: session },
      );
      await leaveRepository.create(
        [
          {
            _id: maps.leave_requests.get(row.id),
            ...requestData(row),
            session_version: lesson.version,
            session_date: lesson.session_date,
            slot_id: lesson.slot_id,
            requested_start: lesson.start_at,
            requested_end: lesson.end_at,
          },
        ],
        { session },
      );
    }
    for (const row of tables.change_requests) {
      const start = date(row.proposed_start),
        end = date(row.proposed_end);
      await changeRepository.create(
        [
          {
            _id: maps.change_requests.get(row.id),
            ...requestData(row),
            session_version: row.session_version,
            proposed_room_id: requireRef(
              maps.rooms,
              row.proposed_room_id,
              "phòng đề xuất",
            ),
            proposed_date: localDate(start),
            proposed_slot_id: matchingSlot(start, end),
            proposed_start: start,
            proposed_end: end,
          },
        ],
        { session },
      );
    }
    for (const [repository, table] of [
      [leaveRepository, "leave_requests"],
      [changeRepository, "change_requests"],
    ]) {
      for (const row of tables[table]) {
        if (
          row.version !== undefined &&
          (!Number.isSafeInteger(row.version) || row.version < 0)
        )
          throw new Error("Version snapshot không hợp lệ");
        if (row.version > 0)
          await repository.updateOne(
            { _id: maps[table].get(row.id) },
            { $set: { version: row.version } },
            { session, runValidators: true },
          );
      }
    }
    const entityMap = {
      users: "User",
      rooms: "Room",
      sections: "Section",
      class_sessions: "ClassSession",
      leave_requests: "Leave",
      change_requests: "Change",
      auth_sessions: "AuthSession",
    };
    for (const row of tables.audit_logs)
      await activityLogRepository.create(
        [
          {
            actor_id: requireRef(maps.users, row.actor_id, "người thao tác"),
            action: row.action,
            entity: entityMap[row.entity] ?? `Legacy:${row.entity}`,
            entity_id: maps[row.entity]?.get(Number(row.entity_id)) ?? newId(),
            before_data: null,
            after_data: { legacy_entity_id: row.entity_id },
            created_at: row.created_at ? date(row.created_at) : new Date(),
          },
        ],
        { session },
      );
    const counts = Object.fromEntries(
      Object.entries(tables).map(([key, rows]) => [key, rows.length]),
    );
    await importBatchRepository.create([{ source_hash: sourceHash, counts }], {
      session,
    });
    return { already_imported: false, counts };
  });
}
