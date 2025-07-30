const mongoose = require("mongoose")
require("dotenv").config({ path: "../.env" }) // Đảm bảo load .env từ thư mục cha

// Import Models
const User = require("../models/User")
const Message = require("../models/Message")
const Status = require("../models/Status")
const Call = require("../models/Call")
const GroupChat = require("../models/GroupChat") // THÊM DÒNG NÀY

const MONGODB_URI = process.env.MONGODB_URI || "mongodb://localhost:27017/whatsapp_ndt"

async function seedDatabase() {
  try {
    await mongoose.connect(MONGODB_URI, {
      useNewUrlParser: true,
      useUnifiedTopology: true,
    })
    console.log("✅ MongoDB connected for seeding")

    // --- Xóa dữ liệu cũ (Tùy chọn: Bỏ comment nếu bạn muốn xóa sạch trước khi seed) ---
    console.log("🗑️ Clearing existing data...")
    await User.deleteMany({})
    await Message.deleteMany({})
    await Status.deleteMany({})
    await Call.deleteMany({})
    await GroupChat.deleteMany({}) // THÊM DÒNG NÀY
    console.log("🗑️ Existing data cleared.")

    // --- 1. Tạo người dùng mẫu ---
    console.log("Creating sample users...")
    const usersData = [
      {
        email: "alice@example.com",
        name: "Alice",
        status: "Hey there! I'm using WhatsApp NDT!",
        profilePictureUrl: "/uploads/default-user.png", // Updated default
        verified: true,
        lastMessageAt: new Date(Date.now() - 1000 * 60 * 1), // Example: 1 minute ago
        lastMessageContent: "Hello Charlie!", // Example last message
      },
      {
        email: "bob@example.com",
        name: "Bob",
        status: "Available",
        profilePictureUrl: "/uploads/default-user.png", // Updated default
        verified: true,
        lastMessageAt: new Date(Date.now() - 1000 * 60 * 2), // Example: 2 minutes ago
        lastMessageContent: "Looks great!", // Example last message
      },
      {
        email: "charlie@example.com",
        name: "Charlie",
        status: "Busy",
        profilePictureUrl: "/uploads/default-user.png", // Updated default
        verified: true,
        lastMessageAt: new Date(Date.now() - 1000 * 60 * 9), // Example: 9 minutes ago
        lastMessageContent: "Yes, confirmed.", // Example last message
      },
      {
        email: "david@example.com",
        name: "David",
        status: "At the gym",
        profilePictureUrl: "/uploads/default-user.png", // Updated default
        verified: true,
        lastMessageAt: new Date(Date.now() - 1000 * 60 * 9), // Example: 9 minutes ago
        lastMessageContent: "Yes, confirmed.", // Example last message
      },
      {
        email: "eve@example.com",
        name: "Eve",
        status: "Coding...",
        profilePictureUrl: "/uploads/default-user.png", // Updated default
        verified: true,
        lastMessageAt: new Date(Date.now() - 1000 * 60 * 30), // Example: 30 minutes ago
        lastMessageContent: "Declined call.", // Example last message
      },
      // Thêm người dùng mặc định từ Flutter ChatPage
      {
        email: "devstack@example.com",
        name: "Dev Stack",
        status: "A full stack developer",
        profilePictureUrl: "/uploads/default-user.png", // Updated default
        verified: true,
        lastMessageAt: new Date(Date.now() - 1000 * 60 * 14),
        lastMessageContent: "Chào Alice! Rất tốt, cảm ơn bạn!",
      },
      {
        email: "flutterteam@example.com",
        name: "Flutter Team",
        status: "New Flutter update is amazing!",
        profilePictureUrl: "/uploads/default-user.png", // Updated default
        verified: true,
        lastMessageAt: new Date(Date.now() - 1000 * 60 * 12),
        lastMessageContent: "Có bản cập nhật mới nào không?",
      },
      // THÊM EMAIL CỦA BẠN VÀO ĐÂY
      {
        email: "cphanthanhnhan74@gmail.com",
        name: "Phan Thanh Nhan",
        status: "Đang phát triển ứng dụng WhatsApp NDT!",
        profilePictureUrl: "/uploads/default-user.png", // Updated default
        verified: true,
        lastMessageAt: new Date(Date.now() - 1000 * 60 * 1),
        lastMessageContent: "Bạn có muốn thử tính năng mới không?",
      },
    ]
    // Thêm các người dùng bổ sung để đạt tổng cộng 30 người dùng
    for (let i = 9; usersData.length < 30; i++) {
      // Bắt đầu từ img=9 để tránh trùng lặp
      usersData.push({
        email: `user${i}@example.com`,
        name: `User ${i}`,
        status: `Hello from User ${i}!`,
        profilePictureUrl: `/uploads/default-user.png`, // Updated default
        verified: true,
        lastMessageAt: new Date(Date.now() - Math.floor(Math.random() * 1000 * 60 * 60 * 24)), // Random time in last 24h
        lastMessageContent: `Random message ${i}`,
      })
    }
    const users = await User.insertMany(usersData)
    // Gán lại các biến người dùng chính xác sau khi insertMany
    const [alice, bob, charlie, david, eve, devstack, flutterteam, phanthanhnhan, ...otherUsers] = users
    console.log(`👥 Created ${users.length} users.`)

    // --- 2. Tạo nhóm chat mẫu ---
    console.log("Creating sample group chats...")
    const group1 = await GroupChat.create({
      name: "Flutter Devs",
      description: "Nhóm dành cho các nhà phát triển Flutter",
      profilePictureUrl: "/uploads/default-group.png", // Updated default
      members: [alice._id, bob._id, phanthanhnhan._id, devstack._id, flutterteam._id],
      admin: [alice._id, phanthanhnhan._id],
      lastMessageAt: new Date(Date.now() - 1000 * 60 * 18),
      lastMessageContent: "Có ai đang làm việc với Flutter 3.0 không?",
    })
    const group2 = await GroupChat.create({
      name: "Bạn bè thân thiết",
      description: "Nhóm bạn bè thân thiết của Nhan",
      profilePictureUrl: "/uploads/default-group.png", // Updated default
      members: [phanthanhnhan._id, charlie._id, david._id],
      admin: [phanthanhnhan._id],
      lastMessageAt: new Date(Date.now() - 1000 * 60 * 10),
      lastMessageContent: "Nhóm bạn bè thân thiết của tôi!",
    })
    console.log(`👨‍👩‍👧‍👦 Created 2 group chats.`)

    // --- 3. Tạo tin nhắn mẫu ---
    console.log("Creating sample messages...")
    const messagesData = [
      {
        sender: alice._id,
        receiver: bob._id,
        content: "Hi Bob, how are you?",
        type: "text",
        status: "read",
        createdAt: new Date(Date.now() - 1000 * 60 * 5), // 5 phút trước
      },
      {
        sender: bob._id,
        receiver: alice._id,
        content: "I'm good, Alice! How about you?",
        type: "text",
        status: "read",
        createdAt: new Date(Date.now() - 1000 * 60 * 4), // 4 phút trước
      },
      {
        sender: alice._id,
        receiver: bob._id,
        content: "Đã gửi ảnh",
        type: "image",
        contentUrl: "https://picsum.photos/id/237/200/300", // Ảnh mẫu
        status: "delivered",
        createdAt: new Date(Date.now() - 1000 * 60 * 3), // 3 phút trước
      },
      {
        sender: bob._id,
        receiver: alice._id,
        content: "Looks great!",
        type: "text",
        status: "sent", // Chưa đọc
        createdAt: new Date(Date.now() - 1000 * 60 * 2), // 2 phút trước
      },
      {
        sender: charlie._id,
        receiver: david._id,
        content: "Meeting at 3 PM?",
        type: "text",
        status: "read",
        createdAt: new Date(Date.now() - 1000 * 60 * 10), // 10 phút trước
      },
      {
        sender: david._id,
        receiver: charlie._id,
        content: "Yes, confirmed.",
        type: "text",
        status: "read",
        createdAt: new Date(Date.now() - 1000 * 60 * 9), // 9 phút trước
      },
      {
        sender: alice._id,
        receiver: charlie._id,
        content: "Hello Charlie!",
        type: "text",
        status: "sent",
        createdAt: new Date(Date.now() - 1000 * 60 * 1), // 1 phút trước
      },
      // Thêm tin nhắn mẫu cho Dev Stack và Flutter Team
      {
        sender: alice._id,
        receiver: devstack._id,
        content: "Chào Dev Stack! Ứng dụng hoạt động tốt chứ?",
        type: "text",
        status: "read",
        createdAt: new Date(Date.now() - 1000 * 60 * 15),
      },
      {
        sender: devstack._id,
        receiver: alice._id,
        content: "Chào Alice! Rất tốt, cảm ơn bạn!",
        type: "text",
        status: "read",
        createdAt: new Date(Date.now() - 1000 * 60 * 14),
      },
      {
        sender: bob._id,
        receiver: flutterteam._id,
        content: "Flutter Team, có bản cập nhật mới nào không?",
        type: "text",
        status: "sent",
        createdAt: new Date(Date.now() - 1000 * 60 * 12),
      },
      // THÊM TIN NHẮN MẪU CHO TÀI KHOẢN CỦA BẠN
      {
        sender: alice._id,
        receiver: phanthanhnhan._id,
        content: "Chào Phan Thanh Nhan! Bạn khỏe không?",
        type: "text",
        status: "delivered",
        createdAt: new Date(Date.now() - 1000 * 60 * 7),
      },
      {
        sender: phanthanhnhan._id,
        receiver: alice._id,
        content: "Chào Alice! Tôi khỏe, cảm ơn bạn. Ứng dụng đang chạy tốt!",
        type: "text",
        status: "read",
        createdAt: new Date(Date.now() - 1000 * 60 * 6),
      },
      {
        sender: bob._id,
        receiver: phanthanhnhan._id,
        content: "Bạn có muốn thử tính năng mới không?",
        type: "text",
        status: "sent",
        createdAt: new Date(Date.now() - 1000 * 60 * 1),
      },
      // THÊM TIN NHẮN NHÓM MẪU
      {
        sender: alice._id,
        group: group1._id,
        content: "Chào mọi người trong nhóm Flutter Devs!",
        type: "text",
        status: "delivered",
        createdAt: new Date(Date.now() - 1000 * 60 * 20),
      },
      {
        sender: phanthanhnhan._id,
        group: group1._id,
        content: "Chào Alice! Rất vui được tham gia nhóm.",
        type: "text",
        status: "read",
        createdAt: new Date(Date.now() - 1000 * 60 * 19),
      },
      {
        sender: devstack._id,
        group: group1._id,
        content: "Có ai đang làm việc với Flutter 3.0 không?",
        type: "text",
        status: "sent",
        createdAt: new Date(Date.now() - 1000 * 60 * 18),
      },
      {
        sender: phanthanhnhan._id,
        group: group2._id,
        content: "Nhóm bạn bè thân thiết của tôi!",
        type: "text",
        status: "delivered",
        createdAt: new Date(Date.now() - 1000 * 60 * 10),
      },
    ]
    const messages = await Message.insertMany(messagesData)
    console.log(`💬 Created ${messages.length} messages.`)

    // --- 4. Tạo trạng thái mẫu ---
    console.log("Creating sample statuses...")
    const statusesData = [
      {
        user: alice._id,
        type: "text",
        content: "Enjoying my day! 😊",
        expiresAt: new Date(Date.now() + 23 * 60 * 60 * 1000), // Hết hạn sau 23 giờ
        createdAt: new Date(Date.now() - 1000 * 60 * 30), // 30 phút trước
      },
      {
        user: bob._id,
        type: "image",
        mediaUrl: "https://picsum.photos/id/1047/200/300", // Ảnh mẫu
        expiresAt: new Date(Date.now() + 22 * 60 * 60 * 1000), // Hết hạn sau 22 giờ
        createdAt: new Date(Date.now() - 1000 * 60 * 45), // 45 phút trước
      },
      {
        user: charlie._id,
        type: "text",
        content: "Working hard! 💻",
        expiresAt: new Date(Date.now() + 20 * 60 * 60 * 1000),
        createdAt: new Date(Date.now() - 1000 * 60 * 60 * 2), // 2 giờ trước
      },
      {
        user: david._id,
        type: "image",
        mediaUrl: "https://picsum.photos/id/1084/200/300",
        expiresAt: new Date(Date.now() + 18 * 60 * 60 * 1000),
        createdAt: new Date(Date.now() - 1000 * 60 * 60 * 3), // 3 giờ trước
      },
      {
        user: devstack._id,
        type: "text",
        content: "Building awesome apps!",
        expiresAt: new Date(Date.now() + 21 * 60 * 60 * 1000),
        createdAt: new Date(Date.now() - 1000 * 60 * 50),
      },
      {
        user: flutterteam._id,
        type: "image",
        mediaUrl: "https://picsum.photos/id/1025/200/300",
        expiresAt: new Date(Date.now() + 19 * 60 * 60 * 1000),
        createdAt: new Date(Date.now() - 1000 * 60 * 65),
      },
      // THÊM TRẠNG THÁI MẪU CHO TÀI KHOẢN CỦA BẠN
      {
        user: phanthanhnhan._id,
        type: "text",
        content: "Chào buổi sáng! ☕",
        expiresAt: new Date(Date.now() + 23 * 60 * 60 * 1000),
        createdAt: new Date(Date.now() - 1000 * 60 * 10),
      },
    ]
    const statuses = await Status.insertMany(statusesData)
    console.log(`✨ Created ${statuses.length} statuses.`)

    // --- 5. Tạo lịch sử cuộc gọi mẫu ---
    console.log("Creating sample calls...")
    const callsData = [
      {
        caller: alice._id,
        receiver: bob._id,
        callType: "audio",
        callStatus: "outgoing",
        duration: 60,
        timestamp: new Date(Date.now() - 1000 * 60 * 60 * 4), // 4 giờ trước
      },
      {
        caller: bob._id,
        receiver: alice._id,
        callType: "audio",
        callStatus: "incoming",
        duration: 120,
        timestamp: new Date(Date.now() - 1000 * 60 * 60 * 3), // 3 giờ trước
      },
      {
        caller: charlie._id,
        receiver: alice._id,
        callType: "video",
        callStatus: "missed",
        duration: 0,
        timestamp: new Date(Date.now() - 1000 * 60 * 60 * 2), // 2 giờ trước
      },
      {
        caller: david._id,
        receiver: eve._id,
        callType: "audio",
        callStatus: "answered",
        duration: 300,
        timestamp: new Date(Date.now() - 1000 * 60 * 60 * 1), // 1 giờ trước
      },
      {
        caller: eve._id,
        receiver: david._id,
        callType: "video",
        callStatus: "declined",
        duration: 0,
        timestamp: new Date(Date.now() - 1000 * 60 * 30), // 30 phút trước
      },
      // Thêm cuộc gọi mẫu cho Dev Stack và Flutter Team
      {
        caller: alice._id,
        receiver: devstack._id,
        callType: "audio",
        callStatus: "answered",
        duration: 90,
        timestamp: new Date(Date.now() - 1000 * 60 * 60 * 5),
      },
      {
        caller: flutterteam._id,
        receiver: bob._id,
        callType: "video",
        callStatus: "missed",
        duration: 0,
        timestamp: new Date(Date.now() - 1000 * 60 * 60 * 6),
      },
      // THÊM CUỘC GỌI MẪU CHO TÀI KHOẢN CỦA BẠN
      {
        caller: phanthanhnhan._id,
        receiver: alice._id,
        callType: "audio",
        callStatus: "outgoing",
        duration: 45,
        timestamp: new Date(Date.now() - 1000 * 60 * 20),
      },
      {
        caller: bob._id,
        receiver: phanthanhnhan._id,
        callType: "video",
        callStatus: "missed",
        duration: 0,
        timestamp: new Date(Date.now() - 1000 * 60 * 15),
      },
    ]
    // Thêm 41 cuộc gọi bổ sung để đạt tổng cộng 50 cuộc gọi
    const callTypes = ["audio", "video"]
    const callStatuses = ["incoming", "outgoing", "missed", "answered", "declined"]
    for (let i = 0; i < 41; i++) {
      const randomCallerIndex = Math.floor(Math.random() * users.length)
      let randomReceiverIndex = Math.floor(Math.random() * users.length)
      while (randomReceiverIndex === randomCallerIndex) {
        randomReceiverIndex = Math.floor(Math.random() * users.length)
      }
      const caller = users[randomCallerIndex]
      const receiver = users[randomReceiverIndex]
      const callType = callTypes[Math.floor(Math.random() * callTypes.length)]
      const callStatus = callStatuses[Math.floor(Math.random() * callStatuses.length)]
      const duration = callStatus === "answered" ? Math.floor(Math.random() * 600) + 10 : 0 // 10-610 giây nếu answered
      callsData.push({
        caller: caller._id,
        receiver: receiver._id,
        callType: callType,
        callStatus: callStatus,
        duration: duration,
        timestamp: new Date(Date.now() - Math.floor(Math.random() * 1000 * 60 * 60 * 24 * 7)), // Trong vòng 7 ngày qua
      })
    }
    const calls = await Call.insertMany(callsData)
    console.log(`📞 Created ${calls.length} calls.`)

    console.log("🎉 Database seeding complete!")
  } catch (error) {
    console.error("❌ Database seeding failed:", error)
  } finally {
    mongoose.disconnect()
    console.log("Disconnected from MongoDB.")
  }
}

seedDatabase()
