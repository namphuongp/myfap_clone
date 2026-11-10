import * as service from "../services/assignment.service.js";
export const listLecturers = async (req, res) =>
  res.json(await service.listLecturers(req.user));
export const assignSessions = async (req, res) =>
  res.json(
    await service.assignSessions(req.user, req.params.id, req.validated.body),
  );
