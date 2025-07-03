import express from "express";
import userRoutes from "./userRoutes.js";
import authRoutes from "./auth.routes.js";
import studentRoutes from "./studentRoutes.js";
import deviceRoutes from "./deviceRoutes.js";
import attendanceRoutes from "./attendanceRoutes.js";
import esp32Routes from "./esp32.routes.js";

const router = express.Router();

// Authentication routes
router.use("/auth", authRoutes);

// Resource routes
router.use("/users", userRoutes);
router.use("/students", studentRoutes);
router.use("/device", deviceRoutes);
router.use("/attendance", attendanceRoutes);

// ESP32 routes (for both car wash and fingerprint systems)
router.use("/esp32", esp32Routes);

export default router;
