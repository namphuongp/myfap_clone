import { User } from "../models/user.model.js";
import { MongooseRepository } from "./base.repository.js";
export const userRepository = new MongooseRepository(User);
