import mongoose from "mongoose";
import { databaseRepository } from "../repositories/database.repository.js";
export async function connect(uri = process.env.MONGODB_URI) {
  if (!uri) throw new Error("Thiếu MONGODB_URI trong .env");
  mongoose.set("strictQuery", "throw");
  await mongoose.connect(uri, {
    serverSelectionTimeoutMS: 10000,
    maxPoolSize: 15,
    autoIndex: false,
  });
  const hello = await mongoose.connection.db.admin().command({ hello: 1 });
  if (!hello.setName && !hello.msg?.includes("isdbgrid"))
    throw new Error("MongoDB cần replica set để hỗ trợ transaction");
}
export const initialize = () => databaseRepository.initialize();
export const disconnect = () => mongoose.disconnect();
