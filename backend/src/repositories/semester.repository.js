import { Semester } from "../models/semester.model.js";
import { MongooseRepository } from "./base.repository.js";
export const semesterRepository = new MongooseRepository(Semester);
