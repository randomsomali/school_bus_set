import express from "express";
import {
  pollFingerprintCommand,
  createFingerprintAttendance,
} from "../controllers/fingerprint.controller.js";

const router = express.Router();

// Fingerprint system endpoints
router.get("/fingerprint/poll", pollFingerprintCommand);
router.post("/fingerprint/attendance", createFingerprintAttendance);

export default router;
