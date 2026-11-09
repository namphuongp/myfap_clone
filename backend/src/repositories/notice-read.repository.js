import { NoticeRead } from "../models/notice-read.model.js";
import { MongooseRepository } from "./base.repository.js";
export const noticeReadRepository = new MongooseRepository(NoticeRead);
