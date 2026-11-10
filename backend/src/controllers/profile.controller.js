import * as service from "../services/profile.service.js";
export const getProfile = async (req, res) =>
  res.json(await service.getProfile(req.user));
