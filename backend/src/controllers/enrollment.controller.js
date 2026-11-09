import * as service from "../services/enrollment.service.js";
export const myEnrollments = async (req, res) => {
  const result = await service.myEnrollments(req.user);
  res.json(result);
};
export const listEnrollments = async (req, res) => {
  const result = await service.listEnrollments(req.user, req.params.id);
  res.json(result);
};
export const registerStudent = async (req, res) => {
  const result = await service.registerStudent(
    req.user,
    req.params.id,
    req.validated.body,
  );
  res.status(201).json(result);
};
export const withdrawStudent = async (req, res) => {
  const result = await service.withdrawStudent(
    req.user,
    req.params.id,
    req.validated.body,
    req.params.studentId,
  );
  res.json(result);
};
