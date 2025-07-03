import express from "express";
import {
  getDeviceData,
  updateDeviceData,
} from "../controllers/deviceController.js";
import { validate } from "../middlewares/validationMiddleware.js";
import { deviceSchema } from "../validators/validator.js";

const router = express.Router();

// Device routes (public for ESP32, but can be protected if needed)
router.get("/", getDeviceData);
router.put("/", validate(deviceSchema), updateDeviceData);

export default router;
