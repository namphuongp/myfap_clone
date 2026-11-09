import { Types } from "mongoose";
import { Enrollment } from "../models/enrollment.model.js";
import { MongooseRepository } from "./base.repository.js";
class EnrollmentRepository extends MongooseRepository {
  constructor() {
    super(Enrollment);
  }
  activeCounts(sectionIds) {
    // Aggregation không tự cast ObjectId như find; chuyển ID trước khi lọc.
    const ids = sectionIds.map((id) => new Types.ObjectId(String(id)));
    return this.aggregate([
      { $match: { section_id: { $in: ids }, status: "ACTIVE" } },
      { $group: { _id: "$section_id", count: { $sum: 1 } } },
    ]);
  }
}
export const enrollmentRepository = new EnrollmentRepository();
