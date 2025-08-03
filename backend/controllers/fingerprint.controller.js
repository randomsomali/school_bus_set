import Student from "../models/student.model.js";
import Attendance from "../models/attendance.model.js";

// Store pending commands for ESP32 fingerprint system
let pendingFingerprintCommand = null;

// Helper function to get Somalia time (UTC+3)
const getSomaliaTime = () => {
  return new Date(new Date().toLocaleString("en-US", { timeZone: "Africa/Mogadishu" }));
};

export const pollFingerprintCommand = async (req, res) => {
  try {
    if (pendingFingerprintCommand) {
      const command = { ...pendingFingerprintCommand };
      pendingFingerprintCommand = null; // Clear the command after sending
      return res.json(command);
    }

    return res.json({
      success: false,
      message: "No pending commands",
      code: 0,
    });
  } catch (error) {
    console.error("Error in pollFingerprintCommand:", error);
    res.status(500).json({
      success: false,
      message: "Server error occurred",
      code: 0,
    });
  }
};

export const createFingerprintAttendance = async (req, res, next) => {
  try {
    const { fingerprintId } = req.body;

    if (!fingerprintId) {
      return res.status(400).json({
        success: false,
        message: "Fingerprint ID is required",
      });
    }

    // Find student by fingerprint ID
    const student = await Student.findOne({
      fingerprintId: parseInt(fingerprintId),
    });

    if (!student) {
      return res.status(404).json({
        success: false,
        message: "Student not found with this fingerprint ID",
      });
    }

    // Get current Somalia time (UTC+3)
    const now = getSomaliaTime();
    const hour = now.getHours();
    const type = hour < 12 ? "enter" : "leave";
    const timeString = now.toTimeString().split(" ")[0];

    // Get start and end of today for comparison
    const today = new Date(now);
    today.setHours(0, 0, 0, 0);
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);
    console.log("today", today);
    console.log("tomorrow", tomorrow);
    // Check if attendance record already exists for this student, date, and type
    const existingAttendance = await Attendance.findOne({
      student: student._id,
      date: {
        $gte: today,
        $lt: tomorrow,
      },
      type: type,
    });

    if (existingAttendance) {
      return res.status(400).json({
        success: false,
        message: `Attendance record for ${type} already exists for this student today`,
      });
    }

    // Create attendance record
    const attendance = await Attendance.create({
      student: student._id,
      date: now,
      time: timeString,
      type: type,
    });

    const attendanceWithStudent = await Attendance.findById(
      attendance._id
    ).populate("student", "name fingerprintId");

    console.log(`✅ Fingerprint Attendance Created:`);
    console.log(`   - Student: ${student.name} (ID: ${student.fingerprintId})`);
    console.log(`   - Type: ${type}`);
    console.log(`   - Time: ${timeString}`);
    console.log(`   - Date: ${now.toDateString()}`);

    res.status(201).json({
      success: true,
      message: `Attendance recorded: ${type}`,
      data: attendanceWithStudent,
    });
  } catch (error) {
    console.error("Error in createFingerprintAttendance:", error);
    next(error);
  }
};

// Function to set pending command for ESP32 (called from student controller)
export const setPendingFingerprintCommand = (command) => {
  pendingFingerprintCommand = command;
};

// Function to get the last inserted student's fingerprint ID
export const getLastInsertedStudentFingerprintId = async () => {
  try {
    const lastStudent = await Student.findOne().sort({ createdAt: -1 });
    return lastStudent ? lastStudent.fingerprintId : null;
  } catch (error) {
    console.error("Error getting last inserted student:", error);
    return null;
  }
};
