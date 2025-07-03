import mongoose from "mongoose";
import bcrypt from "bcryptjs";

const userSchema = new mongoose.Schema(
  {
    phone: {
      type: String,
      required: true,
      unique: true,
      trim: true,
    },
    password: {
      type: String,
      required: true,
      minlength: 6,
    },
    role: {
      type: String,
      enum: ["admin", "parent"],
      default: "parent",
    },
  },
  {
    timestamps: true,
  }
);

// Hash password before saving
userSchema.pre("save", async function (next) {
  if (!this.isModified("password")) return next();

  try {
    const salt = await bcrypt.genSalt(10);
    this.password = await bcrypt.hash(this.password, salt);
    next();
  } catch (error) {
    next(error);
  }
});

// Method to compare password
userSchema.methods.validPassword = async function (password) {
  return await bcrypt.compare(password, this.password);
};

// Ensure default admin exists
userSchema.statics.ensureDefaultAdmin = async function () {
  const adminExists = await this.findOne({ role: "admin" });
  if (!adminExists) {
    await this.create({
      phone: "1234567890",
      password: "admin123",
      role: "admin",
    });
    console.log(
      "✅ Default admin user created: phone: 1234567890, password: admin123"
    );
  }
};

const User = mongoose.model("User", userSchema);

export default User;
