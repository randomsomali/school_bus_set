import mongoose from "mongoose";

const deviceSchema = new mongoose.Schema(
  {
    temperature: {
      type: Number,
      required: true,
      default: 0,
    },
    humidity: {
      type: Number,
      required: true,
      default: 0,
    },
    gasSensor: {
      type: Number,
      enum: [0, 1],
      required: true,
      default: 0,
    },
    latitude: {
      type: Number,
      required: true,
      default: 0,
    },
    longitude: {
      type: Number,
      required: true,
      default: 0,
    },
  },
  {
    timestamps: true,
  }
);

// Ensure only one device record exists with realistic default data
deviceSchema.statics.getOrCreate = async function () {
  let device = await this.findOne();
  if (!device) {
    device = await this.create({
      temperature: 25.5,
      humidity: 60,
      gasSensor: 0,
      latitude: 24.7136, // Riyadh coordinates
      longitude: 46.6753,
    });
    console.log("✅ Default device data created with Riyadh coordinates");
  }
  return device;
};

// Method to update device data (overwrites existing data)
deviceSchema.statics.updateDeviceData = async function (data) {
  let device = await this.findOne();
  if (!device) {
    device = await this.create(data);
  } else {
    device = await this.findOneAndUpdate({}, data, { new: true });
  }
  return device;
};

// Initialize device with seed data if empty
deviceSchema.statics.initializeDevice = async function () {
  const deviceCount = await this.countDocuments();
  if (deviceCount === 0) {
    await this.create({
      temperature: 25.5,
      humidity: 60,
      gasSensor: 0,
      latitude: 24.7136, // Riyadh coordinates
      longitude: 46.6753,
    });
    console.log("✅ Device initialized with default data");
  }
};

const Device = mongoose.model("Device", deviceSchema);

export default Device;
