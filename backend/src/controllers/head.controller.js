import * as service from "../services/head.service.js";
export const options = async (req, res) =>
  res.json(await service.options(req.user));
