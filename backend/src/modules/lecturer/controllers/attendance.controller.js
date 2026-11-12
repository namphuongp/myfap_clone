import * as service from "../services/attendance.service.js";
// Lấy danh sách điểm danh và ghi chú đơn nghỉ đã duyệt.
export const getAttendance = async (req, res) => {
  const result = await service.getAttendance(req.user, req.params.id);
  res.json(result);
};
// Ghi đủ danh sách điểm danh, kiểm tra quyền và phiên bản.
export const saveAttendance = async (req, res) => {
  const result = await service.saveAttendance(
    req.user,
    req.params.id,
    req.validated.body,
  );
  res.json(result);
};
