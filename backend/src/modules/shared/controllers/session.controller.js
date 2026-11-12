import * as service from "../services/session.service.js";
// Lấy lịch cá nhân đúng phạm vi và thời gian thuộc lớp.
export const personalSchedule = async (req, res) => {
  const result = await service.personalSchedule(req.user, req.validated.query);
  res.json(result);
};
// Lấy các buổi học trong lớp được phép xem.
export const sectionSessions = async (req, res) => {
  const result = await service.sectionSessions(req.user, req.params.id);
  res.json(result);
};
