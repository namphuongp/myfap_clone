import {
  userRepository,
  majorRepository,
} from "../../../repositories/index.js";

import { get } from "../../../repositories/base.repository.js";
// Trả thông tin hồ sơ chỉ đọc của người đăng nhập.
export async function getProfile(actor) {
  // HS4: Chỉ lấy user theo ID trong token và bổ sung tên ngành hiện tại của sinh viên.
  const user = await get(userRepository, actor._id);
  const major =
    user.role === "STUDENT" && user.major_id
      ? await majorRepository.findById(user.major_id)
      : null;
  return {
    id: String(user._id),
    user_code: user.user_code,
    name: user.name,
    email: user.email,
    role: user.role,
    major: major
      ? { id: String(major._id), code: major.code, name: major.name }
      : null,
  };
}
