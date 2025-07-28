const express = require("express")
const cors = require("cors")
const nodemailer = require("nodemailer")
const mongoose = require("mongoose")
const jwt = require("jsonwebtoken")
const { Server } = require("socket.io")
const http = require("http")
const multer = require("multer")
const path = require("path")
const fs = require("fs")
require("dotenv").config()

const app = express()
const server = http.createServer(app)
const io = new Server(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"],
  },
  maxHttpBufferSize: 1e8, // 100 MB
})

app.use(cors())
app.use(express.json())
app.use("/uploads", express.static(path.join(__dirname, "uploads")))

// Import Models
const User = require("./models/User")
const Message = require("./models/Message")
const Status = require("./models/Status")
const Call = require("./models/Call")
const GroupChat = require("./models/GroupChat") // THÊM DÒNG NÀY

// Cấu hình Nodemailer
let transporter
try {
  transporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST || "smtp.gmail.com",
    port: Number.parseInt(process.env.SMTP_PORT || "587"),
    secure: process.env.SMTP_PORT === "465",
    auth: {
      user: process.env.EMAIL_USER,
      pass: process.env.EMAIL_PASS,
    },
  })
  console.log("✅ Nodemailer transporter initialized successfully")
  console.log("📧 Email User:", process.env.EMAIL_USER)
} catch (error) {
  console.error("❌ Nodemailer initialization failed:", error)
}

// Kết nối MongoDB
mongoose
  .connect(process.env.MONGODB_URI, {
    useNewUrlParser: true,
    useUnifiedTopology: true,
  })
  .then(() => console.log("✅ MongoDB connected successfully"))
  .catch((err) => console.error("❌ MongoDB connection error:", err))

// Lưu OTP tạm thời
const otpStorage = new Map()
// Lưu trữ người dùng đang hoạt động (email -> socket.id, userId)
const activeUsers = new Map() // email -> { socketId: string, userId: ObjectId }

// Tạo thư mục uploads nếu chưa có
const uploadsDir = path.join(__dirname, "uploads")
if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir)
}

// Cấu hình Multer cho upload file
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, uploadsDir)
  },
  filename: (req, file, cb) => {
    cb(null, `${Date.now()}-${file.originalname}`)
  },
})
const upload = multer({ storage: storage })

// Tạo OTP 6 số
function generateOTP() {
  return Math.floor(100000 + Math.random() * 900000).toString()
}

// Generate JWT Token
function generateToken(email, userId) {
  return jwt.sign({ email, userId }, process.env.JWT_SECRET, { expiresIn: "30d" })
}

// Middleware để xác thực JWT
async function verifyToken(req, res, next) {
  const token = req.headers.authorization?.split(" ")[1]
  if (!token) {
    return res.status(401).json({ success: false, message: "Token không được cung cấp" })
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET)
    req.user = decoded // decoded sẽ chứa email và userId
    // Lấy thông tin user đầy đủ từ DB để đảm bảo user tồn tại và có _id
    const user = await User.findById(req.user.userId)
    if (!user) {
      return res.status(401).json({ success: false, message: "Người dùng không tồn tại" })
    }
    req.user.dbUser = user // Lưu đối tượng user từ DB vào req
    next()
  } catch (error) {
    return res.status(401).json({ success: false, message: "Token không hợp lệ" })
  }
}

// API gửi OTP qua Email
app.post("/api/send-otp", async (req, res) => {
  try {
    const { email } = req.body

    if (!email) {
      return res.status(400).json({
        success: false,
        message: "Email là bắt buộc",
      })
    }

    if (!email.includes("@") || !email.includes(".")) {
      return res.status(400).json({
        success: false,
        message: "Địa chỉ email không hợp lệ",
      })
    }

    const otp = generateOTP()

    if (!transporter) {
      console.error("❌ Nodemailer transporter not initialized")
      return res.status(500).json({
        success: false,
        message: "Dịch vụ gửi email chưa sẵn sàng. Vui lòng thử Test OTP.",
      })
    }

    otpStorage.set(email, {
      otp: otp,
      expiresAt: Date.now() + 5 * 60 * 1000,
      attempts: 0,
    })

    console.log(`🔐 Generated OTP: ${otp} for ${email}`)

    try {
      await transporter.sendMail({
        from: process.env.EMAIL_USER,
        to: email,
        subject: "Mã xác thực WhatsApp NDT của bạn",
        html: `
          <div style="font-family: Arial, sans-serif; line-height: 1.6;">
            <h2>Mã xác thực WhatsApp NDT của bạn</h2>
            <p>Mã OTP của bạn là: <strong>${otp}</strong></p>
            <p>Mã này có hiệu lực trong 5 phút.</p>
            <p>Nếu bạn không yêu cầu mã này, vui lòng bỏ qua email này.</p>
            <p>Trân trọng,</p>
            <p>Đội ngũ WhatsApp NDT</p>
          </div>
        `,
      })

      console.log(`✅ OTP email sent successfully to: ${email}`)
      res.json({ success: true, message: "OTP đã được gửi đến email của bạn!" })
    } catch (emailError) {
      console.error("❌ Email sending error:", emailError)
      otpStorage.delete(email)
      res.status(500).json({
        success: false,
        message: "Không thể gửi email OTP. Vui lòng kiểm tra email và thử lại.",
        error: emailError.message,
        suggestion: "Kiểm tra cấu hình EMAIL_USER/EMAIL_PASS trong .env hoặc thử Test OTP.",
      })
    }
  } catch (error) {
    console.error("❌ General Error:", error)
    res.status(500).json({
      success: false,
      message: "Lỗi server: " + error.message,
    })
  }
})

