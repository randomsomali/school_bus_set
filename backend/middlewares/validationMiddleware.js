import { ZodError } from "zod";

// Middleware for validating request data with Zod schemas
export const validate = (schema) => {
  return (req, res, next) => {
    try {
      // Validate request body
      const validatedData = schema.parse(req.body);
      req.validatedData = validatedData; // Attach validated data to request
      next();
    } catch (error) {
      if (error instanceof ZodError) {
        const errors = error.errors
          .map((e) => `${e.path.join(".")}: ${e.message}`)
          .join(", ");
        return res.status(400).json({
          success: false,
          message: "Validation error",
          errors: errors,
        });
      }
      next(error);
    }
  };
};

// Middleware for partial validation (for update operations)
export const validatePartial = (schema) => {
  return (req, res, next) => {
    try {
      // Validate request body (partial)
      const validatedData = schema.partial().parse(req.body);
      req.validatedData = validatedData; // Attach validated data to request
      next();
    } catch (error) {
      if (error instanceof ZodError) {
        const errors = error.errors
          .map((e) => `${e.path.join(".")}: ${e.message}`)
          .join(", ");
        return res.status(400).json({
          success: false,
          message: "Validation error",
          errors: errors,
        });
      }
      next(error);
    }
  };
};
