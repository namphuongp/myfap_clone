import * as service from "../services/notice.service.js";
export const createNotice = async (req, res) =>
  res
    .status(201)
    .json(await service.createNotice(req.user, req.validated.body));
export const updateNotice = async (req, res) =>
  res.json(
    await service.updateNotice(req.user, req.params.id, req.validated.body),
  );
export const publishNotice = async (req, res) =>
  res.json(
    await service.publishNotice(req.user, req.params.id, req.validated.body),
  );
export const archiveNotice = async (req, res) =>
  res.json(
    await service.archiveNotice(req.user, req.params.id, req.validated.body),
  );
export const listNotices = async (req, res) =>
  res.json(await service.listNotices(req.user, req.validated.query));
export const getNotice = async (req, res) =>
  res.json(await service.getNotice(req.user, req.params.id));
export const markRead = async (req, res) =>
  res.json(await service.markRead(req.user, req.params.id));