// API xác thực OTP
app.post("/api/verify-otp", async (req, res) => {
  try {
    const { email, otp } = req.body

    if (!email || !otp) {
      return res.status(400).json({
        success: false,
        message: "Thiếu thông tin cần thiết",
      })
    }

    const stored = otpStorage.get(email)

    if (!stored) {
      return res.status(400).json({ success: false, message: "OTP không tồn tại hoặc đã hết hạn" })
    }

    if (Date.now() > stored.expiresAt) {
      otpStorage.delete(email)
      return res.status(400).json({ success: false, message: "OTP đã hết hạn" })
    }

    if (stored.otp !== otp) {
      stored.attempts++
      if (stored.attempts >= 3) {
        otpStorage.delete(email)
        return res.status(400).json({ success: false, message: "Quá số lần thử" })
      }
      return res.status(400).json({ success: false, message: "OTP không chính xác" })
    }

    otpStorage.delete(email)

    let user = await User.findOne({ email: email })

    if (!user) {
      user = new User({ email: email, verified: true })
      await user.save()
      console.log(`✅ New user registered: ${email}`)
    } else {
      user.lastLogin = new Date()
      user.verified = true
      await user.save()
      console.log(`✅ User logged in: ${email}`)
    }

    const token = generateToken(user.email, user._id) // Truyền userId vào token

    res.json({
      success: true,
      message: "Xác thực thành công!",
      token: token,
      user: {
        _id: user._id, // Trả về _id của user
        email: user.email,
        name: user.name,
        status: user.status,
        profilePictureUrl: user.profilePictureUrl,
        createdAt: user.createdAt,
        lastLogin: user.lastLogin,
      },
    })
  } catch (error) {
    console.error("❌ Verify OTP Error:", error)
    res.status(500).json({ success: false, message: "Lỗi xác thực: " + error.message })
  }
})

// Test OTP (không gửi email thật)
app.post("/api/test-otp", (req, res) => {
  try {
    const { email } = req.body

    if (!email) {
      return res.status(400).json({
        success: false,
        message: "Email là bắt buộc",
      })
    }

    const testOtp = "123456"

    otpStorage.set(email, {
      otp: testOtp,
      expiresAt: Date.now() + 5 * 60 * 1000,
      attempts: 0,
    })

    console.log(`🧪 Test OTP: ${testOtp} for ${email}`)
    res.json({ success: true, message: "Test OTP tạo thành công", testOtp, email })
  } catch (error) {
    res.status(500).json({ success: false, message: "Lỗi tạo test OTP" })
  }
})

// API lấy thông tin profile (cần token)
app.get("/api/profile", verifyToken, async (req, res) => {
  try {
    const user = req.user.dbUser // Lấy user từ middleware
    res.json({
      success: true,
      user: {
        _id: user._id,
        email: user.email,
        name: user.name,
        status: user.status,
        profilePictureUrl: user.profilePictureUrl,
        createdAt: user.createdAt,
        lastLogin: user.lastLogin,
      },
    })
  } catch (error) {
    console.error("❌ Get Profile Error:", error)
    res.status(500).json({ success: false, message: "Lỗi khi lấy thông tin hồ sơ" })
  }
})

