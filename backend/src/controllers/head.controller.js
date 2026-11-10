import * as service from "../services/head.service.js";
export const options = async (req, res) =>
  res.json(await service.options(req.user));
export const courses = async (req, res) =>
  res.json(await service.courses(req.user, req.validated.query));
export const sections = async (req, res) =>
  res.json(await service.sections(req.user, req.validated.query));
export const createCourse = async (req, res) =>
  res
    .status(201)
    .json(await service.createCourse(req.user, req.validated.body));
export const updateCourse = async (req, res) =>
  res.json(
    await service.updateCourse(req.user, req.params.id, req.validated.body),
  );
export const assignLecturer = async (req, res) =>
  res.json(
    await service.assignLecturer(req.user, req.params.id, req.validated.body),
  );
