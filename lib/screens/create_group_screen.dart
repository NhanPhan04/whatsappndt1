import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/chat_model.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class CreateGroupScreen extends StatefulWidget {
  final String sourceUserId;
  final String sourceUserEmail;

  const CreateGroupScreen({Key? key, required this.sourceUserId, required this.sourceUserEmail}) : super(key: key);

  @override
  _CreateGroupScreenState createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  TextEditingController groupNameController = TextEditingController();
  TextEditingController groupDescriptionController = TextEditingController(); // Thêm controller cho mô tả
  TextEditingController searchController = TextEditingController();
  List<ChatModel> allUsers = [];
  List<ChatModel> filteredUsers = [];
  List<ChatModel> selectedMembers = [];
  bool isLoadingUsers = true;
  String errorMessage = "";
  bool isCreatingGroup = false;
  File? _groupImage;

  @override
  void initState() {
    super.initState();
    _fetchAllUsers();
    searchController.addListener(_filterUsers);
  }

  Future<void> _fetchAllUsers() async {
    setState(() {
      isLoadingUsers = true;
      errorMessage = "";
    });
    try {
      final result = await AuthService.fetchUsers(limit: 1000); // Lấy tất cả người dùng
      if (result['success']) {
        setState(() {
          allUsers = (result['users'] as List)
              .map((userJson) => ChatModel(
            name: userJson['name'] ?? userJson['email'],
            email: userJson['email'],
            status: userJson['status'] ?? "Available",
            icon: "person.svg",
            isGroup: false,
            time: "",
            currentMessage: "",
            id: 0,
            profilePictureUrl: userJson['profilePictureUrl'],
            userId: userJson['_id'],
          ))
              .where((user) => user.userId != widget.sourceUserId) // Loại bỏ chính mình
              .toList();
          _filterUsers(); // Áp dụng bộ lọc ban đầu
        });
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
        isLoadingUsers = false;
      });
    }
  }

  void _filterUsers() {
    String query = searchController.text.toLowerCase();
    setState(() {
      filteredUsers = allUsers.where((user) {
        return user.name.toLowerCase().contains(query) ||
            user.email.toLowerCase().contains(query);
      }).toList();
    });
  }

  void _toggleMemberSelection(ChatModel user) {
    setState(() {
      if (selectedMembers.contains(user)) {
        selectedMembers.remove(user);
      } else {
        selectedMembers.add(user);
      }
    });
  }

  Future<void> _pickGroupImage() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _groupImage = File(image.path);
      });
    }
  }

  Future<void> _createGroup() async {
    if (groupNameController.text.trim().isEmpty) {
      _showSnackBar("Vui lòng nhập tên nhóm.", isError: true);
      return;
    }
    if (selectedMembers.isEmpty) {
      _showSnackBar("Vui lòng chọn ít nhất một thành viên.", isError: true);
      return;
    }
    setState(() {
      isCreatingGroup = true;
    });
    String? groupImageUrl;
    if (_groupImage != null) {
      _showSnackBar("Đang tải ảnh nhóm lên...", isError: false);
      final uploadResult = await AuthService.uploadFile(_groupImage!.path);
      if (uploadResult['success']) {
        groupImageUrl = uploadResult['url'];
      } else {
        _showSnackBar("Tải ảnh nhóm lên thất bại: ${uploadResult['message']}", isError: true);
        setState(() {
          isCreatingGroup = false;
        });
        return;
      }
    }
    List<String> memberIds = selectedMembers.map((m) => m.userId!).toList();
    memberIds.add(widget.sourceUserId); // Thêm người tạo vào danh sách thành viên

    final result = await AuthService.createGroup(
      groupNameController.text.trim(),
      memberIds,
      groupDescriptionController.text.trim().isEmpty ? null : groupDescriptionController.text.trim(), // Truyền mô tả
      groupImageUrl, // Truyền URL ảnh nhóm
    );

    if (result['success']) {
      _showSnackBar("Đã tạo nhóm thành công!", isError: false);
      Navigator.pop(context, true); // Quay lại màn hình trước và báo thành công
    } else {
      _showSnackBar("Tạo nhóm thất bại: ${result['message']}", isError: true);
    }
    setState(() {
      isCreatingGroup = false;
    });
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Tạo nhóm mới"),
        backgroundColor: Color(0xFF075E54),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickGroupImage,
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: _groupImage != null
                        ? FileImage(_groupImage!)
                        : null,
                    child: _groupImage == null
                        ? Icon(Icons.camera_alt, size: 40, color: Colors.grey[600])
                        : null,
                  ),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: groupNameController,
                  decoration: InputDecoration(
                    hintText: "Tên nhóm",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: groupDescriptionController, // Thêm TextField cho mô tả
                  decoration: InputDecoration(
                    hintText: "Mô tả nhóm (Tùy chọn)",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  maxLines: 2,
                ),
                SizedBox(height: 10),
                TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: "Tìm kiếm thành viên...",
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          selectedMembers.isNotEmpty
              ? Container(
            height: 60,
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: selectedMembers.length,
              itemBuilder: (context, index) {
                final member = selectedMembers[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5.0),
                  child: Chip(
                    avatar: CircleAvatar(
                      backgroundImage: member.profilePictureUrl != null && member.profilePictureUrl!.isNotEmpty
                          ? NetworkImage(member.profilePictureUrl!)
                          : null,
                      child: (member.profilePictureUrl == null || member.profilePictureUrl!.isEmpty)
                          ? Text(member.name[0].toUpperCase())
                          : null,
                    ),
                    label: Text(member.name),
                    onDeleted: () => _toggleMemberSelection(member),
                  ),
                );
              },
            ),
          )
              : SizedBox.shrink(),
          Divider(),
          Expanded(
            child: isLoadingUsers
                ? Center(child: CircularProgressIndicator())
                : errorMessage.isNotEmpty
                ? Center(
              child: Text(errorMessage, style: TextStyle(color: Colors.red)),
            )
                : ListView.builder(
              itemCount: filteredUsers.length,
              itemBuilder: (context, index) {
                final user = filteredUsers[index];
                final isSelected = selectedMembers.contains(user);
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Color(0xFF075E54),
                    backgroundImage: user.profilePictureUrl != null && user.profilePictureUrl!.isNotEmpty
                        ? NetworkImage(user.profilePictureUrl!)
                        : null,
                    child: (user.profilePictureUrl == null || user.profilePictureUrl!.isEmpty)
                        ? Text(
                      user.name[0].toUpperCase(),
                      style: TextStyle(color: Colors.white),
                    )
                        : null,
                  ),
                  title: Text(user.name),
                  subtitle: Text(user.email),
                  trailing: isSelected
                      ? Icon(Icons.check_circle, color: Colors.green)
                      : Icon(Icons.circle_outlined, color: Colors.grey),
                  onTap: () => _toggleMemberSelection(user),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isCreatingGroup ? null : _createGroup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF075E54),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: isCreatingGroup
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text(
                  "Tạo nhóm",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    groupNameController.dispose();
    groupDescriptionController.dispose(); // Dispose controller
    searchController.dispose();
    super.dispose();
  }
}
