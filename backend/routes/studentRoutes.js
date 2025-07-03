import express from "express";
import {
  getAllStudents,
  getStudentById,
  createStudent,
  updateStudent,
  deleteStudent,
  getStudentsByParent,
} from "../controllers/studentController.js";
import { authenticate, restrictTo } from "../middlewares/authmiddleware.js";
import {
  validate,
  validatePartial,
} from "../middlewares/validationMiddleware.js";
import { studentSchema } from "../validators/validator.js";

const router = express.Router();

// Protected routes
router.use(authenticate);

// Admin-only routes
router
  .route("/")
  .get(restrictTo("admin"), getAllStudents)
  .post(restrictTo("admin"), validate(studentSchema), createStudent);

router
  .route("/:id")
  .get(restrictTo("admin"), getStudentById)
  .put(restrictTo("admin"), validatePartial(studentSchema), updateStudent)
  .delete(restrictTo("admin"), deleteStudent);

// Parent routes (parents can view their own students)
router.get("/parent/:parentId", getStudentsByParent);

export default router;
