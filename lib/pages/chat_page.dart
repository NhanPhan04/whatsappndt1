import 'package:flutter/material.dart';
import '../models/chat_model.dart';
import '../screens/individual_page.dart';
import '../services/auth_service.dart';

class ChatPage extends StatefulWidget {
  final ChatModel sourchat;

  ChatPage({
    Key? key,
    required this.sourchat,
  }) : super(key: key);

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  List<ChatModel> chats = [];
  List<ChatModel> filteredChats = [];
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
    _fetchChats();
    _scrollController.addListener(_scrollListener);
    AuthService.getSocket().on("chat_list_update", (data) {
      print("Received chat list update: $data");
      final String chatId = data['chatId'];
      final String lastMessageContent = data['lastMessageContent'] ?? "";
      final DateTime lastMessageAt = DateTime.parse(data['lastMessageAt']);
      final bool isGroup = data['isGroup'] ?? false;

      setState(() {
        final index = chats.indexWhere((chat) =>
        (isGroup && chat.groupId == chatId) ||
            (!isGroup && chat.userId == chatId));

        if (index != -1) {
          // Update existing chat
          chats[index].lastMessageAt = lastMessageAt;
          chats[index].lastMessageContent = lastMessageContent;
        } else {
          // If chat not found (e.g., new chat with a user not yet fetched),
          // re-fetch all chats to ensure it appears.
          // This is a fallback for simplicity; a more robust solution
          // would fetch only the new chat's details.
          _fetchChats(forceRefresh: true);
        }
        _sortChats(); // Re-sort the list
      });
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
      final result = await AuthService.fetchUsers(
        page: isLoadMore ? currentPageUsers + 1 : 1,
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
            time: "", // This will be updated by lastMessageAt
            currentMessage: userJson['lastMessageContent'] ?? "", // Use new field
            id: 0,
            profilePictureUrl: userJson['profilePictureUrl'],
            userId: userJson['_id'],
            lastMessageAt: userJson['lastMessageAt'] != null ? DateTime.parse(userJson['lastMessageAt']) : null, // Parse new field
            lastMessageContent: userJson['lastMessageContent'] ?? "", // Use new field
          ))
              .where((user) => user.userId != widget.sourchat.userId)
              .toList();

          if (isLoadMore) {
            chats.addAll(newUsers);
          } else {
            chats.removeWhere((chat) => !chat.isGroup);
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
            email: "",
            status: groupJson['description'] ?? "Nhóm chat",
            icon: "group.svg",
            isGroup: true,
            time: "", // This will be updated by lastMessageAt
            currentMessage: groupJson['lastMessageContent'] ?? "", // Use new field
            id: 0,
            profilePictureUrl: groupJson['profilePictureUrl'],
            groupId: groupJson['_id'],
            members: groupJson['members'],
            lastMessageAt: groupJson['lastMessageAt'] != null ? DateTime.parse(groupJson['lastMessageAt']) : null, // Parse new field
            lastMessageContent: groupJson['lastMessageContent'] ?? "", // Use new field
          ))
              .toList();

          if (isLoadMore) {
            chats.addAll(newGroups);
          } else {
            chats.removeWhere((chat) => chat.isGroup);
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
    chats.sort((a, b) {
      // Sort by lastMessageAt descending. If null, treat as older.
      if (a.lastMessageAt == null && b.lastMessageAt == null) return 0;
      if (a.lastMessageAt == null) return 1; // b is newer
      if (b.lastMessageAt == null) return -1; // a is newer
      return b.lastMessageAt!.compareTo(a.lastMessageAt!);
    });
    filteredChats = List.from(chats);
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
                    chatModel: chat,
                    sourchat: widget.sourchat,
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
                  // Đã sửa lỗi: Sử dụng AuthService.getFullImageUrl
                  backgroundImage: NetworkImage(AuthService.getFullImageUrl(chat.profilePictureUrl)),
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
                        chat.lastMessageContent!.isEmpty ? chat.status : chat.lastMessageContent!, // Use lastMessageContent
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
                  chat.lastMessageAt != null
                      ? '${chat.lastMessageAt!.hour}:${chat.lastMessageAt!.minute.toString().padLeft(2, '0')}' // Format time
                      : "",
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
    AuthService.getSocket().off("chat_list_update");
    super.dispose();
  }
}