// API cập nhật profile (cần token)
app.post("/api/profile/update", verifyToken, async (req, res) => {
  try {
    const { name, status, profilePictureUrl } = req.body
    const user = req.user.dbUser // Lấy user từ middleware

    if (name !== undefined) user.name = name
    if (status !== undefined) user.status = status
    if (profilePictureUrl !== undefined) user.profilePictureUrl = profilePictureUrl

    await user.save()

    res.json({
      success: true,
      message: "Cập nhật hồ sơ thành công",
      user: {
        _id: user._id,
        email: user.email,
        name: user.name,
        status: user.status,
        profilePictureUrl: user.profilePictureUrl,
        createdAt: user.createdAt,
        lastLogin: user.lastLogin,
      },
    })
  } catch (error) {
    console.error("❌ Update Profile Error:", error)
    res.status(500).json({ success: false, message: "Lỗi khi cập nhật hồ sơ" })
  }
})

// API lấy danh sách tất cả người dùng (có phân trang)
app.get("/api/users", verifyToken, async (req, res) => {
  try {
    const currentUserId = req.user.userId
    const page = Number.parseInt(req.query.page) || 1
    const limit = Number.parseInt(req.query.limit) || 10

    const skip = (page - 1) * limit

    const users = await User.find({ _id: { $ne: currentUserId } })
      .select("email name status profilePictureUrl")
      .skip(skip)
      .limit(limit)

    const totalUsers = await User.countDocuments({ _id: { $ne: currentUserId } })

    res.json({
      success: true,
      users: users,
      currentPage: page,
      totalPages: Math.ceil(totalUsers / limit),
      totalUsers: totalUsers,
    })
  } catch (error) {
    console.error("❌ Get Users Error:", error)
    res.status(500).json({ success: false, message: "Lỗi khi lấy danh sách người dùng" })
  }
})

// API upload file (ảnh, video, tài liệu)
app.post("/api/upload/file", verifyToken, upload.single("file"), (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ success: false, message: "Không có file nào được tải lên." })
    }

    const fileUrl = `${req.protocol}://${req.get("host")}/uploads/${req.file.filename}`
    console.log(`✅ File uploaded: ${fileUrl}`)
    res.json({ success: true, message: "File đã được tải lên thành công", url: fileUrl })
  } catch (error) {
    console.error("❌ File Upload Error:", error)
    res.status(500).json({ success: false, message: "Lỗi khi tải file lên: " + error.message })
  }
})

// --- API cho Tin nhắn (Chat History) ---
app.get("/api/messages/:chatId", verifyToken, async (req, res) => {
  try {
    const currentUserId = req.user.userId
    const chatId = req.params.chatId // Có thể là targetUserId hoặc groupId
    const page = Number.parseInt(req.query.page) || 1
    const limit = Number.parseInt(req.query.limit) || 30

    const skip = (page - 1) * limit

    let messagesQuery
    let totalMessagesQuery

    // Kiểm tra xem chatId có phải là ID của một nhóm không
    const group = await GroupChat.findById(chatId)

    if (group) {
      // Đây là tin nhắn nhóm
      // Đảm bảo người dùng hiện tại là thành viên của nhóm
      if (!group.members.includes(currentUserId)) {
        return res.status(403).json({ success: false, message: "Bạn không phải là thành viên của nhóm này." })
      }

      messagesQuery = Message.find({ group: chatId })
      totalMessagesQuery = Message.countDocuments({ group: chatId })
    } else {
      // Đây là tin nhắn cá nhân
      messagesQuery = Message.find({
        $or: [
          { sender: currentUserId, receiver: chatId },
          { sender: chatId, receiver: currentUserId },
        ],
      })
      totalMessagesQuery = Message.countDocuments({
        $or: [
          { sender: currentUserId, receiver: chatId },
          { sender: chatId, receiver: currentUserId },
        ],
      })
    }

    const messages = await messagesQuery
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit)
      .populate("sender", "email name profilePictureUrl")
      .populate("receiver", "email name profilePictureUrl")
      .populate("group", "name profilePictureUrl") // Populate thông tin nhóm nếu có

    const totalMessages = await totalMessagesQuery

    res.json({
      success: true,
      messages: messages.reverse(),
      currentPage: page,
      totalPages: Math.ceil(totalMessages / limit),
      totalMessages: totalMessages,
    })
  } catch (error) {
    console.error("❌ Get Messages Error:", error)
    res.status(500).json({ success: false, message: "Lỗi khi lấy tin nhắn: " + error.message })
  }
})

