import { fail } from "../../../utils/api-error.js";
import { same } from "../../../utils/identity.js";
import { clean } from "../../../utils/serialize.js";
import { get } from "../../../repositories/base.repository.js";
import { transaction } from "../../../repositories/transaction.js";
import { audit } from "./audit.service.js";
import { sectionFilter } from "./access.service.js";
import {
  courseRepository,
  semesterRepository,
  sectionRepository,
} from "../../../repositories/index.js";
// Lấy lớp học phần trong phạm vi được phép.
export async function listSections(user, q = {}) {
  return await decorate(
    await sectionRepository.find(
      {
        ...(await sectionFilter(user)),
        ...Object.fromEntries(
          ["course_id", "semester_id"]
            .filter((key) => q[key])
            .map((key) => [key, q[key]]),
        ),
      },
      {
        sort: { _id: 1 },
        limit: 200,
      },
    ),
  );
}
// Tạo lớp học phần; chưa bắt buộc có giảng viên.
export async function createSection(user, data) {
  // TL3: Chỉ tạo lớp cho môn cùng bộ môn/kỳ còn hiệu lực; lớp mặc định CLOSED, 30 chỗ.
  const result = await transaction(async (session) => {
    const course = await get(courseRepository, data.course_id, session);
    const semester = await get(semesterRepository, data.semester_id, session);
    if (!same(course.department_id, user.department_id))
      fail(403, "Môn ngoài bộ môn");
    if (course.active === false) fail(409, "Môn đã ngừng sử dụng");
    if (semester.end_at <= new Date()) fail(409, "Học kỳ đã kết thúc");
    const [row] = await sectionRepository.create(
      [
        {
          ...data,
          department_id: course.department_id,
          capacity: 30,
          status: "CLOSED",
        },
      ],
      { session },
    );
    await audit(session, user, "CREATE_SECTION", "Section", row._id, null, row);
    return sectionDto(row);
  });
  return result;
}
// Bổ sung tên môn và học kỳ cho danh sách lớp.
async function decorate(rows) {
  const courses = await courseRepository.find({
    _id: { $in: rows.map((s) => s.course_id) },
  });
  const semesters = await semesterRepository.find({
    _id: { $in: rows.map((s) => s.semester_id) },
  });
  return rows.map((s) => ({
    ...sectionDto(s),
    course: courses.find((c) => same(c._id, s.course_id))?.name,
    course_code: courses.find((c) => same(c._id, s.course_id))?.code,
    semester_code: semesters.find((t) => same(t._id, s.semester_id))?.code,
  }));
}

// Ẩn giảng viên legacy và trả dữ liệu lớp theo phân công từng buổi.
function sectionDto(row) {
  const dto = clean(row);
  delete dto.lecturer_id;
  return { ...dto, assignment_basis: "SESSION" };
}
