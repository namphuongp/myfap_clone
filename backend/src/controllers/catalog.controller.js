import * as service from "../services/catalog.service.js";
export const timeSlots = async (req, res) => {
  const result = await service.timeSlots();
  res.json(result);
};
export const listCatalog = (kind) => async (req, res) => {
  const result = await service.listCatalog(kind);
  res.json(result);
};
export const createCatalog = (kind) => async (req, res) => {
  const result = await service.createCatalog(
    req.user,
    req.validated.body,
    kind,
  );
  res.status(201).json(result);
};
export const createUser = async (req, res) => {
  const result = await service.createUser(req.user, req.validated.body);
  res.status(201).json(result);
};
