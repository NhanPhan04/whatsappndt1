const mongoose = require("mongoose")

const callSchema = new mongoose.Schema(
  {
    caller: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    receiver: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    callType: {
      type: String,
      enum: ["audio", "video"],
      required: true,
    },
    callStatus: {
      type: String,
      enum: ["incoming", "outgoing", "missed", "answered", "declined"],
      required: true,
    },
    duration: {
      type: Number, // Thời lượng cuộc gọi bằng giây
      default: 0,
    },
    timestamp: {
      type: Date,
      default: Date.now,
    },
  },
  {
    timestamps: true,
  },
)

module.exports = mongoose.model("Call", callSchema)
