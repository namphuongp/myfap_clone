import { id } from "../validators/common.js";
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
export function validateId(req, res, next, value, name) {
  try {
    req.params[name] = id.parse(value);
    next();
  } catch (error) {
    next(error);
  }
}
