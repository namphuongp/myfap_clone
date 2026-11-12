import { Router } from "express";
import { sharedRoutes } from "../modules/shared/shared.routes.js";
import { studentRoutes } from "../modules/student/student.routes.js";
import { lecturerRoutes } from "../modules/lecturer/lecturer.routes.js";
import { headRoutes } from "../modules/head/head.routes.js";
import { staffRoutes } from "../modules/staff/staff.routes.js";
export { authRoutes } from "../modules/auth/auth.routes.js";
export function protectedRoutes(){const router=Router();router.use(sharedRoutes(),studentRoutes(),lecturerRoutes(),headRoutes(),staffRoutes());return router;}
