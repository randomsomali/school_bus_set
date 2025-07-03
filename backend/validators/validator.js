import { z } from "zod";

// User Schema
export const userSchema = z.object({
  phone: z
    .string()
    .min(10, "Phone number must be at least 10 characters")
    .max(15, "Phone number cannot exceed 15 characters"),
  password: z
    .string()
    .min(6, "Password must be at least 6 characters")
    .max(100, "Password cannot exceed 100 characters"),
  role: z.enum(["admin", "parent"]).default("parent"),
});

// Login Schema
export const loginSchema = z.object({
  phone: z
    .string()
    .min(10, "Phone number must be at least 10 characters")
    .max(15, "Phone number cannot exceed 15 characters"),
  password: z
    .string()
    .min(6, "Password must be at least 6 characters")
    .max(100, "Password cannot exceed 100 characters"),
});

// Student Schema (fingerprintId is generated automatically)
export const studentSchema = z.object({
  name: z
    .string()
    .min(2, "Name must be at least 2 characters")
    .max(255, "Name cannot exceed 255 characters"),
  parent: z.string().min(1, "Parent ID is required"),
});

// Attendance Schema
export const attendanceSchema = z.object({
  date: z.string().optional(),
  time: z.string().min(1, "Time is required"),
  type: z.enum(["enter", "leave"]),
  student: z.string().min(1, "Student ID is required"),
});

// Device Schema
export const deviceSchema = z.object({
  temperature: z.number().min(-50).max(100),
  humidity: z.number().min(0).max(100),
  gasSensor: z.number().min(0).max(1),
  latitude: z.number().min(-90).max(90),
  longitude: z.number().min(-180).max(180),
});
