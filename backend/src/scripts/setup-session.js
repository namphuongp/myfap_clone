import { connect, disconnect, initialize } from "../config/database.js";
import { userRepository } from "../repositories/index.js";
import { get } from "../repositories/base.repository.js";
import { createSession } from "../services/session.service.js";
import { createSessionSchema } from "../validators/session.validator.js";
import { id } from "../validators/common.js";
const args = Object.fromEntries(
  process.argv.slice(2).map((arg) => {
    const i = arg.indexOf("=");
    if (i < 0) throw new Error("Dùng --key=value");
    return [arg.slice(2, i), arg.slice(i + 1)];
  }),
);
try {
  const headId = id.parse(args.head);
  const data = createSessionSchema.parse({
    section_id: args.section,
    room_id: args.room,
    session_date: args.date,
    slot_id: Number(args.slot),
  });
  await connect();
  await initialize();
  const actor = await get(userRepository, headId);
  if (actor.role !== "HEAD" || !actor.active)
    throw new Error("Cần HEAD hoạt động của bộ môn");
  const row = await createSession(actor, data);
  console.log(
    JSON.stringify({
      id: row.id,
      section_id: row.section_id,
      session_date: row.session_date,
      slot_id: row.slot_id,
      lecturer_id: row.lecturer_id,
    }),
  );
} finally {
  await disconnect();
}
