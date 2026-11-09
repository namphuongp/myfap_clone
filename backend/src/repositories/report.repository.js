import { Types } from "mongoose";
import { classSessionRepository } from "./index.js";
const statusCount = (status) => ({
  $size: {
    $filter: {
      input: "$attendance",
      as: "a",
      cond: { $eq: ["$$a.status", status] },
    },
  },
});
export const reportRepository = {
  attendanceBySections(ids) {
    return classSessionRepository.aggregate([
      {
        $match: {
          section_id: { $in: ids.map((id) => new Types.ObjectId(String(id))) },
        },
      },
      {
        $group: {
          _id: "$section_id",
          sessions: {
            $sum: { $cond: [{ $ne: ["$status", "CANCELLED"] }, 1, 0] },
          },
          cancelled_sessions: {
            $sum: { $cond: [{ $eq: ["$status", "CANCELLED"] }, 1, 0] },
          },
          completed_sessions: {
            $sum: { $cond: [{ $eq: ["$status", "COMPLETED"] }, 1, 0] },
          },
          recorded_sessions: {
            $sum: {
              $cond: [
                {
                  $and: [
                    { $ne: ["$status", "CANCELLED"] },
                    "$attendance_saved",
                  ],
                },
                1,
                0,
              ],
            },
          },
          present: {
            $sum: {
              $cond: [
                { $ne: ["$status", "CANCELLED"] },
                statusCount("PRESENT"),
                0,
              ],
            },
          },
          late: {
            $sum: {
              $cond: [
                { $ne: ["$status", "CANCELLED"] },
                statusCount("LATE"),
                0,
              ],
            },
          },
          absent: {
            $sum: {
              $cond: [
                { $ne: ["$status", "CANCELLED"] },
                statusCount("ABSENT"),
                0,
              ],
            },
          },
          excused: {
            $sum: {
              $cond: [
                { $ne: ["$status", "CANCELLED"] },
                statusCount("EXCUSED"),
                0,
              ],
            },
          },
        },
      },
    ]);
  },
};
