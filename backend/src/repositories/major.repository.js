import { Major } from "../models/major.model.js";
import { MongooseRepository } from "./base.repository.js";
export const majorRepository = new MongooseRepository(Major);
