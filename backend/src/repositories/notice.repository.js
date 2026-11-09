import { Notice } from "../models/notice.model.js";
import { MongooseRepository } from "./base.repository.js";
export const noticeRepository = new MongooseRepository(Notice);
