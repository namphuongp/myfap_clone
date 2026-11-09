import { MajorTransfer } from "../models/major-transfer.model.js";
import { MongooseRepository } from "./base.repository.js";
export const majorTransferRepository = new MongooseRepository(MajorTransfer);
