const mongoose = require("mongoose")
require("dotenv").config() // Đảm bảo load .env cho MONGODB_URI

// Import model User
const User = require("../models/User")

async function fixUserStatus() {
  try {
    await mongoose.connect(process.env.MONGODB_URI, {
      useNewUrlParser: true,
      useUnifiedTopology: true,
    })
    console.log("✅ MongoDB đã kết nối thành công để sửa trạng thái người dùng.")

    // Tìm các người dùng mà trường 'status' không phải là chuỗi (tức là nó là một đối tượng)
    const usersWithInvalidStatus = await User.find({
      status: { $type: "object" }, // Sử dụng $type của MongoDB để tìm các trường là đối tượng
    })

    if (usersWithInvalidStatus.length === 0) {
      console.log("🎉 Không tìm thấy người dùng nào có trường 'status' không hợp lệ (kiểu đối tượng).")
      return
    }

    console.log(`Tìm thấy ${usersWithInvalidStatus.length} người dùng có trường 'status' không hợp lệ.`)

    for (const user of usersWithInvalidStatus) {
      console.log(`Đang cố gắng sửa người dùng: ${user.email} (ID: ${user._id}), trạng thái hiện tại:`, user.status)
      // Đặt trạng thái về giá trị chuỗi mặc định theo schema của bạn
      user.status = "Hey there! I am using WhatsApp NDT."
      await user.save()
      console.log(`✅ Đã sửa trạng thái cho người dùng: ${user.email}. Trạng thái mới: "${user.status}"`)
    }

    console.log("✨ Script sửa trạng thái người dùng đã hoàn tất.")
  } catch (error) {
    console.error("❌ Lỗi trong quá trình chạy script sửa trạng thái người dùng:", error)
  } finally {
    await mongoose.disconnect()
    console.log("🔌 Đã ngắt kết nối MongoDB.")
  }
}

fixUserStatus()
