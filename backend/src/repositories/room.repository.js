import { Room } from "../models/room.model.js";
import { MongooseRepository } from "./base.repository.js";
export const roomRepository = new MongooseRepository(Room);
