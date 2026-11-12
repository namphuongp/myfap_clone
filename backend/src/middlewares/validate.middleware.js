import { id } from "../modules/shared/validators/common.js";
// Kiểm tra dữ liệu đầu vào theo schema.
export function validate(schema, source = "body") {
  return (req, res, next) => {
    try {
      const resolved = typeof schema === "function" ? schema(req.user) : schema;
      req.validated ??= {};
      req.validated[source] = resolved.parse(req[source] ?? {});
      next();
    } catch (error) {
      next(error);
    }
  };
}
// Kiểm tra định dạng ID trên đường dẫn.
export function validateId(req, res, next, value, name) {
  try {
    req.params[name] = id.parse(value);
    next();
  } catch (error) {
    next(error);
  }
}
