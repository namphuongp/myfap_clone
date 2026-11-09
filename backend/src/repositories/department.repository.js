import { Department } from "../models/department.model.js";
import { MongooseRepository } from "./base.repository.js";
export const departmentRepository = new MongooseRepository(Department);
