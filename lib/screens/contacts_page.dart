import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/chat_model.dart';
import 'individual_page.dart';
import 'create_group_screen.dart';

class ContactsPage extends StatefulWidget {
  final String sourceUserEmail;
  final String sourceUserId;
  const ContactsPage({Key? key, required this.sourceUserEmail, required this.sourceUserId}) : super(key: key);

  @override
  _ContactsPageState createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  List<ChatModel> users = [];
  List<ChatModel> filteredUsers = [];
  bool isLoading = true;
  String errorMessage = "";
  TextEditingController searchController = TextEditingController();
  int currentPage = 1;
  int totalPages = 1;
  bool isFetchingMore = false;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    searchController.addListener(_filterUsers);
  }

  // Đã sửa lỗi: Thêm tham số forceRefresh vào định nghĩa hàm
  Future<void> _fetchUsers({bool isLoadMore = false, bool forceRefresh = false}) async {
    if (forceRefresh) {
      users.clear();
      currentPage = 1;
    }
    if (isLoadMore && currentPage >= totalPages) return;

    setState(() {
      if (isLoadMore) {
        isFetchingMore = true;
      } else {
        isLoading = true;
        errorMessage = "";
      }
    });

    try {
      final result = await AuthService.fetchUsers(
        page: isLoadMore ? currentPage + 1 : 1,
        limit: 1000, // Updated limit from 50 to 1000
        excludeVirtual: true, // CHỈ LẤY NGƯỜI DÙNG THẬT
      );

      if (result['success']) {
        setState(() {
          final newUsers = (result['users'] as List)
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
              .toList();

          if (isLoadMore || forceRefresh) { // Thêm forceRefresh vào điều kiện này
            users.addAll(newUsers);
          } else {
            users = newUsers;
          }
          currentPage = result['currentPage'];
          totalPages = result['totalPages'];
          _filterUsers(); // Áp dụng bộ lọc tìm kiếm sau khi tải người dùng
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
        isLoading = false;
        isFetchingMore = false;
      });
    }
  }

  void _filterUsers() {
    String query = searchController.text.toLowerCase();
    setState(() {
      filteredUsers = users.where((user) {
        return user.name.toLowerCase().contains(query) ||
            user.email.toLowerCase().contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Chọn liên hệ"),
        backgroundColor: Color(0xFF075E54),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.group_add),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CreateGroupScreen(
                    sourceUserId: widget.sourceUserId,
                    sourceUserEmail: widget.sourceUserEmail,
                  ),
                ),
              );
              if (result == true) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Nhóm đã được tạo thành công!")),
                );
                _fetchUsers(forceRefresh: true); // Lời gọi hàm đã được sửa
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: "Tìm kiếm theo tên hoặc email...",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          isLoading && users.isEmpty
              ? Center(child: CircularProgressIndicator())
              : errorMessage.isNotEmpty
              ? Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(errorMessage, style: TextStyle(color: Colors.red)),
                  SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _fetchUsers,
                    child: Text("Thử lại"),
                  ),
                ],
              ),
            ),
          )
              : Expanded(
            child: ListView.builder(
              itemCount: filteredUsers.length + (isFetchingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == filteredUsers.length) {
                  if (currentPage < totalPages) {
                    _fetchUsers(isLoadMore: true);
                    return Center(child: CircularProgressIndicator());
                  } else {
                    return SizedBox.shrink();
                  }
                }
                final user = filteredUsers[index];
                return InkWell(
                  onTap: () {
                    final sourceChat = ChatModel(
                      name: "Bạn",
                      email: widget.sourceUserEmail,
                      icon: "person.svg",
                      isGroup: false,
                      time: "",
                      currentMessage: "",
                      status: "Online",
                      id: 0,
                      profilePictureUrl: null,
                      userId: widget.sourceUserId,
                    );
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => IndividualPage(
                          chatModel: user,
                          sourchat: sourceChat,
                        ),
                      ),
                    );
                  },
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Color(0xFF075E54),
                      backgroundImage: NetworkImage(AuthService.getFullImageUrl(user.profilePictureUrl)),
                      child: (user.profilePictureUrl == null || user.profilePictureUrl!.isEmpty)
                          ? Text(
                        user.name[0].toUpperCase(),
                        style: TextStyle(color: Colors.white),
                      )
                          : null,
                    ),
                    title: Text(user.name),
                    subtitle: Text(user.email),
                    trailing: Text(user.status),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}