// API đánh dấu tin nhắn đã đọc
app.post("/api/messages/read", verifyToken, async (req, res) => {
  try {
    const { messageIds } = req.body
    const readerId = req.user.userId

    if (!messageIds || !Array.isArray(messageIds) || messageIds.length === 0) {
      return res.status(400).json({ success: false, message: "Thiếu ID tin nhắn." })
    }

    await Message.updateMany(
      {
        _id: { $in: messageIds },
        // Đối với tin nhắn cá nhân, người đọc phải là người nhận
        // Đối với tin nhắn nhóm, người đọc phải là thành viên của nhóm
        $or: [{ receiver: readerId }, { "group.members": readerId }], // Cần kiểm tra kỹ hơn cho nhóm
        status: { $ne: "read" },
      },
      {
        $addToSet: { readBy: readerId },
        $set: { status: "read" },
      },
    )

    res.json({ success: true, message: "Đã đánh dấu tin nhắn là đã đọc." })
  } catch (error) {
    console.error("❌ Mark Messages Read Error:", error)
    res.status(500).json({ success: false, message: "Lỗi khi đánh dấu tin nhắn đã đọc: " + error.message })
  }
})

// --- API cho Trạng thái (Status) ---
app.post("/api/status", verifyToken, async (req, res) => {
  try {
    const { type, content, mediaUrl } = req.body
    const userId = req.user.userId

    if (!type || (type === "text" && !content) || (type !== "text" && !mediaUrl)) {
      return res.status(400).json({ success: false, message: "Thiếu thông tin trạng thái." })
    }

    const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000) // Hết hạn sau 24 giờ

    const newStatus = new Status({
      user: userId,
      type,
      content: type === "text" ? content : "",
      mediaUrl: type !== "text" ? mediaUrl : "",
      expiresAt,
    })

    await newStatus.save()
    res.json({ success: true, message: "Đã đăng trạng thái thành công!", status: newStatus })
  } catch (error) {
    console.error("❌ Post Status Error:", error)
    res.status(500).json({ success: false, message: "Lỗi khi đăng trạng thái: " + error.message })
  }
})

app.get("/api/statuses", verifyToken, async (req, res) => {
  try {
    const currentUserId = req.user.userId
    const page = Number.parseInt(req.query.page) || 1
    const limit = Number.parseInt(req.query.limit) || 10

    const skip = (page - 1) * limit

    // Lấy trạng thái của người dùng hiện tại và những người dùng mà họ là bạn bè (đơn giản là tất cả trừ mình)
    const statuses = await Status.find({
      user: { $ne: currentUserId },
      expiresAt: { $gt: new Date() }, // Chỉ lấy trạng thái chưa hết hạn
    })
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit)
      .populate("user", "email name profilePictureUrl") // Lấy thông tin người dùng đăng trạng thái

    const totalStatuses = await Status.countDocuments({
      user: { $ne: currentUserId },
      expiresAt: { $gt: new Date() },
    })

    res.json({
      success: true,
      statuses: statuses,
      currentPage: page,
      totalPages: Math.ceil(totalStatuses / limit),
      totalStatuses: totalStatuses,
    })
  } catch (error) {
    console.error("❌ Get Statuses Error:", error)
    res.status(500).json({ success: false, message: "Lỗi khi lấy trạng thái: " + error.message })
  }
})

app.get("/api/my-statuses", verifyToken, async (req, res) => {
  try {
    const userId = req.user.userId
    const statuses = await Status.find({ user: userId }).sort({ createdAt: -1 })
    res.json({ success: true, statuses: statuses })
  } catch (error) {
    console.error("❌ Get My Statuses Error:", error)
    res.status(500).json({ success: false, message: "Lỗi khi lấy trạng thái của tôi: " + error.message })
  }
})

// --- API cho Cuộc gọi (Call History) ---
app.post("/api/calls/log", verifyToken, async (req, res) => {
  try {
    const { receiverEmail, callType, callStatus, duration } = req.body
    const callerId = req.user.userId

    const receiverUser = await User.findOne({ email: receiverEmail })
    if (!receiverUser) {
      return res.status(404).json({ success: false, message: "Người nhận không tồn tại." })
    }

    const newCall = new Call({
      caller: callerId,
      receiver: receiverUser._id,
      callType,
      callStatus,
      duration: duration || 0,
    })

    await newCall.save()
    res.json({ success: true, message: "Đã ghi lại cuộc gọi.", call: newCall })
  } catch (error) {
    console.error("❌ Log Call Error:", error)
    res.status(500).json({ success: false, message: "Lỗi khi ghi lại cuộc gọi: " + error.message })
  }
})

