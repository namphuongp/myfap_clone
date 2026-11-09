import * as service from "../services/profile.service.js";
export const getProfile = async (req, res) =>
  res.json(await service.getProfile(req.user));
export const updateProfile = async (req, res) =>
  res.json(await service.updateProfile(req.user, req.validated.body));
export const changePassword = async (req, res) =>
  res.json(await service.changePassword(req.user, req.validated.body));
