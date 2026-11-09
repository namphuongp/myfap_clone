import { id, version, body } from "./common.js";

export const registerStudentSchema = (user) =>
  user.role === "STUDENT" ? body({}) : body({ student_id: id });
export const withdrawStudentSchema = body({ version });
