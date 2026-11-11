import * as service from "../services/head-lecturer.service.js";
export const list = async (req, res) =>
  res.json(await service.list(req.user, req.validated.query));
export const detail = async (req, res) =>
  res.json(await service.detail(req.user, req.params.id));
export const create = async (req, res) =>
  res.status(201).json(await service.create(req.user, req.validated.body));
export const update = async (req, res) =>
  res.json(await service.update(req.user, req.params.id, req.validated.body));
