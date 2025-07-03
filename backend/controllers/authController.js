import jwt from "jsonwebtoken";
import { JWT_SECRET } from "../config/env.js";
import User from "../models/users.model.js";

// Generate JWT token
const generateToken = (user) => {
  return jwt.sign(
    {
      user_id: user._id,
      role: user.role,
      type: "user",
    },
    JWT_SECRET,
    { expiresIn: "7d" }
  );
};

// User login (single endpoint for all roles)
export const loginUser = async (req, res, next) => {
  try {
    const { phone, password } = req.validatedData;

    const user = await User.findOne({ phone: phone });
    if (!user) {
      return res
        .status(401)
        .json({ success: false, message: "Invalid phone or password" });
    }

    const isPasswordValid = await user.validPassword(password);
    if (!isPasswordValid) {
      return res
        .status(401)
        .json({ success: false, message: "Invalid phone or password" });
    }

    const token = generateToken(user);
    const userObj = user.toObject();
    delete userObj.password;

    res.json({
      success: true,
      data: {
        user: userObj,
        token,
      },
    });
  } catch (error) {
    next(error);
  }
};
