import Student from "../models/student.model.js";
import User from "../models/users.model.js";
import { studentSchema } from "../validators/validator.js";
import { setPendingFingerprintCommand } from "./fingerprint.controller.js";

// Generate unique fingerprint ID between 1-127
const generateFingerprintId = async () => {
  const usedIds = await Student.distinct("fingerprintId");
  for (let id = 1; id <= 127; id++) {
    if (!usedIds.includes(id)) {
      return id;
    }
  }
  throw new Error("No available fingerprint IDs (all 1-127 are in use)");
};

// Get all students (admin only)
export const getAllStudents = async (req, res, next) => {
  try {
    const students = await Student.find()
      .populate("parent", "phone role")
      .sort({ createdAt: -1 });
    res.json({ success: true, data: students });
  } catch (error) {
    next(error);
  }
};

// Get a single student by ID (admin only)
export const getStudentById = async (req, res, next) => {
  try {
    const student = await Student.findById(req.params.id).populate(
      "parent",
      "phone role"
    );
    if (!student) {
      return res
        .status(404)
        .json({ success: false, message: "Student not found" });
    }
    res.json({ success: true, data: student });
  } catch (error) {
    next(error);
  }
};

// Create a new student (admin only)
export const createStudent = async (req, res, next) => {
  try {
    const validatedData = studentSchema.parse(req.body);

    // Check if parent exists
    const parent = await User.findById(validatedData.parent);
    if (!parent) {
      return res
        .status(400)
        .json({ success: false, message: "Parent not found" });
    }

    // Generate unique fingerprint ID
    const fingerprintId = await generateFingerprintId();

    const newStudent = await Student.create({
      ...validatedData,
      fingerprintId,
    });

    const studentWithParent = await Student.findById(newStudent._id).populate(
      "parent",
      "phone role"
    );

    // Set pending command for ESP32 to enroll new fingerprint
    setPendingFingerprintCommand({
      success: true,
      message: "New student created - enroll fingerprint",
      code: 1, // 1 = enroll
      fingerprintId: fingerprintId,
      studentName: validatedData.name,
      studentId: newStudent._id,
    });

    console.log(`✅ New Student Created:`);
    console.log(`   - Name: ${validatedData.name}`);
    console.log(`   - Fingerprint ID: ${fingerprintId}`);
    console.log(`   - Parent: ${parent.phone}`);

    res.status(201).json({ success: true, data: studentWithParent });
  } catch (error) {
    next(error);
  }
};

// Update a student (admin only)
export const updateStudent = async (req, res, next) => {
  try {
    const validatedData = studentSchema.partial().parse(req.body);
    const student = await Student.findById(req.params.id);

    if (!student) {
      return res
        .status(404)
        .json({ success: false, message: "Student not found" });
    }

    // Check if parent exists (if updating parent)
    if (validatedData.parent) {
      const parent = await User.findById(validatedData.parent);
      if (!parent) {
        return res
          .status(400)
          .json({ success: false, message: "Parent not found" });
      }
    }

    Object.assign(student, validatedData);
    await student.save();

    const studentWithParent = await Student.findById(student._id).populate(
      "parent",
      "phone role"
    );
    res.json({ success: true, data: studentWithParent });
  } catch (error) {
    next(error);
  }
};

// Delete a student (admin only)
export const deleteStudent = async (req, res, next) => {
  try {
    const student = await Student.findById(req.params.id);
    if (!student) {
      return res
        .status(404)
        .json({ success: false, message: "Student not found" });
    }

    // Store fingerprint ID before deletion for ESP32 command
    const fingerprintId = student.fingerprintId;
    const studentName = student.name;

    await Student.findByIdAndDelete(req.params.id);

    // Set pending command for ESP32 to delete fingerprint
    setPendingFingerprintCommand({
      success: true,
      message: "Student deleted - remove fingerprint",
      code: 2, // 2 = delete
      fingerprintId: fingerprintId,
      studentName: studentName,
      studentId: req.params.id,
    });

    console.log(`🗑️ Student Deleted:`);
    console.log(`   - Name: ${studentName}`);
    console.log(`   - Fingerprint ID: ${fingerprintId}`);

    res.json({ success: true, message: "Student deleted successfully" });
  } catch (error) {
    next(error);
  }
};

// Get students by parent ID (for parent dashboard)
export const getStudentsByParent = async (req, res, next) => {
  try {
    const parentId = req.params.parentId;
    const students = await Student.find({ parent: parentId }).populate(
      "parent",
      "phone role"
    );
    res.json({ success: true, data: students });
  } catch (error) {
    next(error);
  }
};
