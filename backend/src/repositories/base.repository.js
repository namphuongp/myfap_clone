import { fail } from "../utils/api-error.js";

// Repository nhận filter nội bộ đã được service xây dựng, không nhận req/body trực tiếp.
export class MongooseRepository {
  #model;
  // Khởi tạo đối tượng và các phụ thuộc cần thiết.
  constructor(model) {
    this.#model = model;
    this.entityName = model.modelName;
  }
  #options(query, { session, select, sort, skip, limit, lean } = {}) {
    if (session) query.session(session);
    if (select) query.select(select);
    if (sort) query.sort(sort);
    if (skip !== undefined) query.skip(skip);
    if (limit !== undefined) query.limit(limit);
    if (lean) query.lean();
    return query.exec();
  }
  // Tìm danh sách theo bộ lọc nội bộ.
  find(filter = {}, options) {
    return this.#options(this.#model.find(filter), options);
  }
  // Tìm một bản ghi theo bộ lọc nội bộ.
  findOne(filter = {}, options) {
    return this.#options(this.#model.findOne(filter), options);
  }
  // Tìm bản ghi theo ID.
  findById(id, options) {
    return this.#options(this.#model.findById(id), options);
  }
  // Kiểm tra có bản ghi phù hợp hay không.
  exists(filter, options) {
    return this.#options(this.#model.exists(filter), options);
  }
  // Đếm bản ghi theo bộ lọc.
  countDocuments(filter = {}, options) {
    return this.#options(this.#model.countDocuments(filter), options);
  }
  // Lấy các giá trị không trùng theo bộ lọc.
  distinct(field, filter = {}, options) {
    return this.#options(this.#model.distinct(field, filter), options);
  }
  // Thực hiện tổng hợp dữ liệu trong repository.
  aggregate(pipeline, { session } = {}) {
    const query = this.#model.aggregate(pipeline);
    if (session) query.session(session);
    return query.exec();
  }
  // Tạo document để tiếp tục kiểm tra và lưu.
  instantiate(data) {
    return new this.#model(data);
  }
  // Tạo dữ liệu sau khi kiểm tra quyền và tính hợp lệ.
  async create(data, options = {}) {
    const rows = await this.#model.create(Array.isArray(data) ? data : [data], {
      ...options,
      ordered: true,
    });
    return Array.isArray(data) ? rows : rows[0];
  }
  // Cập nhật một bản ghi với kiểm tra schema.
  updateOne(filter, update, options = {}) {
    return this.#model
      .updateOne(filter, update, { ...options, runValidators: true })
      .exec();
  }
  // Xóa một bản ghi theo bộ lọc nội bộ.
  deleteOne(filter, options) {
    return this.#model.deleteOne(filter, options).exec();
  }
  // Xóa các bản ghi đúng bộ lọc nội bộ.
  deleteMany(filter, options) {
    return this.#model.deleteMany(filter, options).exec();
  }
}
// Lấy bản ghi bắt buộc tồn tại hoặc trả lỗi 404.
export async function get(repository, key, session) {
  const row = await repository.findById(key, { session });
  if (!row) fail(404, "Không tìm thấy dữ liệu");
  return row;
}
// Giữ lifecycle/version của document Mongoose nhưng tập trung thao tác lưu tại repository.
export function saveDocument(document, options = {}) {
  return document.save(options);
}
