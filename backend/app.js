import express from "express";
import cors from "cors";
import morgan from "morgan";
import { config } from "dotenv";
import { errorHandler } from "./middlewares/authmiddleware.js";
import { convertRequestDates, formatResponseDates } from "./middlewares/timezoneMiddleware.js";
import routes from "./routes/index.js";
import connectToDatabase from "./database/mongodb.js";

// Load environment variables
config();

const app = express();
const PORT = process.env.PORT;

// Middleware
app.use(
  cors({
    origin: "*",
    methods: ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization"],
    credentials: true,
  })
);
app.use(morgan("dev"));
app.use(express.json());
app.use(express.urlencoded({ extended: false }));

// Timezone middleware
app.use(convertRequestDates);
app.use(formatResponseDates);

// Welcome route
app.get("/", (req, res) => {
  res.json({
    success: true,
    message: "School Bus Fingerprint Management API",
    version: "1.0.0",
  });
});

// API Routes
app.use("/api", routes);

// Global error handler
app.use(errorHandler);

// Handle 404 routes
app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: "Route not found",
  });
});

// Database connection and server startup
const startServer = async () => {
  try {
    await connectToDatabase();

    app.listen(PORT, "0.0.0.0", () => {
      console.log(`Server running on port ${PORT}`);
    });
  } catch (error) {
    console.error("Unable to connect to the database:", error);
    process.exit(1);
  }
};

startServer();

export default app;
