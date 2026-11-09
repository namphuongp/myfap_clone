import bcrypt from "bcryptjs";
import {
  userRepository,
  departmentRepository,
  authSessionRepository,
} from "../repositories/index.js";
import {
  majorRepository,
  majorTransferRepository,
} from "../repositories/student-affairs.repositories.js";
import { get, saveDocument } from "../repositories/base.repository.js";
import { transaction } from "../repositories/transaction.js";
import { audit } from "./audit.service.js";
import { clean } from "../utils/serialize.js";
import { checkVersion } from "../utils/version.js";
import { fail } from "../utils/api-error.js";
export async function getProfile(actor) {
  const user = await get(userRepository, actor._id);
  const department = await departmentRepository.findById(user.department_id);
  const major = user.major_id
    ? await majorRepository.findById(user.major_id)
    : null;
  const pending =
    user.role === "STUDENT"
      ? await majorTransferRepository.findOne({
          student_id: user._id,
          status: { $in: ["PENDING", "APPROVED"] },
          applied_at: null,
        })
      : null;
  return {
    ...clean(user),
    phone: user.phone ?? null,
    address: user.address ?? null,
    date_of_birth: user.date_of_birth ?? null,
    major_id: user.major_id ? String(user.major_id) : null,
    department: department
      ? {
          id: String(department._id),
          code: department.code,
          name: department.name,
        }
      : null,
    major: major
      ? { id: String(major._id), code: major.code, name: major.name }
      : null,
    pending_major_transfer: clean(pending),
  };
}
export async function updateProfile(actor, data) {
  await transaction(async (session) => {
    const user = await get(userRepository, actor._id, session);
    checkVersion(user, data.version);
    const before = {
      phone: user.phone ?? null,
      address: user.address ?? null,
      date_of_birth: user.date_of_birth ?? null,
    };
    for (const key of ["phone", "address", "date_of_birth"])
      if (Object.hasOwn(data, key)) user[key] = data[key];
    await saveDocument(user, { session });
    await audit(session, actor, "UPDATE_PROFILE", "User", user._id, before, {
      phone: user.phone,
      address: user.address,
      date_of_birth: user.date_of_birth,
    });
  });
  return getProfile(actor);
}
export async function changePassword(actor, data) {
  const user = await userRepository.findById(actor._id, {
    select: "+password_hash",
  });
  if (!(await bcrypt.compare(data.current_password, user.password_hash)))
    fail(400, "Mật khẩu hiện tại không đúng");
  if (await bcrypt.compare(data.new_password, user.password_hash))
    fail(400, "Mật khẩu mới phải khác mật khẩu hiện tại");
  const passwordHash = await bcrypt.hash(data.new_password, 12);
  await transaction(async (session) => {
    const current = await userRepository.findById(actor._id, {
      session,
      select: "+password_hash",
    });
    if (current.password_hash !== user.password_hash)
      fail(409, "Mật khẩu đã thay đổi, hãy đăng nhập lại");
    current.password_hash = passwordHash;
    await saveDocument(current, { session });
    await authSessionRepository.deleteMany({ user_id: actor._id }, { session });
    await audit(session, actor, "CHANGE_PASSWORD", "User", actor._id, null, {
      sessions_revoked: true,
    });
  });
  return { message: "Đổi mật khẩu thành công, vui lòng đăng nhập lại" };
}
