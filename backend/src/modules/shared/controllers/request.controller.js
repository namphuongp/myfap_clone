import * as service from "../services/request.service.js";
// XN5: Controller nhận người đăng nhập và dữ liệu hợp lệ, gọi service xử lý.
export const createLeave = async (req, res) => {
  const result = await service.createLeave(req.user, req.validated.body);
  res.status(201).json(result);
};
// Tạo đề xuất đổi lịch hoặc phòng của giảng viên phụ trách.
export const createChange = async (req, res) => {
  const result = await service.createChange(req.user, req.validated.body);
  res.status(201).json(result);
};
// Lấy các đơn theo quyền người gửi hoặc người duyệt.
export const listRequests = (kind) => async (req, res) => {
  const result = await service.listRequests(
    req.user,
    req.validated.query,
    kind,
  );
  res.json(result);
};
// Duyệt đơn với kiểm tra phiên bản, lịch và quyền phụ trách.
export const reviewRequest = (kind) => async (req, res) => {
  const result = await service.reviewRequest(
    req.user,
    req.params.id,
    req.validated.body,
    kind,
  );
  res.json(result);
};
