import * as service from "../services/catalog.service.js";
export const timeSlots = async (req, res) =>
  res.json(await service.timeSlots());
export const listCatalog = (kind) => async (req, res) =>
  res.json(await service.listCatalog(kind, req.user));
