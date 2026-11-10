import * as service from "../services/attendance.service.js";
export const getAttendance = async (req, res) => {
  const result = await service.getAttendance(req.user, req.params.id);
  res.json(result);
};
export const saveAttendance = async (req, res) => {
  const result = await service.saveAttendance(
    req.user,
    req.params.id,
    req.validated.body,
  );
  res.json(result);
};
