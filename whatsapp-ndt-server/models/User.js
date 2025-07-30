const mongoose = require("mongoose")

const userSchema = new mongoose.Schema(
  {
    email: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
    },
    name: {
      type: String,
      default: "Người dùng mới",
      trim: true,
    },
    status: {
      type: String,
      default: "Hey there! I am using WhatsApp NDT.",
      trim: true,
    },
    profilePictureUrl: {
      type: String,
      default: "/uploads/default-user.png", // Updated to local path
    },
    lastMessageAt: {
      type: Date,
      default: Date.now,
    },
    lastMessageContent: {
      type: String,
      default: "",
      trim: true,
    },
    verified: {
      type: Boolean,
      default: false,
    },
    lastLogin: {
      type: Date,
      default: Date.now,
    },
  },
  {
    timestamps: true,
  },
)

module.exports = mongoose.model("User", userSchema)
