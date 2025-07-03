import express from "express";
import { loginUser } from "../controllers/authController.js";
import { validate } from "../middlewares/validationMiddleware.js";
import { loginSchema } from "../validators/validator.js";

const router = express.Router();

// Public authentication routes
router.post("/login", validate(loginSchema), loginUser);

export default router;
