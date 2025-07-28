import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class UserProfilePage extends StatefulWidget {
  final String userEmail;

  const UserProfilePage({Key? key, required this.userEmail}) : super(key: key);

  @override
  _UserProfilePageState createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  Map<String, dynamic>? userProfile;
  bool isLoading = true;
  String errorMessage = "";

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    setState(() {
      isLoading = true;
      errorMessage = "";
    });
    try {
      // Lấy tất cả người dùng và tìm người dùng cụ thể
      final result = await AuthService.fetchUsers();
      if (result['success']) {
        final users = result['users'] as List;
        final foundUser = users.firstWhere(
              (user) => user['email'] == widget.userEmail,
          orElse: () => null,
        );

        if (foundUser != null) {
          setState(() {
            userProfile = foundUser;
          });
        } else {
          setState(() {
            errorMessage = "Không tìm thấy người dùng này.";
          });
        }
      } else {
        setState(() {
          errorMessage = result['message'] ?? "Không thể tải danh sách người dùng.";
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "Lỗi kết nối: $e";
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Thông tin liên hệ"),
        backgroundColor: Color(0xFF075E54),
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty
          ? Center(
        child: Text(errorMessage, style: TextStyle(color: Colors.red)),
      )
          : userProfile == null
          ? Center(child: Text("Không có dữ liệu profile."))
          : SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 60,
              backgroundColor: Color(0xFF075E54),
              child: Icon(Icons.person, size: 80, color: Colors.white),
            ),
            SizedBox(height: 20),
            Text(
              userProfile!['name'] ?? "Không tên",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              userProfile!['email'] ?? "Không có email",
              style: TextStyle(fontSize: 18, color: Colors.grey[700]),
            ),
            SizedBox(height: 20),
            Divider(),
            SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.info_outline, color: Color(0xFF075E54)),
              title: Text("Trạng thái"),
              subtitle: Text(userProfile!['status'] ?? "Không có trạng thái"),
            ),
            ListTile(
              leading: Icon(Icons.calendar_today, color: Color(0xFF075E54)),
              title: Text("Ngày tham gia"),
              subtitle: Text(
                userProfile!['createdAt'] != null
                    ? DateTime.parse(userProfile!['createdAt']).toLocal().toString().split(' ')[0]
                    : "Không rõ",
              ),
            ),
            // Thêm các thông tin khác nếu có trong userProfile
          ],
        ),
      ),
    );
  }
}
