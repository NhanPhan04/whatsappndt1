import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // Import image_picker
import 'dart:io'; // For File
import '../services/auth_service.dart';

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  TextEditingController nameController = TextEditingController();
  TextEditingController statusController = TextEditingController();
  bool isLoading = false;
  Map<String, dynamic>? userData;
  String? _profilePictureUrl; // URL ảnh đại diện hiện tại
  File? _newProfileImage; // File ảnh mới được chọn

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      isLoading = true;
    });
    final result = await AuthService.fetchUserProfile();
    if (result['success']) {
      setState(() {
        userData = result['user'];
        nameController.text = userData!['name'] ?? '';
        statusController.text = userData!['status'] ?? '';
        _profilePictureUrl = userData!['profilePictureUrl']; // Lấy URL ảnh
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Không thể tải hồ sơ: ${result['message']}")),
      );
    }
    setState(() {
      isLoading = false;
    });
  }

  Future<void> _pickImage() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _newProfileImage = File(image.path);
      });
    }
  }

  Future<void> _updateProfile() async {
    setState(() {
      isLoading = true;
    });

    String? finalProfilePictureUrl = _profilePictureUrl;

    if (_newProfileImage != null) {
      // Upload ảnh mới nếu có
      final uploadResult = await AuthService.uploadFile(_newProfileImage!.path);
      if (uploadResult['success']) {
        finalProfilePictureUrl = uploadResult['url'];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Đã tải ảnh đại diện lên thành công!")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Tải ảnh đại diện thất bại: ${uploadResult['message']}")),
        );
        setState(() {
          isLoading = false;
        });
        return; // Dừng nếu upload ảnh thất bại
      }
    }

    final result = await AuthService.updateProfile(
      nameController.text.trim(),
      statusController.text.trim(),
      finalProfilePictureUrl, // Gửi URL ảnh cuối cùng
    );

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Cập nhật hồ sơ thành công!")),
      );
      // Cập nhật lại dữ liệu trong AuthService sau khi update thành công
      // AuthService.saveUserData đã được gọi trong AuthService.updateProfile
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Cập nhật hồ sơ thất bại: ${result['message']}")),
      );
    }
    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Hồ sơ của bạn"),
        backgroundColor: Color(0xFF075E54),
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: _pickImage, // Nhấn vào để chọn ảnh
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Color(0xFF075E54),
                backgroundImage: _newProfileImage != null
                    ? FileImage(_newProfileImage!) // Ảnh mới được chọn
                    : (_profilePictureUrl != null && _profilePictureUrl!.isNotEmpty
                    ? NetworkImage(_profilePictureUrl!) // Ảnh từ server
                    : null) as ImageProvider<Object>?,
                child: _newProfileImage == null && (_profilePictureUrl == null || _profilePictureUrl!.isEmpty)
                    ? Icon(Icons.person, size: 80, color: Colors.white)
                    : null,
              ),
            ),
            SizedBox(height: 10),
            TextButton(
              onPressed: _pickImage,
              child: Text("Thay đổi ảnh đại diện"),
            ),
            SizedBox(height: 20),
            Text(
              userData?['email'] ?? "Email",
              style: TextStyle(fontSize: 18, color: Colors.grey[700]),
            ),
            SizedBox(height: 30),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: "Tên hiển thị",
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            SizedBox(height: 20),
            TextField(
              controller: statusController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: "Trạng thái",
                prefixIcon: Icon(Icons.info_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isLoading ? null : _updateProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF075E54),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text("Cập nhật hồ sơ", style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    statusController.dispose();
    super.dispose();
  }
}
