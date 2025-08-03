import User from "../models/users.model.js";
import { userSchema } from "../validators/validator.js";
import Student from "../models/student.model.js";
import Attendance from "../models/attendance.model.js"; // Make sure this is imported



// Get all users (admin only)
export const getAllUsers = async (req, res, next) => {
  try {
    const users = await User.find({}, "-password").sort({ createdAt: -1 });
    res.json({ success: true, data: users });
  } catch (error) {
    next(error);
  }
};

// Get a single user by ID (admin only)
export const getUserById = async (req, res, next) => {
  try {
    const user = await User.findById(req.params.id).select("-password");
    if (!user) {
      return res
        .status(404)
        .json({ success: false, message: "User not found" });
    }
    res.json({ success: true, data: user });
  } catch (error) {
    next(error);
  }
};

// Create a new user (admin only)
export const createUser = async (req, res, next) => {
  try {
    const validatedData = userSchema.parse(req.body);
    const existingUser = await User.findOne({ phone: validatedData.phone });
    if (existingUser) {
      return res
        .status(400)
        .json({ success: false, message: "Phone already in use" });
    }
    const newUser = await User.create(validatedData);
    const userObj = newUser.toObject();
    delete userObj.password;
    res.status(201).json({ success: true, data: userObj });
  } catch (error) {
    next(error);
  }
};

// Update a user (admin only)
export const updateUser = async (req, res, next) => {
  try {
    const validatedData = userSchema.partial().parse(req.body);
    const user = await User.findById(req.params.id);
    if (!user) {
      return res
        .status(404)
        .json({ success: false, message: "User not found" });
    }
    if (validatedData.phone && validatedData.phone !== user.phone) {
      const existingUser = await User.findOne({ phone: validatedData.phone });
      if (existingUser) {
        return res
          .status(400)
          .json({ success: false, message: "Phone already in use" });
      }
    }
    Object.assign(user, validatedData);
    await user.save();
    const userObj = user.toObject();
    delete userObj.password;
    res.json({ success: true, data: userObj });
  } catch (error) {
    next(error);
  }
};

// Delete a user (admin only)
export const deleteUser = async (req, res, next) => {
  try {
    const user = await User.findById(req.params.id);
    if (!user) {
      return res
        .status(404)
        .json({ success: false, message: "User not found" });
    }

    // Only apply cascading delete if user is a parent
    if (user.role === "parent") {
      // Find all students of this parent
      const students = await Student.find({ parent: user._id });

      // Get their IDs
      const studentIds = students.map((s) => s._id);

      // Delete all attendances for these students
      await Attendance.deleteMany({ student: { $in: studentIds } });

      // Delete all the students
      await Student.deleteMany({ parent: user._id });
    }

    // Delete the user (parent)
    await User.findByIdAndDelete(req.params.id);

    res.json({ success: true, message: "User and related data deleted successfully" });
  } catch (error) {
    next(error);
  }
};
