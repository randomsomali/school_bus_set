import connectToDatabase from "../database/mongodb.js";
import User from "../models/users.model.js";
import Student from "../models/student.model.js";
import Attendance from "../models/attendance.model.js";
import Device from "../models/device.model.js";

const seedData = async () => {
  try {
    await connectToDatabase();

    // Clear existing data
    await User.deleteMany({});
    await Student.deleteMany({});
    await Attendance.deleteMany({});
    await Device.deleteMany({});

    console.log("Cleared existing data");

    // Create admin user
    const adminUser = await User.create({
      phone: "1234567890",
      password: "admin123",
      role: "admin",
    });

    // Create parent users
    const parentUsers = await User.insertMany([
      {
        phone: "1111111111",
        password: "parent123",
        role: "parent",
      },
      {
        phone: "2222222222",
        password: "parent123",
        role: "parent",
      },
      {
        phone: "3333333333",
        password: "parent123",
        role: "parent",
      },
      {
        phone: "4444444444",
        password: "parent123",
        role: "parent",
      },
      {
        phone: "5555555555",
        password: "parent123",
        role: "parent",
      },
    ]);

    console.log("Created users");

    // Create students
    const students = await Student.insertMany([
      {
        name: "Ahmed Hassan",
        fingerprintId: 1,
        parent: parentUsers[0]._id,
      },
      {
        name: "Fatima Ali",
        fingerprintId: 2,
        parent: parentUsers[0]._id,
      },
      {
        name: "Mohammed Omar",
        fingerprintId: 3,
        parent: parentUsers[1]._id,
      },
      {
        name: "Aisha Khalil",
        fingerprintId: 4,
        parent: parentUsers[1]._id,
      },
      {
        name: "Omar Ibrahim",
        fingerprintId: 5,
        parent: parentUsers[2]._id,
      },
      {
        name: "Layla Ahmed",
        fingerprintId: 6,
        parent: parentUsers[3]._id,
      },
      {
        name: "Yusuf Hassan",
        fingerprintId: 7,
        parent: parentUsers[4]._id,
      },
    ]);

    console.log("Created students");

    // Create attendance records for today
    const today = new Date();
    const timeSlots = ["08:00", "08:15", "08:30", "08:45", "09:00"];
    const leaveSlots = ["15:00", "15:15", "15:30", "15:45", "16:00"];

    const attendanceRecords = [];

    students.forEach((student, index) => {
      // Enter records
      attendanceRecords.push({
        date: today,
        time: timeSlots[index % timeSlots.length],
        type: "enter",
        student: student._id,
      });

      // Leave records
      attendanceRecords.push({
        date: today,
        time: leaveSlots[index % leaveSlots.length],
        type: "leave",
        student: student._id,
      });
    });

    await Attendance.insertMany(attendanceRecords);
    console.log("Created attendance records");

    // Create device data
    await Device.create({
      temperature: 25.5,
      humidity: 60,
      gasSensor: 0,
      latitude: 24.7136,
      longitude: 46.6753,
    });

    console.log("Created device data");

    console.log("✅ Seed data inserted successfully!");
    console.log(`Admin: phone: 1234567890, password: admin123`);
    console.log(`Parents: phone: 1111111111-5555555555, password: parent123`);

    process.exit(0);
  } catch (error) {
    console.error("Error seeding data:", error);
    process.exit(1);
  }
};

seedData();