app.get("/api/calls", verifyToken, async (req, res) => {
  try {
    const userId = req.user.userId
    const page = Number.parseInt(req.query.page) || 1
    const limit = Number.parseInt(req.query.limit) || 10
    const filterType = req.query.type // "incoming", "outgoing", "missed"
    const filterDate = req.query.date // "today", "yesterday", "last7days"

    const skip = (page - 1) * limit
    const query = {
      $or: [{ caller: userId }, { receiver: userId }],
    }

    if (filterType) {
      query.callStatus = filterType
    }

    if (filterDate) {
      const now = new Date()
      let startDate
      let endDate = now

      if (filterDate === "today") {
        startDate = new Date(now.getFullYear(), now.getMonth(), now.getDate())
      } else if (filterDate === "yesterday") {
        startDate = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1)
        endDate = new Date(now.getFullYear(), now.getMonth(), now.getDate())
      } else if (filterDate === "last7days") {
        startDate = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 7)
      }
      query.timestamp = { $gte: startDate, $lt: endDate }
    }

    const calls = await Call.find(query)
      .sort({ timestamp: -1 })
      .skip(skip)
      .limit(limit)
      .populate("caller", "email name profilePictureUrl")
      .populate("receiver", "email name profilePictureUrl")

    const totalCalls = await Call.countDocuments(query)

    res.json({
      success: true,
      calls: calls,
      currentPage: page,
      totalPages: Math.ceil(totalCalls / limit),
      totalCalls: totalCalls,
    })
  } catch (error) {
    console.error("❌ Get Calls Error:", error)
    res.status(500).json({ success: false, message: "Lỗi khi lấy lịch sử cuộc gọi: " + error.message })
  }
})

// --- API cho Nhóm chat (Group Chat) ---
app.post("/api/groups", verifyToken, async (req, res) => {
  try {
    const { name, memberIds, description, profilePictureUrl } = req.body
    const currentUserId = req.user.userId

    if (!name || !memberIds || !Array.isArray(memberIds) || memberIds.length < 1) {
      return res.status(400).json({ success: false, message: "Tên nhóm và ít nhất một thành viên là bắt buộc." })
    }

    // Đảm bảo người tạo nhóm cũng là thành viên và admin
    if (!memberIds.includes(currentUserId.toString())) {
      memberIds.push(currentUserId.toString())
    }

    // Kiểm tra xem tất cả memberIds có hợp lệ không
    const existingUsers = await User.find({ _id: { $in: memberIds } })
    if (existingUsers.length !== memberIds.length) {
      return res.status(400).json({ success: false, message: "Một hoặc nhiều thành viên không tồn tại." })
    }

    const newGroup = new GroupChat({
      name,
      description,
      profilePictureUrl,
      members: memberIds,
      admin: [currentUserId], // Người tạo là admin mặc định
    })

    await newGroup.save()

    // Thông báo cho các thành viên mới về nhóm mới
    memberIds.forEach((memberId) => {
      const memberUser = existingUsers.find((u) => u._id.toString() === memberId)
      if (memberUser) {
        const memberSocketInfo = activeUsers.get(memberUser.email)
        if (memberSocketInfo && memberSocketInfo.socketId) {
          io.to(memberSocketInfo.socketId).emit("new_group_chat", {
            _id: newGroup._id,
            name: newGroup.name,
            profilePictureUrl: newGroup.profilePictureUrl,
            isGroup: true,
            members: newGroup.members,
          })
        }
      }
    })

    res.json({ success: true, message: "Đã tạo nhóm thành công!", group: newGroup })
  } catch (error) {
    console.error("❌ Create Group Error:", error)
    res.status(500).json({ success: false, message: "Lỗi khi tạo nhóm: " + error.message })
  }
})

app.get("/api/groups", verifyToken, async (req, res) => {
  try {
    const currentUserId = req.user.userId
    const page = Number.parseInt(req.query.page) || 1
    const limit = Number.parseInt(req.query.limit) || 10

    const skip = (page - 1) * limit

    const groups = await GroupChat.find({ members: currentUserId })
      .sort({ updatedAt: -1 }) // Sắp xếp theo thời gian cập nhật gần nhất
      .skip(skip)
      .limit(limit)
      .populate("members", "email name profilePictureUrl") // Lấy thông tin thành viên

    const totalGroups = await GroupChat.countDocuments({ members: currentUserId })

    res.json({
      success: true,
      groups: groups,
      currentPage: page,
      totalPages: Math.ceil(totalGroups / limit),
      totalGroups: totalGroups,
    })
  } catch (error) {
    console.error("❌ Get Groups Error:", error)
    res.status(500).json({ success: false, message: "Lỗi khi lấy danh sách nhóm: " + error.message })
  }
})

