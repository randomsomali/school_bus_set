import { config } from "dotenv";

// Load environment variables
config();

// Environment variables
export const { PORT, DB_URI, JWT_SECRET } = process.env;
