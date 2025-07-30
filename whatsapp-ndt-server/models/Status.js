const mongoose = require("mongoose")

const statusSchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    type: {
      type: String,
      enum: ["text", "image", "video"], // Loại trạng thái
      required: true,
    },
    content: {
      type: String, // Nội dung văn bản cho trạng thái text
      default: "",
      required: function () {
        return this.type === "text"
      },
    },
    mediaUrl: {
      type: String, // URL cho ảnh hoặc video
      default: "",
      required: function () {
        return this.type === "image" || this.type === "video"
      },
    },
    viewedBy: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref: "User",
      },
    ], // Danh sách người đã xem trạng thái
    expiresAt: {
      type: Date,
      required: true,
    }, // Thời gian hết hạn của trạng thái (ví dụ: 24 giờ)
  },
  {
    timestamps: true,
  },
)

// Index để tự động xóa trạng thái hết hạn
statusSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 })

module.exports = mongoose.model("Status", statusSchema)
