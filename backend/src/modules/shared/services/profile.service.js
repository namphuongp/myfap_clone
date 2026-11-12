import { userRepository } from "../../../repositories/index.js";
import { majorRepository } from "../../../repositories/index.js";
import { get } from "../../../repositories/base.repository.js";
export async function getProfile(actor) {
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
