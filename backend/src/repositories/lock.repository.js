import { Lock } from "../models/lock.model.js";
import { MongooseRepository } from "./base.repository.js";
export const lockRepository = new MongooseRepository(Lock);
