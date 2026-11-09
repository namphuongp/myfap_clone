import { Section } from "../models/section.model.js";
import { MongooseRepository } from "./base.repository.js";
export const sectionRepository = new MongooseRepository(Section);
