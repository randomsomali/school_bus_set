import mongoose from "mongoose";
import { DB_URI } from "../config/env.js";
import User from "../models/users.model.js";
import Device from "../models/device.model.js";

if (!DB_URI) {
  throw new Error("Please define the DB_URI environment variable inside .env");
}

const connectToDatabase = async () => {
  try {
    await mongoose.connect(DB_URI);
    console.log(`✅ Connected to MongoDB Atlas`);

    // Ensure default admin exists
    await User.ensureDefaultAdmin();

    // Ensure device data exists
    await Device.initializeDevice();

    console.log("✅ Database initialization completed");
  } catch (error) {
    console.error("MongoDB Atlas Connection Error:", error);
    process.exit(1);
  }
};

export default connectToDatabase;
