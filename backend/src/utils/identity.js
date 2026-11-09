import mongoose from "mongoose";
export const same = (a, b) => String(a) === String(b);
export const newId = () => new mongoose.Types.ObjectId();
