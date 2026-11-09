import { fail } from "../utils/api-error.js";

// Repository nhận filter nội bộ đã được service xây dựng, không nhận req/body trực tiếp.
export class MongooseRepository {
  #model;
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
  find(filter = {}, options) {
    return this.#options(this.#model.find(filter), options);
  }
  findOne(filter = {}, options) {
    return this.#options(this.#model.findOne(filter), options);
  }
  findById(id, options) {
    return this.#options(this.#model.findById(id), options);
  }
  exists(filter, options) {
    return this.#options(this.#model.exists(filter), options);
  }
  countDocuments(filter = {}, options) {
    return this.#options(this.#model.countDocuments(filter), options);
  }
  distinct(field, filter = {}, options) {
    return this.#options(this.#model.distinct(field, filter), options);
  }
  aggregate(pipeline, { session } = {}) {
    const query = this.#model.aggregate(pipeline);
    if (session) query.session(session);
    return query.exec();
  }
  instantiate(data) {
    return new this.#model(data);
  }
  async create(data, options = {}) {
    const rows = await this.#model.create(Array.isArray(data) ? data : [data], {
      ...options,
      ordered: true,
    });
    return Array.isArray(data) ? rows : rows[0];
  }
  updateOne(filter, update, options = {}) {
    return this.#model
      .updateOne(filter, update, { ...options, runValidators: true })
      .exec();
  }
  deleteOne(filter, options) {
    return this.#model.deleteOne(filter, options).exec();
  }
  deleteMany(filter, options) {
    return this.#model.deleteMany(filter, options).exec();
  }
}
export async function get(repository, key, session) {
  const row = await repository.findById(key, { session });
  if (!row) fail(404, "Không tìm thấy dữ liệu");
  return row;
}
// Giữ lifecycle/version của document Mongoose nhưng tập trung thao tác lưu tại repository.
export function saveDocument(document, options = {}) {
  return document.save(options);
}
