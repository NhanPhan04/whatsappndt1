const mongoose = require("mongoose")

const groupChatSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: true,
      trim: true,
    },
    description: {
      type: String,
      default: "",
      trim: true,
    },
    profilePictureUrl: {
      type: String,
      default: "/uploads/default-group.png", // Default group image
    },
    members: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref: "User",
        required: true,
      },
    ],
    admin: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref: "User",
        required: true,
      },
    ],
    lastMessageAt: {
      type: Date,
      default: Date.now,
    },
    lastMessageContent: {
      type: String,
      default: "",
      trim: true,
    },
  },
  {
    timestamps: true, // Adds createdAt and updatedAt
  },
)

module.exports = mongoose.model("GroupChat", groupChatSchema)
