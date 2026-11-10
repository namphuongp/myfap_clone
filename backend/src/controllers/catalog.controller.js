import * as service from "../services/catalog.service.js";
export const timeSlots = async (req, res) =>
  res.json(await service.timeSlots());
export const listCatalog = (kind) => async (req, res) =>
  res.json(await service.listCatalog(kind, req.user));
export const createCourse = async (req, res) =>
  res
    .status(201)
    .json(await service.createCourse(req.user, req.validated.body));
export const updateCourse = async (req, res) =>
  res.json(
    await service.updateCourse(req.user, req.params.id, req.validated.body),
  );

export const listMajors = async (req, res) =>
  res.json(await service.listMajors(req.user));
