import * as service from "../services/notice.service.js";
// Tạo thông báo nháp sau khi kiểm tra đối tượng nhận.
export const createNotice = async (req, res) =>
  res
    .status(201)
    .json(await service.createNotice(req.user, req.validated.body));
// Phát hành thông báo với kiểm tra phiên bản.
export const publishNotice = async (req, res) =>
  res.json(
    await service.publishNotice(req.user, req.params.id, req.validated.body),
  );
// Lấy thông báo đúng đối tượng và trạng thái.
export const listNotices = async (req, res) =>
  res.json(await service.listNotices(req.user, req.validated.query));
// Đọc thông báo nếu người dùng thuộc đối tượng nhận.
export const getNotice = async (req, res) =>
  res.json(await service.getNotice(req.user, req.params.id));
