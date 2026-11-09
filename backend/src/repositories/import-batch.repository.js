import { ImportBatch } from "../models/import-batch.model.js";
import { MongooseRepository } from "./base.repository.js";
export const importBatchRepository = new MongooseRepository(ImportBatch);
