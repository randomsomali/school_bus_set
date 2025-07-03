import express from "express";
import {
  createAttendance,
  getAllAttendance,
  getAttendanceByStudent,
  getTodayAttendance,
} from "../controllers/attendanceController.js";
import { authenticate, restrictTo } from "../middlewares/authmiddleware.js";
import { validate } from "../middlewares/validationMiddleware.js";
import { attendanceSchema } from "../validators/validator.js";

const router = express.Router();

// Public route for ESP32 to create attendance records
router.post("/", validate(attendanceSchema), createAttendance);

// Protected routes
// router.use(authenticate);

// Admin routes
router.get("/", getAllAttendance);
router.get("/today", getTodayAttendance);

// Student-specific routes (admin and parent can access)
router.get("/student/:studentId", getAttendanceByStudent);

export default router;
