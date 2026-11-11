import { Router } from "express";
import { getProfile } from "../controllers/profile.controller.js";
export function profileRoutes() {
  const router = Router();
  router.get("/profile", getProfile);
  return router;
}
