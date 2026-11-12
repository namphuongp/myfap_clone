import mongoose from "mongoose";
import { createHash } from "node:crypto";
import { ClassMembership, ActivityLog, ImportBatch } from "../models/index.js";
import { transaction } from "./transaction.js";

export const legacyCollections = [
  "enrollments",
  "enrollmentperiods",
  "audits",
  "sessionhistories",
  "noticereads",
];
const marker = "schema-v3-17-collections";
const digest = (value) =>
  createHash("sha256").update(JSON.stringify(value)).digest("hex");
async function sourceRows(name, session) {
  const db = mongoose.connection.db;
  if (!(await db.listCollections({ name }, { nameOnly: true }).hasNext()))
    return [];
  return db.collection(name).find({}, { session }).sort({ _id: 1 }).toArray();
}
export async function assertCollectionsMigrated() {
  const db = mongoose.connection.db;
  const names = new Set(
    (await db.listCollections({}, { nameOnly: true }).toArray()).map(
      (c) => c.name,
    ),
  );
  for (const name of legacyCollections)
    if (
      names.has(name) &&
      (await db.collection(name).findOne({}, { projection: { _id: 1 } }))
    )
      throw new Error(
        "Cần dừng backend và chạy npm run db:migrate trước khi sử dụng schema mới",
      );
}
export async function migrateCollections({ apply = false } = {}) {
  const db = mongoose.connection.db;
  const sources = {};
  for (const name of legacyCollections) sources[name] = await sourceRows(name);
  const summary = Object.fromEntries(
    Object.entries(sources).map(([name, rows]) => [name, rows.length]),
  );
  if (!apply) return { apply: false, sources: summary };
  const previous = await ImportBatch.findOne({ source_hash: marker }).lean();
  const hashes = Object.fromEntries(
    Object.entries(sources).map(([name, rows]) => [name, digest(rows)]),
  );
  if (
    previous &&
    !(await db
      .listCollections({ name: { $in: legacyCollections } }, { nameOnly: true })
      .hasNext())
  ) {
    return {
      apply: true,
      already_migrated: true,
      collections: (
        await db.listCollections({}, { nameOnly: true }).toArray()
      ).map((c) => c.name),
    };
  }
  if (previous) {
    for (const name of legacyCollections)
      if (sources[name].length && previous.counts.hashes[name] !== hashes[name])
        throw new Error("Nguồn cũ đã thay đổi sau migration: " + name);
  } else
    await transaction(async (session) => {
      // Đọc lại trong transaction để phát hiện nguồn thay đổi trong lúc chuẩn bị.
      for (const name of legacyCollections)
        if (digest(await sourceRows(name, session)) !== hashes[name])
          throw new Error("Dữ liệu nguồn đang thay đổi; cần dừng backend");
      const sections = new Map(
        (await db.collection("sections").find({}, { session }).toArray()).map(
          (s) => [String(s._id), s],
        ),
      );
      const key = (row) =>
        String(row.section_id) + ":" + String(row.student_id);
      const enrollments = new Map(sources.enrollments.map((e) => [key(e), e]));
      const periods = new Map();
      for (const p of sources.enrollmentperiods) {
        const k = key(p);
        if (!periods.has(k)) periods.set(k, []);
        periods.get(k).push(p);
      }
      const membershipRows = [];
      for (const k of new Set([...enrollments.keys(), ...periods.keys()])) {
        const enrollment = enrollments.get(k),
          rows = periods.get(k) ?? [];
        if (!rows.length)
          rows.push({
            _id: enrollment._id,
            section_id: enrollment.section_id,
            student_id: enrollment.student_id,
            starts_at: enrollment.enrolled_at,
            ends_at:
              enrollment.status === "WITHDRAWN"
                ? enrollment.withdrawn_at
                : null,
          });
        rows.sort((a, b) => a.starts_at - b.starts_at);
        for (let i = 0; i < rows.length; i++) {
          const p = rows[i],
            section = sections.get(String(p.section_id));
          if (!section)
            throw new Error("Membership tham chiếu lớp không tồn tại");
          const end = p.ends_at ?? null;
          if (!(p.starts_at instanceof Date) || (end && end < p.starts_at))
            throw new Error("Khoảng thuộc lớp không hợp lệ");
          if (i && (!rows[i - 1].ends_at || rows[i - 1].ends_at > p.starts_at))
            throw new Error("Các khoảng thuộc lớp bị chồng lấn");
          if (
            enrollment &&
            i === rows.length - 1 &&
            (enrollment.status === "ACTIVE") !== !end
          )
            throw new Error("Trạng thái và lịch sử thuộc lớp không khớp");
          membershipRows.push({
            ...p,
            course_id: section.course_id,
            semester_id: section.semester_id,
            ends_at: end,
            version:
              i === rows.length - 1
                ? (enrollment?.version ?? p.version ?? 0)
                : (p.version ?? 0),
            legacy_data: {
              enrollment: enrollment ?? null,
              period:
                sources.enrollmentperiods.find(
                  (x) => String(x._id) === String(p._id),
                ) ?? null,
            },
          });
        }
      }
      const logs = [
        ...sources.audits.map((r) => ({
          ...r,
          category: "AUDIT",
          legacy_data: { source: "audits", document: r },
        })),
        ...sources.sessionhistories.map((r) => ({
          _id: r._id,
          actor_id: r.actor_id,
          action: r.action,
          entity: "ClassSession",
          entity_id: r.session_id,
          request_id: r.request_id ?? null,
          category: "SESSION_HISTORY",
          before_data: r.before_data,
          after_data: r.after_data,
          created_at: r.created_at,
          updated_at: r.updated_at,
          version: r.version ?? 0,
          legacy_data: { source: "sessionhistories", document: r },
        })),
        ...sources.noticereads.map((r) => ({
          _id: r._id,
          actor_id: r.user_id,
          action: "READ_NOTICE",
          entity: "Notice",
          entity_id: r.notice_id,
          category: "AUDIT",
          created_at: r.created_at ?? r.read_at,
          updated_at: r.updated_at ?? r.read_at,
          version: r.version ?? 0,
          legacy_data: { source: "noticereads", document: r },
        })),
      ];
      for (const [Model, rows] of [
        [ClassMembership, membershipRows],
        [ActivityLog, logs],
      ])
        for (const row of rows) {
          const validated = new Model(row);
          await validated.validate();
          const existing = await Model.collection.findOne(
            { _id: row._id },
            { session },
          );
          if (existing)
            throw new Error(
              "Đích migration đã có ID trùng: " + Model.collection.name,
            );
          await Model.collection.insertOne(validated.toObject(), { session });
        }
      // Lưu fingerprint cả document đích để kiểm chứng trước khi xoá nguồn, hỗ trợ chạy lại sau gián đoạn.
      const targets = {};
      for (const [Model, rows] of [
        [ClassMembership, membershipRows],
        [ActivityLog, logs],
      ]) {
        const docs = await Model.collection
          .find({ _id: { $in: rows.map((r) => r._id) } }, { session })
          .sort({ _id: 1 })
          .toArray();
        if (docs.length !== rows.length)
          throw new Error("Số lượng đích không khớp");
        targets[Model.collection.name] = {
          ids: docs.map((d) => d._id),
          hash: digest(docs),
        };
      }
      await ImportBatch.create(
        [
          {
            source_hash: marker,
            counts: { sources: summary, hashes, targets },
          },
        ],
        { session },
      );
    });
  const checkpoint = await ImportBatch.findOne({ source_hash: marker }).lean();
  for (const [name, target] of Object.entries(checkpoint.counts.targets)) {
    const docs = await db
      .collection(name)
      .find({ _id: { $in: target.ids } })
      .sort({ _id: 1 })
      .toArray();
    if (docs.length !== target.ids.length || digest(docs) !== target.hash)
      throw new Error("Không xác minh được dữ liệu đích; giữ nguyên nguồn");
  }
  for (const name of legacyCollections) {
    if (!(await db.listCollections({ name }, { nameOnly: true }).hasNext()))
      continue;
    const current = await sourceRows(name);
    if (current.length && digest(current) !== checkpoint.counts.hashes[name])
      throw new Error("Nguồn đã thay đổi; không xoá " + name);
    await db.collection(name).drop();
  }
  return {
    apply: true,
    sources: checkpoint.counts.sources,
    collections: (
      await db.listCollections({}, { nameOnly: true }).toArray()
    ).map((c) => c.name),
  };
}
