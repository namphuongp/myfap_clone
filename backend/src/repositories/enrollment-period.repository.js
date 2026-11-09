import { EnrollmentPeriod } from "../models/enrollment-period.model.js";
import { MongooseRepository } from "./base.repository.js";
export const enrollmentPeriodRepository = new MongooseRepository(
  EnrollmentPeriod,
);
