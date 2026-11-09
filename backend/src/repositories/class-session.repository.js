import { ClassSession } from "../models/class-session.model.js";
import { MongooseRepository } from "./base.repository.js";
export const classSessionRepository = new MongooseRepository(ClassSession);
