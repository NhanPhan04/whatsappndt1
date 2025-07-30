import 'package:flutter/material.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../services/auth_service.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'user_profile_page.dart';

class IndividualPage extends StatefulWidget {
  final ChatModel chatModel; // Có thể là người dùng hoặc nhóm
  final ChatModel sourchat;

  IndividualPage({
    Key? key,
    required this.chatModel,
    required this.sourchat,
  }) : super(key: key);

  @override
  _IndividualPageState createState() => _IndividualPageState();
}

class _IndividualPageState extends State<IndividualPage> {
  TextEditingController _controller = TextEditingController();
  bool showEmojiPicker = false;
  List<MessageModel> messages = [];
  late IO.Socket socket;
  bool isTargetTyping = false; // Cho cá nhân
  Map<String, bool> groupTypingStatus = {}; // Cho nhóm: userId -> isTyping
  final ScrollController _scrollController = ScrollController();
  int currentPage = 1;
  int totalPages = 1;
  bool isFetchingMoreMessages = false;

  @override
  void initState() {
    super.initState();
    _connectSocket();
    _setupSocketListeners();
    _fetchMessages(); // Tải tin nhắn khi khởi tạo
    _scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent &&
        currentPage < totalPages &&
        !isFetchingMoreMessages) {
      _fetchMessages(isLoadMore: true);
    }
  }

  void _connectSocket() {
    socket = AuthService.getSocket();
    if (!socket.connected) {
      socket.connect();
    }
    socket.emit("signin", widget.sourchat.email);
  }

  void _setupSocketListeners() {
    socket.on("message", (data) {
      print("Received message: $data");
      final newMessage = MessageModel.fromJson(data, widget.sourchat.email);
      // Chỉ thêm tin nhắn nếu nó thuộc về cuộc trò chuyện hiện tại
      bool isForThisChat = false;
      if (widget.chatModel.isGroup && newMessage.groupId == widget.chatModel.groupId) {
        isForThisChat = true;
      } else if (!widget.chatModel.isGroup &&
          ((newMessage.sourceEmail == widget.chatModel.email && newMessage.targetEmail == widget.sourchat.email) ||
              (newMessage.sourceEmail == widget.sourchat.email && newMessage.targetEmail == widget.chatModel.email))) {
        isForThisChat = true;
      }

      if (isForThisChat) {
        setState(() {
          messages.add(newMessage); // Đã sửa: Thêm tin nhắn mới vào cuối danh sách
        });
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent, // Đã sửa: Cuộn xuống cuối
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
        // Nếu tin nhắn nhận được là của người khác và đang hiển thị, đánh dấu là đã đọc
        if (newMessage.sourceEmail != widget.sourchat.email && newMessage.id != null) {
          AuthService.markMessagesAsRead([newMessage.id!]);
          // Cập nhật trạng thái tin nhắn trong UI ngay lập tức
          final index = messages.indexWhere((msg) => msg.id == newMessage.id);
          if (index != -1) {
            setState(() {
              messages[index].status = "read";
            });
          }
        }
      }
    });

    socket.on("typing", (data) {
      if (widget.chatModel.isGroup) {
        // Xử lý typing cho nhóm
        final typingUserEmail = data['userEmail'];
        final typingGroupId = data['groupId'];
        final isTyping = data['isTyping'];
        if (typingGroupId == widget.chatModel.groupId && typingUserEmail != widget.sourchat.email) {
          setState(() {
            groupTypingStatus[typingUserEmail] = isTyping;
            // Xóa trạng thái typing nếu không còn gõ
            if (!isTyping) {
              groupTypingStatus.remove(typingUserEmail);
            }
          });
        }
      } else {
        // Xử lý typing cho cá nhân
        if (data['userEmail'] == widget.chatModel.email) {
          setState(() {
            isTargetTyping = data['isTyping'];
          });
        }
      }
    });

    socket.on("message_status_update", (data) {
      final messageId = data['messageId'];
      final status = data['status'];
      final index = messages.indexWhere((msg) => msg.id == messageId);
      if (index != -1) {
        setState(() {
          messages[index].status = status;
        });
      }
    });
  }

  Future<void> _fetchMessages({bool isLoadMore = false}) async {
    if (isLoadMore && currentPage >= totalPages) return;

    setState(() {
      isFetchingMoreMessages = true;
    });

    final String chatId = widget.chatModel.isGroup ? widget.chatModel.groupId! : widget.chatModel.userId!;
    final result = await AuthService.fetchMessages(
      chatId,
      page: isLoadMore ? currentPage + 1 : 1,
      limit: 30,
    );

    if (result['success']) {
      setState(() {
        final newMessages = (result['messages'] as List)
            .map((json) => MessageModel.fromJson(json, widget.sourchat.email))
            .toList();

        // Đánh dấu tin nhắn của người khác/nhóm là đã đọc khi tải về
        final messagesToMarkAsRead = newMessages
            .where((msg) => msg.sourceEmail != widget.sourchat.email && msg.status != "read" && msg.id != null)
            .map((msg) => msg.id!)
            .toList();

        if (messagesToMarkAsRead.isNotEmpty) {
          AuthService.markMessagesAsRead(messagesToMarkAsRead);
          // Cập nhật trạng thái trong UI
          for (var msgId in messagesToMarkAsRead) {
            final index = newMessages.indexWhere((msg) => msg.id == msgId);
            if (index != -1) {
              newMessages[index].status = "read";
            }
          }
        }

        if (isLoadMore) {
          messages.addAll(newMessages);
        } else {
          messages = newMessages;
        }
        currentPage = result['currentPage'];
        totalPages = result['totalPages'];
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Không thể tải tin nhắn: ${result['message']}")),
      );
    }

    setState(() {
      isFetchingMoreMessages = false;
    });
  }

  void _sendMessage({String? messageText, String type = "text", String? contentUrl}) {
    final msg = messageText ?? _controller.text.trim();
    if (msg.isEmpty && contentUrl == null) return;

    // Tạo một tin nhắn tạm thời để hiển thị ngay lập tức
    final tempMessage = MessageModel(
      message: msg,
      sourceEmail: widget.sourchat.email,
      targetEmail: widget.chatModel.isGroup ? "" : widget.chatModel.email, // Rỗng nếu là nhóm
      groupId: widget.chatModel.isGroup ? widget.chatModel.groupId : null, // Gán groupId nếu là nhóm
      groupName: widget.chatModel.isGroup ? widget.chatModel.name : null,
      senderName: widget.sourchat.name, // Tên người gửi
      timestamp: DateTime.now(),
      isMe: true,
      type: type,
      contentUrl: contentUrl,
      status: "sent", // Trạng thái ban đầu
    );

    socket.emit("message", {
      "message": msg,
      "sourceEmail": widget.sourchat.email,
      "targetEmail": widget.chatModel.isGroup ? null : widget.chatModel.email, // null nếu là nhóm
      "groupId": widget.chatModel.isGroup ? widget.chatModel.groupId : null, // Gửi groupId nếu là nhóm
      "type": type,
      "contentUrl": contentUrl,
    });

    setState(() {
      messages.add(tempMessage); // Đã sửa: Thêm vào cuối danh sách
    });
    _controller.clear();

    // Tắt trạng thái typing
    if (widget.chatModel.isGroup) {
      socket.emit("typing", {
        "groupId": widget.chatModel.groupId,
        "isTyping": false,
      });
    } else {
      socket.emit("typing", {
        "targetEmail": widget.chatModel.email,
        "isTyping": false,
      });
    }

    if (showEmojiPicker) {
      setState(() {
        showEmojiPicker = false;
      });
    }
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent, // Đã sửa: Cuộn xuống cuối
      duration: Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _toggleEmojiPicker() {
    setState(() {
      showEmojiPicker = !showEmojiPicker;
    });
    if (showEmojiPicker) {
      FocusScope.of(context).unfocus();
    }
  }

  void _showChatInfo() {
    // Nếu là nhóm, có thể hiển thị thông tin nhóm
    // Nếu là cá nhân, hiển thị thông tin người dùng
    if (widget.chatModel.isGroup) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Thông tin nhóm sẽ được phát triển.")),
      );
      // TODO: Navigate to GroupInfoPage
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => UserProfilePage(userEmail: widget.chatModel.email),
        ),
      );
    }
  }

  void _clearChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Xóa tin nhắn"),
        content: Text("Bạn có chắc chắn muốn xóa tất cả tin nhắn với ${widget.chatModel.name}? Hành động này sẽ xóa tin nhắn trên cả server."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Hủy"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Đóng dialog
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Đang xóa tin nhắn...")),
              );
              // Sử dụng userId hoặc groupId tùy thuộc vào loại chat
              final String chatIdToDelete = widget.chatModel.isGroup ? widget.chatModel.groupId! : widget.chatModel.userId!;
              final result = await AuthService.deleteChatHistory(chatIdToDelete);
              if (result['success']) {
                setState(() {
                  messages.clear(); // Xóa tin nhắn cục bộ
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Đã xóa tất cả tin nhắn!")),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Xóa tin nhắn thất bại: ${result['message']}")),
                );
              }
            },
            child: Text("Xóa", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: source);
    if (image != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Đang tải ảnh lên...")),
      );
      final uploadResult = await AuthService.uploadFile(image.path);
      if (uploadResult['success']) {
        _sendMessage(
          messageText: "Đã gửi ảnh",
          type: "image",
          contentUrl: uploadResult['url'],
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Đã gửi ảnh!")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Tải ảnh lên thất bại: ${uploadResult['message']}")),
        );
      }
    }
  }

  Future<void> _pickAndSendFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      PlatformFile file = result.files.first;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Đang tải file lên...")),
      );
      final uploadResult = await AuthService.uploadFile(file.path!);
      if (uploadResult['success']) {
        _sendMessage(
          messageText: "Đã gửi file: ${file.name}",
          type: "file",
          contentUrl: uploadResult['url'],
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Đã gửi file!")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Tải file lên thất bại: ${uploadResult['message']}")),
        );
      }
    }
  }

  Future<void> _sendLocation() async {
    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Quyền truy cập vị trí bị từ chối.")),
      );
      return;
    }
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final locationMessage = "Vị trí của tôi: Lat ${position.latitude}, Lon ${position.longitude}";
      final mapUrl = "https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}";
      _sendMessage(
        messageText: locationMessage,
        type: "location",
        contentUrl: mapUrl,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Đã gửi vị trí.")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Không thể lấy vị trí: $e")),
      );
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Đính kèm",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAttachmentOption(
                  icon: Icons.image,
                  label: "Ảnh",
                  color: Colors.purple,
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndSendImage(ImageSource.gallery);
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.insert_drive_file,
                  label: "Tài liệu",
                  color: Colors.blue,
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndSendFile();
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.location_on,
                  label: "Vị trí",
                  color: Colors.green,
                  onTap: () {
                    Navigator.pop(context);
                    _sendLocation();
                  },
                ),
              ],
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 30,
            ),
          ),
          SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent(MessageModel message) {
    switch (message.type) {
      case "image":
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.contentUrl != null && message.contentUrl!.isNotEmpty)
              GestureDetector(
                onTap: () async {
                  if (await canLaunchUrl(Uri.parse(message.contentUrl!))) {
                    await launchUrl(Uri.parse(message.contentUrl!));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Không thể mở ảnh.")),
                    );
                  }
                },
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.6, // Giới hạn kích thước ảnh
                    maxHeight: MediaQuery.of(context).size.height * 0.4,
                  ),
                  child: Image.network(
                    message.contentUrl!,
                    fit: BoxFit.contain, // Đảm bảo ảnh hiển thị đầy đủ
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey[300],
                      width: 150,
                      height: 150,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image, size: 50, color: Colors.grey[600]),
                            Text("Lỗi tải ảnh", style: TextStyle(color: Colors.grey[600])),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (message.message.isNotEmpty) Text(message.message, style: TextStyle(fontSize: 16)),
          ],
        );
      case "location":
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message.message, style: TextStyle(fontSize: 16)),
            if (message.contentUrl != null && message.contentUrl!.isNotEmpty)
              GestureDetector(
                onTap: () async {
                  if (await canLaunchUrl(Uri.parse(message.contentUrl!))) {
                    await launchUrl(Uri.parse(message.contentUrl!));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Không thể mở bản đồ.")),
                    );
                  }
                },
                child: Text(
                  "Xem trên bản đồ",
                  style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                ),
              ),
          ],
        );
      case "file":
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message.message, style: TextStyle(fontSize: 16)),
            if (message.contentUrl != null && message.contentUrl!.isNotEmpty)
              GestureDetector(
                onTap: () async {
                  if (await canLaunchUrl(Uri.parse(message.contentUrl!))) {
                    await launchUrl(Uri.parse(message.contentUrl!));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Không thể mở file.")),
                    );
                  }
                },
                child: Text(
                  "Tải xuống file",
                  style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                ),
              ),
          ],
        );
      default: // "text"
        return Text(message.message, style: TextStyle(fontSize: 16));
    }
  }

  Icon _getMessageStatusIcon(String status) {
    switch (status) {
      case "sent":
        return Icon(Icons.done, size: 16, color: Colors.grey); // Một dấu tích
      case "delivered":
        return Icon(Icons.done_all, size: 16, color: Colors.grey); // Hai dấu tích
      case "read":
        return Icon(Icons.done_all, size: 16, color: Colors.blue); // Hai dấu tích màu xanh
      default:
        return Icon(Icons.hourglass_empty, size: 16, color: Colors.grey); // Trạng thái không xác định
    }
  }

  String _getTypingStatusText() {
    if (widget.chatModel.isGroup) {
      final typingUsers = groupTypingStatus.keys.where((email) => groupTypingStatus[email] == true).toList();
      if (typingUsers.isEmpty) {
        return "Đang hoạt động";
      } else if (typingUsers.length == 1) {
        // Tìm tên người dùng từ email
        final typingUserName = widget.chatModel.members?.firstWhere(
              (member) => member['email'] == typingUsers[0],
          orElse: () => null,
        )?['name'] ?? typingUsers[0];
        return "$typingUserName đang gõ...";
      } else {
        return "${typingUsers.length} người đang gõ...";
      }
    } else {
      return isTargetTyping ? "Đang gõ..." : "Đang hoạt động";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF075E54),
        foregroundColor: Colors.white,
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white,
              backgroundImage: widget.chatModel.profilePictureUrl != null && widget.chatModel.profilePictureUrl!.isNotEmpty
                  ? NetworkImage(widget.chatModel.profilePictureUrl!)
                  : null,
              child: (widget.chatModel.profilePictureUrl == null || widget.chatModel.profilePictureUrl!.isEmpty)
                  ? Icon(
                widget.chatModel.isGroup ? Icons.group : Icons.person,
                color: Color(0xFF075E54),
              )
                  : null,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.chatModel.name,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _getTypingStatusText(),
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.videocam),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Tính năng video call sẽ được phát triển")),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.call),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Tính năng voice call sẽ được phát triển")),
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'info':
                  _showChatInfo();
                  break;
                case 'clear':
                  _clearChat();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'info',
                child: Row(
                  children: [
                    Icon(Icons.info, size: 20),
                    SizedBox(width: 10),
                    Text("Thông tin"),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.clear_all, size: 20),
                    SizedBox(width: 10),
                    Text("Xóa tin nhắn"),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
              ),
              child: ListView.builder(
                controller: _scrollController,
                reverse: false, // Đã sửa: Hiển thị tin nhắn theo thứ tự bình thường
                padding: EdgeInsets.all(10),
                itemCount: messages.length + (isFetchingMoreMessages ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == messages.length && isFetchingMoreMessages) {
                    return Center(child: CircularProgressIndicator());
                  }
                  final message = messages[index]; // Lấy tin nhắn từ danh sách
                  final isMe = message.isMe;
                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: EdgeInsets.symmetric(vertical: 5),
                      padding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                      decoration: BoxDecoration(
                        color: isMe ? Color(0xFFDCF8C6) : Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            spreadRadius: 1,
                            blurRadius: 2,
                          ),
                        ],
                      ),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.7,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (widget.chatModel.isGroup && !isMe) // Hiển thị tên người gửi trong nhóm nếu không phải mình
                            Text(
                              message.senderName ?? message.sourceEmail,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey,
                              ),
                            ),
                          _buildMessageContent(message),
                          SizedBox(height: 5),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              if (isMe) ...[
                                SizedBox(width: 5),
                                _getMessageStatusIcon(message.status), // Hiển thị trạng thái tin nhắn
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.all(10),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            showEmojiPicker
                                ? Icons.keyboard
                                : Icons.emoji_emotions_outlined,
                            color: Color(0xFF075E54),
                          ),
                          onPressed: _toggleEmojiPicker,
                        ),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            decoration: InputDecoration(
                              hintText: "Nhập tin nhắn...",
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 10),
                            ),
                            onChanged: (value) {
                              // Gửi trạng thái typing
                              if (widget.chatModel.isGroup) {
                                socket.emit("typing", {
                                  "groupId": widget.chatModel.groupId,
                                  "isTyping": value.isNotEmpty,
                                });
                              } else {
                                socket.emit("typing", {
                                  "targetEmail": widget.chatModel.email,
                                  "isTyping": value.isNotEmpty,
                                });
                              }
                            },
                            onSubmitted: (value) => _sendMessage(messageText: value),
                            onTap: () {
                              if (showEmojiPicker) {
                                setState(() {
                                  showEmojiPicker = false;
                                });
                              }
                            },
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.attach_file, color: Color(0xFF075E54)),
                          onPressed: () {
                            _showAttachmentOptions();
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.camera_alt, color: Color(0xFF075E54)),
                          onPressed: () {
                            _pickAndSendImage(ImageSource.camera);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 10),
                FloatingActionButton(
                  mini: true,
                  backgroundColor: Color(0xFF075E54),
                  onPressed: () => _sendMessage(messageText: _controller.text),
                  child: Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          ),
          if (showEmojiPicker)
            Container(
              height: 250,
              child: EmojiPicker(
                onEmojiSelected: (category, emoji) {
                  setState(() {
                    _controller.text += emoji.emoji;
                  });
                },
                config: const Config(
                  height: 256,
                  checkPlatformCompatibility: true,
                  emojiViewConfig: EmojiViewConfig(
                    emojiSizeMax: 28,
                  ),
                  skinToneConfig: SkinToneConfig(),
                  categoryViewConfig: CategoryViewConfig(),
                  bottomActionBarConfig: BottomActionBarConfig(),
                  searchViewConfig: SearchViewConfig(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    // Tắt trạng thái typing khi rời khỏi màn hình
    if (widget.chatModel.isGroup) {
      socket.emit("typing", {
        "groupId": widget.chatModel.groupId,
        "isTyping": false,
      });
    } else {
      socket.emit("typing", {
        "targetEmail": widget.chatModel.email,
        "isTyping": false,
      });
    }
    socket.off("message");
    socket.off("typing");
    socket.off("message_status_update");
    super.dispose();
    //
  }
}