app.get("/api/groups/:groupId", verifyToken, async (req, res) => {
  try {
    const groupId = req.params.groupId
    const currentUserId = req.user.userId

    const group = await GroupChat.findById(groupId)
      .populate("members", "email name profilePictureUrl")
      .populate("admin", "email name")

    if (!group) {
      return res.status(404).json({ success: false, message: "Không tìm thấy nhóm." })
    }

    // Đảm bảo người dùng hiện tại là thành viên của nhóm
    if (!group.members.some((member) => member._id.toString() === currentUserId.toString())) {
      return res.status(403).json({ success: false, message: "Bạn không phải là thành viên của nhóm này." })
    }

    res.json({ success: true, group: group })
  } catch (error) {
    console.error("❌ Get Group Details Error:", error)
    res.status(500).json({ success: false, message: "Lỗi khi lấy thông tin nhóm: " + error.message })
  }
})

// API xóa tất cả tin nhắn giữa hai người dùng HOẶC trong một nhóm
app.delete("/api/messages/:chatId", verifyToken, async (req, res) => {
  try {
    const currentUserId = req.user.userId
    const chatId = req.params.chatId

    let result
    const group = await GroupChat.findById(chatId)

    if (group) {
      // Xóa tin nhắn nhóm (chỉ admin mới có quyền xóa toàn bộ lịch sử)
      if (!group.admin.includes(currentUserId)) {
        return res.status(403).json({ success: false, message: "Bạn không có quyền xóa lịch sử nhóm này." })
      }
      result = await Message.deleteMany({ group: chatId })
    } else {
      // Xóa tin nhắn cá nhân
      result = await Message.deleteMany({
        $or: [
          { sender: currentUserId, receiver: chatId },
          { sender: chatId, receiver: currentUserId },
        ],
      })
    }

    if (result.deletedCount > 0) {
      res.json({ success: true, message: `Đã xóa ${result.deletedCount} tin nhắn.` })
    } else {
      res.status(404).json({ success: false, message: "Không tìm thấy tin nhắn để xóa." })
    }
  } catch (error) {
    console.error("❌ Delete Messages Error:", error)
    res.status(500).json({ success: false, message: "Lỗi khi xóa tin nhắn: " + error.message })
  }
})

