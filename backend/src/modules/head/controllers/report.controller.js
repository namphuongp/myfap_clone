import * as service from "../services/report.service.js";
// Tổng hợp tình hình giảng dạy theo bộ môn.
export const departmentSummary = async (req, res) =>
  res.json(await service.departmentSummary(req.user, req.validated.query));
// Tổng hợp điểm danh trong phạm vi bộ môn.
export const attendanceReport = async (req, res) =>
  res.json(await service.attendanceReport(req.user, req.validated.query));
// Tổng hợp các đơn trong phạm vi bộ môn.
export const requestReport = async (req, res) =>
  res.json(await service.requestReport(req.user, req.validated.query));
