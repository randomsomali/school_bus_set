import express from "express";
import {
  getAllUsers,
  getUserById,
  createUser,
  updateUser,
  deleteUser,
} from "../controllers/userController.js";
import { authenticate, restrictTo } from "../middlewares/authmiddleware.js";
import {
  validate,
  validatePartial,
} from "../middlewares/validationMiddleware.js";
import { userSchema } from "../validators/validator.js";

const router = express.Router();

// Protected routes
router.use(authenticate);

// Admin-only routes
router
  .route("/")
  .get(restrictTo("admin"), getAllUsers)
  .post(restrictTo("admin"), validate(userSchema), createUser);

router
  .route("/:id")
  .get(restrictTo("admin"), getUserById)
  .put(restrictTo("admin"), validatePartial(userSchema), updateUser)
  .delete(restrictTo("admin"), deleteUser);

export default router;
