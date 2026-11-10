import * as service from "../services/session.service.js";
export const personalSchedule = async (req, res) => {
  const result = await service.personalSchedule(req.user, req.validated.query);
  res.json(result);
};
export const sectionSessions = async (req, res) => {
  const result = await service.sectionSessions(req.user, req.params.id);
  res.json(result);
};
