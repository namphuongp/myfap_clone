import * as service from "../services/auth.service.js";
export const health = async (req, res) => {
  const result = await service.health();
  res.json(result);
};
export const login = async (req, res) => {
  const result = await service.login(req.validated.body);
  res.json(result);
};

export const logout = async (req, res) => {
  await service.logout(req.auth);
  res.status(204).end();
};
