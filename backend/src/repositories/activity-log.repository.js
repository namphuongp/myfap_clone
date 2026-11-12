import { ActivityLog } from "../models/activity-log.model.js";
import { MongooseRepository } from "./base.repository.js";
export const activityLogRepository = new MongooseRepository(ActivityLog);
