import Attendance from "../models/attendance.model.js";
import Student from "../models/student.model.js";
import { attendanceSchema } from "../validators/validator.js";

// Create attendance record (from ESP32)
export const createAttendance = async (req, res, next) => {
  try {
    const validatedData = attendanceSchema.parse(req.body);

    // Check if student exists
    const student = await Student.findById(validatedData.student);
    if (!student) {
      return res
        .status(400)
        .json({ success: false, message: "Student not found" });
    }

    // Check if attendance record already exists for this student, date, and type
    const existingAttendance = await Attendance.findOne({
      student: validatedData.student,
      date: validatedData.date || new Date(),
      type: validatedData.type,
    });

    if (existingAttendance) {
      return res.status(400).json({
        success: false,
        message: `Attendance record for ${validatedData.type} already exists for this student on this date`,
      });
    }

    const attendance = await Attendance.create(validatedData);
    const attendanceWithStudent = await Attendance.findById(
      attendance._id
    ).populate("student", "name fingerprintId");

    res.status(201).json({ success: true, data: attendanceWithStudent });
  } catch (error) {
    next(error);
  }
};

// Get all attendance records (admin only)
export const getAllAttendance = async (req, res, next) => {
  try {
    const {
      page = 1,
      limit = 50,
      date,
      startDate,
      endDate,
      student,
      type,
    } = req.query;
    const skip = (page - 1) * limit;

    // Build filter
    const filter = {};

    // Single date filter
    if (date) {
      const filterDate = new Date(date);
      filterDate.setHours(0, 0, 0, 0);
      const nextDate = new Date(filterDate);
      nextDate.setDate(nextDate.getDate() + 1);

      filter.date = {
        $gte: filterDate,
        $lt: nextDate,
      };
    }

    // Date range filter
    if (startDate && endDate) {
      const start = new Date(startDate);
      start.setHours(0, 0, 0, 0);
      const end = new Date(endDate);
      end.setHours(23, 59, 59, 999);

      filter.date = {
        $gte: start,
        $lte: end,
      };
    }

    if (student) filter.student = student;
    if (type) filter.type = type;

    const attendance = await Attendance.find(filter)
      .populate("student", "name fingerprintId parent")
      .populate("student.parent", "phone")
      .sort({ date: -1, time: -1 })
      .skip(skip)
      .limit(parseInt(limit));

    const total = await Attendance.countDocuments(filter);

    res.json({
      success: true,
      data: attendance,
      pagination: {
        currentPage: parseInt(page),
        totalPages: Math.ceil(total / limit),
        totalItems: total,
        itemsPerPage: parseInt(limit),
      },
    });
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

// Get attendance by student ID
export const getAttendanceByStudent = async (req, res, next) => {
  try {
    const { studentId } = req.params;
    const { page = 1, limit = 50, date, startDate, endDate, type } = req.query;
    const skip = (page - 1) * limit;

    // Check if student exists
    const student = await Student.findById(studentId);
    if (!student) {
      return res
        .status(404)
        .json({ success: false, message: "Student not found" });
    }

    // Build filter
    const filter = { student: studentId };

    // Single date filter
    if (date) {
      const filterDate = new Date(date);
      filterDate.setHours(0, 0, 0, 0);
      const nextDate = new Date(filterDate);
      nextDate.setDate(nextDate.getDate() + 1);

      filter.date = {
        $gte: filterDate,
        $lt: nextDate,
      };
    }

    // Date range filter
    if (startDate && endDate) {
      const start = new Date(startDate);
      start.setHours(0, 0, 0, 0);
      const end = new Date(endDate);
      end.setHours(23, 59, 59, 999);

      filter.date = {
        $gte: start,
        $lte: end,
      };
    }

    if (type) filter.type = type;

    const attendance = await Attendance.find(filter)
      .populate("student", "name fingerprintId")
      .sort({ date: -1, time: -1 })
      .skip(skip)
      .limit(parseInt(limit));

    const total = await Attendance.countDocuments(filter);

    res.json({
      success: true,
      data: attendance,
      pagination: {
        currentPage: parseInt(page),
        totalPages: Math.ceil(total / limit),
        totalItems: total,
        itemsPerPage: parseInt(limit),
      },
    });
  } catch (error) {
    next(error);
  }
};

// Get today's attendance summary
export const getTodayAttendance = async (req, res, next) => {
  try {
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);

    const attendance = await Attendance.find({
      date: {
        $gte: today,
        $lt: tomorrow,
      },
    })
      .populate("student", "name fingerprintId parent")
      .populate("student.parent", "phone")
      .sort({ time: 1 });

    // Group by student
    const studentAttendance = {};
    attendance.forEach((record) => {
      const studentId = record.student._id.toString();
      if (!studentAttendance[studentId]) {
        studentAttendance[studentId] = {
          student: record.student,
          enter: null,
          leave: null,
        };
      }
      studentAttendance[studentId][record.type] = record;
    });

    res.json({
      success: true,
      data: Object.values(studentAttendance),
    });
  } catch (error) {
    next(error);
  }
};
