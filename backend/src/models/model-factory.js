import mongoose from "mongoose";
export const { Schema } = mongoose;
export const options = {
  timestamps: { createdAt: "created_at", updatedAt: "updated_at" },
  versionKey: "version",
  optimisticConcurrency: true,
  strict: "throw",
};
// Khai báo trường tham chiếu bắt buộc tới model.
export const ref = (model) => ({
  type: Schema.Types.ObjectId,
  ref: model,
  required: true,
});
// Khai báo chuỗi bắt buộc có giới hạn độ dài.
export const str = (max = 120) => ({
  type: String,
  required: true,
  trim: true,
  maxlength: max,
});
// Tạo model với cấu hình và index dùng chung.
export const model = (name, fields, indexes = []) => {
  const schema = new Schema(fields, options);
  for (const [keys, config] of indexes) schema.index(keys, config);
  return mongoose.model(name, schema);
};
