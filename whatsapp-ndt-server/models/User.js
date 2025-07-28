const mongoose = require("mongoose")

const userSchema = new mongoose.Schema({
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
    // THÊM TRƯỜNG NÀY
    type: String,
    default: "", // URL mặc định hoặc rỗng
  },
  verified: {
    type: Boolean,
    default: false,
  },
  createdAt: {
    type: Date,
    default: Date.now,
  },
  lastLogin: {
    type: Date,
    default: Date.now,
  },
})

module.exports = mongoose.model("User", userSchema)