// Socket.IO for real-time chat
io.on("connection", (socket) => {
  console.log("🔌 User connected:", socket.id)

  socket.on("signin", async (userEmail) => {
    const user = await User.findOne({ email: userEmail })
    if (user) {
      socket.userEmail = userEmail
      socket.userId = user._id.toString() // Lưu userId vào socket
      activeUsers.set(userEmail, { socketId: socket.id, userId: socket.userId })
      console.log(`👤 User ${userEmail} (ID: ${socket.userId}) signed in with socket ID: ${socket.id}`)
      io.emit("user_status_update", { email: userEmail, isOnline: true })

      // Tham gia vào các phòng nhóm mà người dùng là thành viên
      const groups = await GroupChat.find({ members: user._id })
      groups.forEach((group) => {
        socket.join(group._id.toString())
        console.log(`👤 User ${userEmail} joined group room: ${group._id}`)
      })
    } else {
      console.log(`🚫 User ${userEmail} not found in DB, cannot sign in socket.`)
    }
  })

  // Handle message sending (bao gồm các loại nội dung khác)
  socket.on("message", async (data) => {
    const { message, sourceEmail, targetEmail, groupId, type = "text", contentUrl } = data

    console.log(
      `💬 Message from ${sourceEmail} to ${targetEmail || groupId} (Type: ${type}): ${message} ${
        contentUrl ? `(URL: ${contentUrl})` : ""
      }`,
    )

    try {
      const senderUser = await User.findOne({ email: sourceEmail })
      if (!senderUser) {
        console.log(`🚫 Sender user ${sourceEmail} not found in DB. Message not saved.`)
        return
      }

      let newMessage
      const recipientSocketIds = []
      const recipientEmails = []

      if (groupId) {
        // Tin nhắn nhóm
        const group = await GroupChat.findById(groupId)
        if (!group) {
          console.log(`🚫 Group ${groupId} not found. Message not saved.`)
          return
        }
        if (!group.members.includes(senderUser._id)) {
          console.log(`🚫 Sender ${sourceEmail} is not a member of group ${groupId}. Message not saved.`)
          return
        }

        newMessage = new Message({
          sender: senderUser._id,
          group: group._id,
          content: message,
          type: type,
          contentUrl: contentUrl,
          status: "sent",
        })
        await newMessage.save()
        console.log(`✅ Group message saved to DB: ${newMessage._id}`)

        // Gửi tin nhắn đến tất cả thành viên trong nhóm (trừ người gửi)
        group.members.forEach((memberId) => {
          if (memberId.toString() !== senderUser._id.toString()) {
            const memberUser = activeUsers.get(memberId.email) // Cần lấy email từ User model
            if (memberUser && memberUser.socketId) {
              recipientSocketIds.push(memberUser.socketId)
              recipientEmails.push(memberUser.email)
            }
          }
        })

        // Populate sender info for the payload
        await newMessage.populate("sender", "email name profilePictureUrl")
        await newMessage.populate("group", "name profilePictureUrl")

        const messagePayload = {
          _id: newMessage._id,
          message: newMessage.content,
          sourceEmail: newMessage.sender.email,
          targetEmail: null, // Không có targetEmail cho nhóm
          groupId: newMessage.group._id,
          groupName: newMessage.group.name,
          groupProfilePictureUrl: newMessage.group.profilePictureUrl,
          type: newMessage.type,
          contentUrl: newMessage.contentUrl,
          timestamp: newMessage.createdAt.toISOString(),
          status: newMessage.status,
          senderName: newMessage.sender.name, // Thêm tên người gửi cho tin nhắn nhóm
        }

        // Emit tin nhắn đến tất cả thành viên online trong nhóm (trừ người gửi)
        io.to(groupId).emit("message", messagePayload)
        console.log(`✅ Group message ${newMessage._id} emitted to group ${groupId}.`)

        // Cập nhật trạng thái tin nhắn thành 'delivered' cho những người online
        // (Logic này phức tạp hơn cho nhóm, có thể cần mảng deliveredTo)
        // Tạm thời, chỉ đánh dấu là delivered nếu có ít nhất 1 người nhận online
        if (recipientSocketIds.length > 0) {
          newMessage.status = "delivered"
          await newMessage.save()
          messagePayload.status = "delivered"
        }
        // Gửi lại cho người gửi để cập nhật UI của họ
        io.to(socket.id).emit("message", { ...messagePayload, isSent: true })
      } else {
        // Tin nhắn cá nhân (logic cũ)
        const receiverUser = await User.findOne({ email: targetEmail })
        if (!receiverUser) {
          console.log(`🚫 Receiver user ${targetEmail} not found in DB. Message not saved.`)
          return
        }

        newMessage = new Message({
          sender: senderUser._id,
          receiver: receiverUser._id,
          content: message,
          type: type,
          contentUrl: contentUrl,
          status: "sent",
        })
        await newMessage.save()
        console.log(`✅ Individual message saved to DB: ${newMessage._id}`)

        const targetSocketInfo = activeUsers.get(targetEmail)
        // Populate sender and receiver info for the payload
        await newMessage.populate("sender", "email name profilePictureUrl")
        await newMessage.populate("receiver", "email name profilePictureUrl")

        const messagePayload = {
          _id: newMessage._id,
          message: newMessage.content,
          sourceEmail: newMessage.sender.email,
          targetEmail: newMessage.receiver.email,
          type: newMessage.type,
          contentUrl: newMessage.contentUrl,
          timestamp: newMessage.createdAt.toISOString(),
          status: newMessage.status,
        }

        if (targetSocketInfo && targetSocketInfo.socketId) {
          io.to(targetSocketInfo.socketId).emit("message", messagePayload)
          newMessage.status = "delivered"
          await newMessage.save()
          messagePayload.status = "delivered"
          console.log(`✅ Message ${newMessage._id} delivered to online user.`)
        } else {
          console.log(`🚫 Target user ${targetEmail} is not online. Message saved to DB as 'sent'.`)
        }
        // Gửi lại cho người gửi để cập nhật UI của họ
        io.to(socket.id).emit("message", { ...messagePayload, isSent: true })
      }
    } catch (error) {
      console.error("❌ Error saving or processing message:", error)
    }
  })

  // Handle message read receipt
  socket.on("message_read", async (messageId) => {
    try {
      const message = await Message.findById(messageId)
      if (!message) return

      // Kiểm tra xem người dùng hiện tại có quyền đánh dấu tin nhắn này là đã đọc không
      let canMarkAsRead = false
      if (message.receiver && message.receiver.toString() === socket.userId) {
        // Tin nhắn cá nhân và người dùng là người nhận
        canMarkAsRead = true
      } else if (message.group) {
        // Tin nhắn nhóm và người dùng là thành viên của nhóm
        const group = await GroupChat.findById(message.group)
        if (group && group.members.includes(socket.userId)) {
          canMarkAsRead = true
        }
      }

      if (canMarkAsRead && message.status !== "read") {
        message.status = "read"
        message.readBy.addToSet(socket.userId)
        await message.save()
        console.log(`✅ Message ${messageId} marked as read by ${socket.userId}`)

        // Thông báo cho người gửi rằng tin nhắn đã được đọc
        const senderUser = await User.findById(message.sender)
        if (senderUser) {
          const senderSocketInfo = activeUsers.get(senderUser.email)
          if (senderSocketInfo && senderSocketInfo.socketId) {
            io.to(senderSocketInfo.socketId).emit("message_status_update", {
              messageId: message._id,
              status: "read",
            })
          }
        }
      }
    } catch (error) {
      console.error("❌ Error marking message as read:", error)
    }
  })

  // Handle typing indicators
  socket.on("typing", (data) => {
    const { targetEmail, groupId, isTyping } = data
    if (groupId) {
      // Typing trong nhóm chat
      socket.to(groupId).emit("typing", {
        userEmail: socket.userEmail,
        groupId: groupId,
        isTyping,
      })
    } else if (targetEmail) {
      // Typing trong chat cá nhân
      const targetSocketInfo = activeUsers.get(targetEmail)
      if (targetSocketInfo && targetSocketInfo.socketId) {
        io.to(targetSocketInfo.socketId).emit("typing", {
          userEmail: socket.userEmail,
          isTyping,
        })
      }
    }
  })

  // Handle disconnect
  socket.on("disconnect", async () => {
    if (socket.userEmail) {
      activeUsers.delete(socket.userEmail)
      console.log(`👋 User ${socket.userEmail} disconnected`)
      io.emit("user_status_update", { email: socket.userEmail, isOnline: false })

      // Rời khỏi tất cả các phòng nhóm
      const groups = await GroupChat.find({ members: socket.userId })
      groups.forEach((group) => {
        socket.leave(group._id.toString())
        console.log(`👤 User ${socket.userEmail} left group room: ${group._id}`)
      })
    }
  })
})

