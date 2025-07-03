import { ZodError } from "zod";
import { ValidationError, UniqueConstraintError } from "sequelize";

// Global error handler middleware
const errorMiddleware = (err, req, res, next) => {
  console.error("Error:", err);

  // Handle Zod validation errors
  if (err instanceof ZodError) {
    const errors = err.errors
      .map((e) => `${e.path.join(".")}: ${e.message}`)
      .join(", ");
    return res.status(400).json({
      success: false,
      message: "Validation error",
      errors: errors,
    });
  }

  // Handle Sequelize validation errors
  if (err instanceof ValidationError || err instanceof UniqueConstraintError) {
    const errors = err.errors.map((e) => e.message).join(", ");
    return res.status(400).json({
      success: false,
      message: "Validation error",
      errors: errors,
    });
  }

  // Handle JWT errors
  if (err.name === "JsonWebTokenError" || err.name === "TokenExpiredError") {
    return res.status(401).json({
      success: false,
      message:
        err.name === "TokenExpiredError"
          ? "Token has expired"
          : "Invalid token",
    });
  }

  // Handle custom API errors
  if (err.isOperational) {
    return res.status(err.statusCode || 400).json({
      success: false,
      message: err.message,
    });
  }

  // Handle unexpected errors
  console.error("Unexpected error:", err);
  res.status(500).json({
    success: false,
    message: "Internal server error",
  });
};

export default errorMiddleware;
