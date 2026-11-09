import { AuthSession } from "../models/auth-session.model.js";
import { MongooseRepository } from "./base.repository.js";
export const authSessionRepository = new MongooseRepository(AuthSession);