// Health check
app.get("/api/health", (req, res) => {
  res.json({
    status: "OK",
    message: "Server đang chạy!",
    timestamp: new Date().toISOString(),
    emailService: {
      initialized: !!transporter,
      user: process.env.EMAIL_USER,
    },
    database: {
      connected: mongoose.connection.readyState === 1,
      uri: process.env.MONGODB_URI,
    },
    activeOTPs: otpStorage.size,
    activeSocketUsers: activeUsers.size,
  })
})

// Debug endpoint để xem OTP đang lưu
app.get("/api/debug/otps", (req, res) => {
  const otps = Array.from(otpStorage.entries()).map(([email, data]) => ({
    email,
    otp: data.otp,
    expiresIn: Math.max(0, Math.floor((data.expiresAt - Date.now()) / 1000)),
    attempts: data.attempts,
  }))

  res.json({
    count: otps.length,
    otps: otps,
  })
})

// Debug endpoint để xem tất cả người dùng đang lưu
app.get("/api/debug/users", async (req, res) => {
  try {
    const users = await User.find({}).select("email name status profilePictureUrl")
    res.json({
      success: true,
      count: users.length,
      users: users,
    })
  } catch (error) {
    console.error("❌ Debug Get Users Error:", error)
    res.status(500).json({ success: false, message: "Lỗi khi lấy danh sách người dùng debug: " + error.message })
  }
})

const PORT = process.env.PORT || 3000
server.listen(PORT, () => {
  console.log(`🚀 WhatsApp NDT Server chạy tại: http://192.168.2.34:${PORT}`)
  console.log(`📱 Health check: http://192.168.2.34:${PORT}/api/health`)
  console.log(`🔧 Debug OTPs: http://192.168.2.34:${PORT}/api/debug/otps`)
  console.log(`🔧 Debug Users: http://192.168.2.34:${PORT}/api/debug/users`)
  console.log(`📂 Uploads directory: ${uploadsDir}`)
  console.log(`💬 Socket.IO ready for real-time chat`)
  console.log(``)
  })
