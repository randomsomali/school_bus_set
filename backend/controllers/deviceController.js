import Device from "../models/device.model.js";
import { deviceSchema } from "../validators/validator.js";

// Get current device data (single record)
export const getDeviceData = async (req, res, next) => {
  try {
    const device = await Device.getOrCreate();
    res.json({ success: true, data: device });
  } catch (error) {
    next(error);
  }
};

// Update device data from ESP32 (overwrites existing data)
export const updateDeviceData = async (req, res, next) => {
  try {
    const validatedData = deviceSchema.parse(req.body);
    const device = await Device.updateDeviceData(validatedData);
    res.json({
      success: true,
      data: device,
      message: "Device data updated successfully",
    });
  } catch (error) {
    next(error);
  }
};
