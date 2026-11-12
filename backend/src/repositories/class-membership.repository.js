import { Types } from "mongoose";
import { ClassMembership } from "../models/class-membership.model.js";
import { MongooseRepository } from "./base.repository.js";
class ClassMembershipRepository extends MongooseRepository {
  constructor() {
    super(ClassMembership);
  }
  activeCounts(sectionIds) {
    const ids = sectionIds.map((id) => new Types.ObjectId(String(id)));
    return this.aggregate([
      { $match: { section_id: { $in: ids }, ends_at: null } },
      { $group: { _id: "$section_id", count: { $sum: 1 } } },
    ]);
  }
  latestForStudent(studentId) {
    // Một sinh viên có thể rời rồi quay lại lớp; API chỉ trả khoảng gần nhất cho mỗi lớp.
    return this.aggregate([
      { $match: { student_id: new Types.ObjectId(String(studentId)) } },
      { $sort: { starts_at: -1, _id: -1 } },
      { $group: { _id: "$section_id", row: { $first: "$$ROOT" } } },
      { $replaceRoot: { newRoot: "$row" } },
      { $sort: { starts_at: -1 } },
      { $limit: 200 },
    ]);
  }
}
export const classMembershipRepository = new ClassMembershipRepository();
