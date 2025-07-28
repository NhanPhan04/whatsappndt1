import 'package:flutter/material.dart';
import '../models/chat_model.dart';
import '../screens/individual_page.dart';
import '../services/auth_service.dart'; // Import AuthService

class ChatPage extends StatefulWidget {
  // Bỏ chatmodels vì sẽ tải từ API
  final ChatModel sourchat;

  ChatPage({
    Key? key,
    required this.sourchat,
  }) : super(key: key);

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  List<ChatModel> chats = []; // Danh sách người dùng và nhóm từ API
  List<ChatModel> filteredChats = []; // Dùng cho tìm kiếm nếu có
  bool isLoading = true;
  String errorMessage = "";

  int currentPageUsers = 1;
  int totalPagesUsers = 1;
  bool isFetchingMoreUsers = false;

  int currentPageGroups = 1;
  int totalPagesGroups = 1;
  bool isFetchingMoreGroups = false;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchChats(); // Tải người dùng và nhóm khi khởi tạo
    _scrollController.addListener(_scrollListener);
    AuthService.getSocket().on("new_group_chat", (data) {
      // Lắng nghe sự kiện nhóm mới được tạo
      print("Received new group chat: $data");
      _fetchChats(forceRefresh: true); // Làm mới danh sách chat
    });
  }

  void _scrollListener() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      if (currentPageUsers < totalPagesUsers && !isFetchingMoreUsers) {
        _fetchUsers(isLoadMore: true);
      }
      if (currentPageGroups < totalPagesGroups && !isFetchingMoreGroups) {
        _fetchGroups(isLoadMore: true);
      }
    }
  }

  Future<void> _fetchChats({bool forceRefresh = false}) async {
    if (forceRefresh) {
      chats.clear();
      currentPageUsers = 1;
      currentPageGroups = 1;
    }
    await Future.wait([
      _fetchUsers(),
      _fetchGroups(),
    ]);
    _sortChats();
  }

  Future<void> _fetchUsers({bool isLoadMore = false}) async {
    if (isLoadMore && currentPageUsers >= totalPagesUsers) return;

    setState(() {
      if (isLoadMore) {
        isFetchingMoreUsers = true;
      } else {
        isLoading = true;
        errorMessage = "";
      }
    });

    try {
      final result = await AuthService.fetchUsers(page: isLoadMore ? currentPageUsers + 1 : 1, limit: 10);
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
              .where((user) => user.userId != widget.sourchat.userId)
              .toList();

          if (isLoadMore) {
            chats.addAll(newUsers);
          } else {
            chats.removeWhere((chat) => !chat.isGroup); // Xóa người dùng cũ nếu không load thêm
            chats.addAll(newUsers);
          }
          currentPageUsers = result['currentPage'];
          totalPagesUsers = result['totalPages'];
          _sortChats();
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
        isFetchingMoreUsers = false;
      });
    }
  }

  Future<void> _fetchGroups({bool isLoadMore = false}) async {
    if (isLoadMore && currentPageGroups >= totalPagesGroups) return;

    setState(() {
      if (isLoadMore) {
        isFetchingMoreGroups = true;
      } else {
        isLoading = true;
        errorMessage = "";
      }
    });

    try {
      final result = await AuthService.fetchGroups(page: isLoadMore ? currentPageGroups + 1 : 1, limit: 10);
      if (result['success']) {
        setState(() {
          final newGroups = (result['groups'] as List)
              .map((groupJson) => ChatModel(
            name: groupJson['name'],
            email: "", // Nhóm không có email
            status: groupJson['description'] ?? "Nhóm chat",
            icon: "group.svg",
            isGroup: true,
            time: "",
            currentMessage: "",
            id: 0,
            profilePictureUrl: groupJson['profilePictureUrl'],
            groupId: groupJson['_id'], // Lấy groupId
            members: groupJson['members'], // Lấy danh sách thành viên
          ))
              .toList();

          if (isLoadMore) {
            chats.addAll(newGroups);
          } else {
            chats.removeWhere((chat) => chat.isGroup); // Xóa nhóm cũ nếu không load thêm
            chats.addAll(newGroups);
          }
          currentPageGroups = result['currentPage'];
          totalPagesGroups = result['totalPages'];
          _sortChats();
        });
      } else {
        setState(() {
          errorMessage = result['message'] ?? "Không thể tải danh sách nhóm.";
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "Lỗi kết nối: $e";
      });
    } finally {
      setState(() {
        isLoading = false;
        isFetchingMoreGroups = false;
      });
    }
  }

  void _sortChats() {
    // Sắp xếp chats theo thời gian tin nhắn cuối cùng (nếu có) hoặc theo tên
    // Hiện tại chỉ sắp xếp theo tên để đơn giản
    chats.sort((a, b) => a.name.compareTo(b.name));
    filteredChats = chats; // Cập nhật filteredChats
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading && chats.isEmpty
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
                onPressed: _fetchChats,
                child: Text("Thử lại"),
              ),
            ],
          ),
        ),
      )
          : filteredChats.isEmpty
          ? Center(
        child: Text(
          "Không có cuộc trò chuyện nào được tìm thấy.",
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      )
          : ListView.builder(
        controller: _scrollController,
        itemCount: filteredChats.length + (isFetchingMoreUsers || isFetchingMoreGroups ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == filteredChats.length) {
            if (isFetchingMoreUsers || isFetchingMoreGroups) {
              return Center(child: CircularProgressIndicator());
            } else {
              return SizedBox.shrink();
            }
          }
          final chat = filteredChats[index];
          return InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => IndividualPage(
                    chatModel: chat, // Truyền chat model đầy đủ
                    sourchat: widget.sourchat, // Truyền source chat đầy đủ
                  ),
                ),
              );
            },
            child: Container(
              height: 70,
              child: ListTile(
                leading: CircleAvatar(
                  radius: 25,
                  backgroundColor: Color(0xFF075E54),
                  backgroundImage: chat.profilePictureUrl != null && chat.profilePictureUrl!.isNotEmpty
                      ? NetworkImage(chat.profilePictureUrl!)
                      : null,
                  child: (chat.profilePictureUrl == null || chat.profilePictureUrl!.isEmpty)
                      ? Icon(
                    chat.isGroup ? Icons.group : Icons.person,
                    color: Colors.white,
                  )
                      : null,
                ),
                title: Text(
                  chat.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Row(
                  children: [
                    Expanded(
                      child: Text(
                        chat.currentMessage.isEmpty ? chat.status : chat.currentMessage, // Hiển thị status nếu không có tin nhắn
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                trailing: Text(
                  chat.time.isEmpty ? "" : chat.time, // Không hiển thị thời gian nếu không có
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    AuthService.getSocket().off("new_group_chat"); // Hủy đăng ký sự kiện
    super.dispose();
  }
}
