import { applyDueMajorTransfers } from "../../shared/services/major-transfer.service.js";
import { transaction } from "../../../repositories/transaction.js";
import { fail } from "../../../utils/api-error.js";
import { clean } from "../../../utils/serialize.js";
import { hash, token } from "../../../utils/crypto.js";
import { databaseRepository } from "../../../repositories/database.repository.js";
import bcrypt from "bcryptjs";
import {
  userRepository,
  authSessionRepository,
} from "../../../repositories/index.js";
// Kiểm tra kết nối database.
export async function health() {
  await databaseRepository.ping();
  return { status: "ok", database: "mongodb" };
}
// Xác thực tài khoản và tạo phiên đăng nhập.
export async function login(data) {
  const user = await userRepository.findOne(
    { email: data.email },
    { select: "+password_hash" },
  );
  const valid = await bcrypt.compare(
    data.password,
    user?.password_hash ??
      "$2b$12$YgJE9YWOVcrTGLlX7ybzXu5xFxIx7Kf1T7QmZvJ6VCCbZz04HfA3O",
  );
  if (!user?.active || !valid) fail(401, "Email hoặc mật khẩu không đúng");
  if (user.role === "STUDENT")
    await applyDueMajorTransfers(new Date(), user._id);
  const accessToken = token();
  const hours = Number(process.env.SESSION_HOURS ?? 8);
  const expiresAt = new Date(
    Date.now() + (Number.isFinite(hours) && hours > 0 ? hours : 8) * 3600000,
  );
  return transaction(async (session) => {
    const current = await userRepository.findById(user._id, {
      session,
      select: "+password_hash",
    });
    if (!current?.active || current.password_hash !== user.password_hash)
      fail(401, "Thông tin đăng nhập đã thay đổi");
    await authSessionRepository.create(
      {
        user_id: current._id,
        token_hash: hash(accessToken),
        expires_at: expiresAt,
      },
      { session },
    );
    return { accessToken, expiresAt, user: clean(current) };
  });
}
// Kiểm tra token, tài khoản và cập nhật chuyển ngành đã đến hạn.
export async function resolveSession(bearer) {
  if (!bearer) fail(401, "Cần đăng nhập");
  const auth = await authSessionRepository.findOne({
    token_hash: hash(bearer),
    expires_at: { $gt: new Date() },
  });
  if (!auth) fail(401, "Phiên đã hết hạn");
  let user = await userRepository.findOne({
    _id: auth.user_id,
    active: true,
  });
  if (!user) fail(401, "Phiên không hợp lệ");
  if (user.role === "STUDENT") {
    await applyDueMajorTransfers(new Date(), user._id);
    user = await userRepository.findById(user._id);
  }
  return { user, auth };
}
// Thu hồi phiên đăng nhập hiện tại.
export async function logout(auth) {
  await authSessionRepository.deleteOne({ _id: auth._id });
}
