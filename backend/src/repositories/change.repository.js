import { Change } from "../models/change.model.js";
import { MongooseRepository } from "./base.repository.js";
export const changeRepository = new MongooseRepository(Change);
