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

  ChatModel sourceChat = ChatModel(
    name: "You",
    icon: "person.svg",
    isGroup: false,
    time: "",
    currentMessage: "",
    status: "Online",
    id: 0,
    email: "",
    profilePictureUrl: null,
    userId: null, // THÊM TRƯỜNG NÀY
  );

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
        sourceChat.email = userData!['email'];
        sourceChat.name = userData!['name'];
        sourceChat.status = userData!['status'];
        sourceChat.profilePictureUrl = userData!['profilePictureUrl'];
        sourceChat.userId = userData!['_id']; // Lấy userId từ backend
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
              ];
            },
          ),
        ],
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
      body: userData == null
          ? Center(
        child: CircularProgressIndicator(),
      )
          : TabBarView(
        controller: _tabController,
        children: [
          CameraPage(),
          ChatPage(
            sourchat: sourceChat, // Chỉ truyền sourceChat
          ),
          StatusPage(sourceUserId: sourceChat.userId!), // Truyền userId
          CallPage(sourceUserId: sourceChat.userId!), // Truyền userId
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ContactsPage(
              sourceUserEmail: userData!['email'],
              sourceUserId: userData!['_id'], // Truyền userId của mình
            )),
          );
        },
        backgroundColor: Color(0xFF075E54),
        child: Icon(Icons.chat, color: Colors.white),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    AuthService.getSocket().disconnect();
    super.dispose();
  }
}
