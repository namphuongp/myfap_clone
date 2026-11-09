import * as service from "../services/report.service.js";
export const departmentSummary = async (req, res) =>
  res.json(await service.departmentSummary(req.user, req.validated.query));
export const attendanceReport = async (req, res) =>
  res.json(await service.attendanceReport(req.user, req.validated.query));
export const requestReport = async (req, res) =>
  res.json(await service.requestReport(req.user, req.validated.query));
