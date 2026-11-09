import * as service from "../services/session.service.js";
export const personalSchedule = async (req, res) => {
  const result = await service.personalSchedule(req.user, req.validated.query);
  res.json(result);
};
export const sectionSessions = async (req, res) => {
  const result = await service.sectionSessions(req.user, req.params.id);
  res.json(result);
};
export const createSession = async (req, res) => {
  const result = await service.createSession(req.user, req.validated.body);
  res.status(201).json(result);
};
export const changeSchedule = async (req, res) => {
  const result = await service.changeSchedule(
    req.user,
    req.params.id,
    req.validated.body,
  );
  res.json(result);
};
export const setSessionStatus = async (req, res) => {
  const result = await service.setSessionStatus(
    req.user,
    req.params.id,
    req.validated.body,
  );
  res.json(result);
};
export const sessionHistory = async (req, res) => {
  const result = await service.sessionHistory(req.user, req.params.id);
  res.json(result);
};
