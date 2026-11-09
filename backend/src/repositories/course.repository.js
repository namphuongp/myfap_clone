import { Course } from "../models/course.model.js";
import { MongooseRepository } from "./base.repository.js";
export const courseRepository = new MongooseRepository(Course);
