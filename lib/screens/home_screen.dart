import 'package:flutter/material.dart';
import '../pages/camera_page.dart';
import '../pages/chat_page.dart';
import '../pages/status_page.dart';
import '../pages/call_page.dart';
import '../models/chat_model.dart';
import '../services/auth_service.dart';
import 'landing_screen.dart';
import 'contacts_page.dart';
import 'profile_page.dart';
import 'user_profile_page.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? userData;
  ChatModel? sourceChat;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: 1);
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final result = await AuthService.fetchUserProfile();
    if (result['success']) {
      setState(() {
        userData = result['user'];
        sourceChat = ChatModel(
          name: userData!['name'] ?? "You",
          icon: "person.svg",
          isGroup: false,
          time: "",
          currentMessage: "",
          status: userData!['status'] ?? "Online",
          id: 0,
          email: userData!['email'],
          profilePictureUrl: userData!['profilePictureUrl'],
          userId: userData!['_id'],
          lastMessageAt: DateTime.now(),
          lastMessageContent: "",
        );
      });
      AuthService.getSocket().connect();
      AuthService.getSocket().emit("signin", userData!['email']);
    } else {
      print('Failed to load user profile: ${result['message']}');
      await AuthService.logout();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => LandingScreen()),
            (route) => false,
      );
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Đăng xuất"),
        content: Text("Bạn có chắc chắn muốn đăng xuất?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Hủy"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text("Đăng xuất"),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await AuthService.logout();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => LandingScreen()),
            (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Lấy chiều rộng màn hình hiện tại
    final screenWidth = MediaQuery.of(context).size.width;
    // Định nghĩa ngưỡng cho màn hình lớn (ví dụ: tablet hoặc điện thoại gập)
    // Bạn có thể điều chỉnh ngưỡng này tùy theo thiết kế mong muốn
    final bool isLargeScreen = screenWidth > 600; // Ví dụ: > 600 logical pixels

    return Scaffold(
      appBar: AppBar(
        title: Text("WhatsApp NDT"),
        backgroundColor: Color(0xFF075E54),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () {
              // TODO: Implement search
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ProfilePage()),
                  ).then((_) => _loadUserInfo());
                  break;
                case 'settings':
                // TODO: Navigate to settings
                  break;
                case 'logout':
                  _logout();
                  break;
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                PopupMenuItem(
                  value: 'profile',
                  child: Row(
                    children: [
                      Icon(Icons.person, size: 20),
                      SizedBox(width: 10),
                      Text("Hồ sơ"),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(Icons.settings, size: 20),
                      SizedBox(width: 10),
                      Text("Cài đặt"),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, size: 20),
                      SizedBox(width: 10),
                      Text("Đăng xuất"),
                    ],
                  ),
                ),
              ]; // Đã sửa: Đóng danh sách PopupMenuItem bằng ];
            }, // Đóng itemBuilder
          ), // Đóng PopupMenuButton
        ], // Đóng danh sách actions
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            Tab(icon: Icon(Icons.camera_alt, size: 28)),
            Tab(text: "Trò Chuyện"),
            Tab(text: "Trạng Thái"),
            Tab(text: "Cuộc Gọi"),
          ],
        ),
      ),
      body: sourceChat == null // Kiểm tra nếu sourceChat là null
          ? Center(
        child: CircularProgressIndicator(),
      )
          : LayoutBuilder(
        builder: (context, constraints) {
          final double contentWidth = isLargeScreen ? 700.0 : constraints.maxWidth;

          return Center(
            child: SizedBox(
              width: contentWidth,
              child: TabBarView(
                controller: _tabController,
                children: [
                  CameraPage(),
                  ChatPage(
                    sourchat: sourceChat!, // Sử dụng toán tử null-check ở đây
                  ),
                  StatusPage(sourceUserId: sourceChat!.userId!), // Sử dụng toán tử null-check ở đây
                  CallPage(sourceUserId: sourceChat!.userId!), // Sử dụng toán tử null-check ở đây
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (userData != null && sourceChat != null) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ContactsPage(
                sourceUserEmail: userData!['email'],
                sourceUserId: userData!['_id'],
              )),
            );
          }
        },
        backgroundColor: Color(0xFF075E54),
        child: Icon(Icons.chat, color: Colors.white),
      ),
      // Có thể điều chỉnh vị trí FAB cho màn hình lớn hơn nếu cần
      // Ví dụ: FloatingActionButtonLocation.centerFloat hoặc FloatingActionButtonLocation.endDocked
      floatingActionButtonLocation: isLargeScreen
          ? FloatingActionButtonLocation.endFloat // Giữ nguyên hoặc thay đổi
          : FloatingActionButtonLocation.endFloat, // Mặc định
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    AuthService.getSocket().disconnect();
    super.dispose();
  }
}
