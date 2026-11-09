import { Leave } from "../models/leave.model.js";
import { MongooseRepository } from "./base.repository.js";
export const leaveRepository = new MongooseRepository(Leave);
