import * as service from "../services/request.service.js";
export const createLeave = async (req, res) => {
  const result = await service.createLeave(req.user, req.validated.body);
  res.status(201).json(result);
};
export const createChange = async (req, res) => {
  const result = await service.createChange(req.user, req.validated.body);
  res.status(201).json(result);
};
export const listRequests = (kind) => async (req, res) => {
  const result = await service.listRequests(
    req.user,
    req.validated.query,
    kind,
  );
  res.json(result);
};
export const reviewRequest = (kind) => async (req, res) => {
  const result = await service.reviewRequest(
    req.user,
    req.params.id,
    req.validated.body,
    kind,
  );
  res.json(result);
};
