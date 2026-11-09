import * as service from "../services/major.service.js";
export const listMajors = async (req, res) =>
  res.json(await service.listMajors());
export const createMajor = async (req, res) =>
  res.status(201).json(await service.createMajor(req.user, req.validated.body));
export const updateCurriculum = async (req, res) =>
  res.json(
    await service.updateCurriculum(req.user, req.params.id, req.validated.body),
  );
export const assignInitialMajor = async (req, res) =>
  res.json(
    await service.assignInitialMajor(
      req.user,
      req.params.id,
      req.validated.body,
    ),
  );
export const createTransfer = async (req, res) =>
  res
    .status(201)
    .json(await service.createTransfer(req.user, req.validated.body));
export const listTransfers = async (req, res) =>
  res.json(await service.listTransfers(req.user, req.validated.query));
export const decideTransfer = async (req, res) =>
  res.json(
    await service.decideTransfer(req.user, req.params.id, req.validated.body),
  );
export const cancelTransfer = async (req, res) =>
  res.json(
    await service.cancelTransfer(req.user, req.params.id, req.validated.body),
  );
