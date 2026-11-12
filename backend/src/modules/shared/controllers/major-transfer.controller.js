import * as service from "../services/major-transfer.service.js";

export const options = async (_req, res) => res.json(await service.options());
export const create = async (req, res) =>
  res.status(201).json(await service.create(req.user, req.validated.body));
export const list = async (req, res) =>
  res.json(await service.list(req.user, req.validated.query));
export const review = async (req, res) =>
  res.json(await service.review(req.user, req.params.id, req.validated.body));
