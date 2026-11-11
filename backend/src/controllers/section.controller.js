import * as service from "../services/section.service.js";
export const availableSections = async (req, res) => {
  const result = await service.availableSections(req.user, req.validated.query);
  res.json(result);
};
export const listSections = async (req, res) => {
  const result = await service.listSections(req.user, req.validated.query);
  res.json(result);
};
export const createSection = async (req, res) => {
  const result = await service.createSection(req.user, req.validated.body);
  res.status(201).json(result);
};
export const setSectionStatus = async (req, res) => {
  const result = await service.setSectionStatus(
    req.user,
    req.params.id,
    req.validated.body,
  );
  res.json(result);
};
