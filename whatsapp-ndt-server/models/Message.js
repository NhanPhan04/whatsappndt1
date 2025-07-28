const mongoose = require("mongoose")

const messageSchema = new mongoose.Schema(
  {
    sender: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    receiver: {
      // Người nhận cá nhân (nếu không phải nhóm chat)
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: function () {
        return !this.group // Bắt buộc nếu không có group
      },
    },
    group: {
      // Nhóm chat (nếu là nhóm chat)
      type: mongoose.Schema.Types.ObjectId,
      ref: "GroupChat",
      required: function () {
        return !this.receiver // Bắt buộc nếu không có receiver cá nhân
      },
    },
    content: {
      type: String,
      required: true,
    },
    type: {
      type: String,
      enum: ["text", "image", "video", "file", "location"], // Các loại tin nhắn
      default: "text",
    },
    contentUrl: {
      type: String, // URL cho ảnh, video, file, hoặc bản đồ vị trí
      default: "",
    },
    readBy: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref: "User",
      },
    ], // Danh sách người đã đọc (cho nhóm hoặc 1-1)
    status: {
      type: String,
      enum: ["sent", "delivered", "read"],
      default: "sent",
    },
  },
  {
    timestamps: true, // Tự động thêm createdAt và updatedAt
  },
)

module.exports = mongoose.model("Message", messageSchema)
