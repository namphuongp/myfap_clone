import { Types } from "mongoose";
import { ClassMembership } from "../models/class-membership.model.js";
import { MongooseRepository } from "./base.repository.js";
class ClassMembershipRepository extends MongooseRepository {
  // Khởi tạo đối tượng và các phụ thuộc cần thiết.
  constructor() {
    super(ClassMembership);
  }
  // Đếm sinh viên còn thuộc từng lớp.
  activeCounts(sectionIds) {
    const ids = sectionIds.map((id) => new Types.ObjectId(String(id)));
    return this.aggregate([
      { $match: { section_id: { $in: ids }, ends_at: null } },
      { $group: { _id: "$section_id", count: { $sum: 1 } } },
    ]);
  }
}
export const classMembershipRepository = new ClassMembershipRepository();
