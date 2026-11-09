import { SessionHistory } from "../models/session-history.model.js";
import { MongooseRepository } from "./base.repository.js";
export const sessionHistoryRepository = new MongooseRepository(SessionHistory);
