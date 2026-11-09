import { Audit } from "../models/audit.model.js";
import { MongooseRepository } from "./base.repository.js";
export const auditRepository = new MongooseRepository(Audit);
