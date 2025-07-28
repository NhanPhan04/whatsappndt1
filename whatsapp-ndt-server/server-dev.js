const express = require("express")
const cors = require("cors")
const nodemailer = require("nodemailer")
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

// In-memory storage for development (replaces MongoDB)
const users = new Map() // email -> user object
const messages = new Map() // messageId -> message object
const statuses = new Map() // statusId -> status object
const calls = new Map() // callId -> call object
const groupChats = new Map() // groupId -> group object
let messageIdCounter = 1
let statusIdCounter = 1
let callIdCounter = 1
let groupIdCounter = 1
let userIdCounter = 1

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

console.log("✅ Development server using in-memory storage (no MongoDB required)")

// Lưu OTP tạm thời
const otpStorage = new Map()
// Lưu trữ người dùng đang hoạt động (email -> socket.id, userId)
const activeUsers = new Map() // email -> { socketId: string, userId: string }

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
  return jwt.sign({ email, userId }, process.env.JWT_SECRET || "dev-secret", { expiresIn: "30d" })
}

// Middleware để xác thực JWT
async function verifyToken(req, res, next) {
  const token = req.headers.authorization?.split(" ")[1]
  if (!token) {
    return res.status(401).json({ success: false, message: "Token không được cung cấp" })
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET || "dev-secret")
    req.user = decoded // decoded sẽ chứa email và userId
    // Lấy thông tin user từ in-memory storage
    const user = users.get(decoded.email)
    if (!user) {
      return res.status(401).json({ success: false, message: "Người dùng không tồn tại" })
    }
    req.user.dbUser = user // Lưu đối tượng user vào req
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

    otpStorage.set(email, {
      otp: otp,
      expiresAt: Date.now() + 5 * 60 * 1000,
      attempts: 0,
    })

    console.log(`🔐 Generated OTP: ${otp} for ${email}`)

    if (!transporter) {
      console.log("📧 Using test OTP mode (no email sent)")
      return res.json({ 
        success: true, 
        message: "Test OTP generated (email service not configured)", 
        testOtp: otp 
      })
    }

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
      res.json({ 
        success: true, 
        message: "Test OTP generated (email failed to send)", 
        testOtp: otp 
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

    let user = users.get(email)

    if (!user) {
      user = {
        _id: `user_${userIdCounter++}`,
        email: email,
        verified: true,
        createdAt: new Date(),
        lastLogin: new Date(),
        name: "",
        status: "Hey there! I am using WhatsApp NDT.",
        profilePictureUrl: ""
      }
      users.set(email, user)
      console.log(`✅ New user registered: ${email}`)
    } else {
      user.lastLogin = new Date()
      user.verified = true
      console.log(`✅ User logged in: ${email}`)
    }

    const token = generateToken(user.email, user._id)

    res.json({
      success: true,
      message: "Xác thực thành công!",
      token: token,
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
    const user = req.user.dbUser
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
    const user = req.user.dbUser

    if (name !== undefined) user.name = name
    if (status !== undefined) user.status = status
    if (profilePictureUrl !== undefined) user.profilePictureUrl = profilePictureUrl

    users.set(user.email, user)

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

// API lấy danh sách tất cả người dùng
app.get("/api/users", verifyToken, async (req, res) => {
  try {
    const currentUserId = req.user.userId
    const allUsers = Array.from(users.values()).filter(u => u._id !== currentUserId)

    res.json({
      success: true,
      users: allUsers.map(u => ({
        _id: u._id,
        email: u.email,
        name: u.name,
        status: u.status,
        profilePictureUrl: u.profilePictureUrl
      })),
      currentPage: 1,
      totalPages: 1,
      totalUsers: allUsers.length,
    })
  } catch (error) {
    console.error("❌ Get Users Error:", error)
    res.status(500).json({ success: false, message: "Lỗi khi lấy danh sách người dùng" })
  }
})

// API upload file
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

// Basic messaging endpoints (simplified for development)
app.get("/api/messages/:chatId", verifyToken, async (req, res) => {
  const chatMessages = Array.from(messages.values()).filter(m => 
    (m.receiver === req.params.chatId && m.sender === req.user.userId) ||
    (m.sender === req.params.chatId && m.receiver === req.user.userId) ||
    m.group === req.params.chatId
  ).sort((a, b) => new Date(a.createdAt) - new Date(b.createdAt))

  res.json({
    success: true,
    messages: chatMessages,
    currentPage: 1,
    totalPages: 1,
    totalMessages: chatMessages.length,
  })
})

// Health check
app.get("/api/health", (req, res) => {
  res.json({
    status: "OK",
    message: "Development server running!",
    timestamp: new Date().toISOString(),
    emailService: {
      initialized: !!transporter,
      user: process.env.EMAIL_USER,
    },
    database: {
      connected: true,
      type: "in-memory-dev",
    },
    activeOTPs: otpStorage.size,
    activeSocketUsers: activeUsers.size,
    totalUsers: users.size,
  })
})

// Socket.IO for real-time chat (simplified)
io.on("connection", (socket) => {
  console.log("🔌 User connected:", socket.id)

  socket.on("signin", (userEmail) => {
    const user = users.get(userEmail)
    if (user) {
      socket.userEmail = userEmail
      socket.userId = user._id
      activeUsers.set(userEmail, { socketId: socket.id, userId: socket.userId })
      console.log(`👤 User ${userEmail} (ID: ${socket.userId}) signed in with socket ID: ${socket.id}`)
      io.emit("user_status_update", { email: userEmail, isOnline: true })
    }
  })

  socket.on("message", (data) => {
    const { message, sourceEmail, targetEmail, type = "text", contentUrl } = data
    console.log(`💬 Message from ${sourceEmail} to ${targetEmail} (Type: ${type}): ${message}`)

    const newMessage = {
      _id: `msg_${messageIdCounter++}`,
      sender: socket.userId,
      receiver: targetEmail ? Array.from(users.values()).find(u => u.email === targetEmail)?._id : null,
      content: message,
      type: type,
      contentUrl: contentUrl,
      status: "sent",
      createdAt: new Date(),
    }
    
    messages.set(newMessage._id, newMessage)

    const targetSocketInfo = activeUsers.get(targetEmail)
    if (targetSocketInfo && targetSocketInfo.socketId) {
      io.to(targetSocketInfo.socketId).emit("message", {
        ...newMessage,
        sourceEmail,
        targetEmail,
        timestamp: newMessage.createdAt.toISOString(),
      })
      newMessage.status = "delivered"
    }

    // Send back to sender
    io.to(socket.id).emit("message", {
      ...newMessage,
      sourceEmail,
      targetEmail,
      timestamp: newMessage.createdAt.toISOString(),
      isSent: true
    })
  })

  socket.on("disconnect", () => {
    if (socket.userEmail) {
      activeUsers.delete(socket.userEmail)
      console.log(`👋 User ${socket.userEmail} disconnected`)
      io.emit("user_status_update", { email: socket.userEmail, isOnline: false })
    }
  })
})

const PORT = process.env.PORT || 3000
server.listen(PORT, () => {
  console.log(`🚀 WhatsApp NDT Development Server running at: http://localhost:${PORT}`)
  console.log(`📱 Health check: http://localhost:${PORT}/api/health`)
  console.log(`📂 Uploads directory: ${uploadsDir}`)
  console.log(`💬 Socket.IO ready for real-time chat`)
  console.log(`📊 Database: In-memory storage (development mode)`)
  console.log(``)
})
