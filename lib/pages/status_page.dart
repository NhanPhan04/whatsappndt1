import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // Để chọn ảnh/video cho trạng thái
import 'package:file_picker/file_picker.dart';
import '../services/auth_service.dart';
import 'package:timeago/timeago.dart' as timeago; // Thêm thư viện timeago

class StatusPage extends StatefulWidget {
  final String sourceUserId;

  const StatusPage({Key? key, required this.sourceUserId}) : super(key: key);

  @override
  _StatusPageState createState() => _StatusPageState();
}

class _StatusPageState extends State<StatusPage> {
  List<dynamic> myStatuses = [];
  List<dynamic> friendStatuses = [];
  bool isLoadingMyStatuses = true;
  bool isLoadingFriendStatuses = true;
  String myStatusError = "";
  String friendStatusError = "";

  int currentPage = 1;
  int totalPages = 1;
  bool isFetchingMore = false;

  @override
  void initState() {
    super.initState();
    _fetchMyStatuses();
    _fetchFriendStatuses();
  }

  Future<void> _fetchMyStatuses() async {
    setState(() {
      isLoadingMyStatuses = true;
      myStatusError = "";
    });
    try {
      final result = await AuthService.fetchMyStatuses();
      if (result['success']) {
        setState(() {
          myStatuses = result['statuses'];
        });
      } else {
        setState(() {
          myStatusError = result['message'] ?? "Không thể tải trạng thái của tôi.";
        });
      }
    } catch (e) {
      setState(() {
        myStatusError = "Lỗi kết nối: $e";
      });
    } finally {
      setState(() {
        isLoadingMyStatuses = false;
      });
    }
  }

  Future<void> _fetchFriendStatuses({bool isLoadMore = false}) async {
    if (isLoadMore && currentPage >= totalPages) return;

    setState(() {
      if (isLoadMore) {
        isFetchingMore = true;
      } else {
        isLoadingFriendStatuses = true;
        friendStatusError = "";
      }
    });

    try {
      final result = await AuthService.fetchStatuses(page: isLoadMore ? currentPage + 1 : 1, limit: 10);
      if (result['success']) {
        setState(() {
          final newStatuses = result['statuses'];
          if (isLoadMore) {
            friendStatuses.addAll(newStatuses);
          } else {
            friendStatuses = newStatuses;
          }
          currentPage = result['currentPage'];
          totalPages = result['totalPages'];
        });
      } else {
        setState(() {
          friendStatusError = result['message'] ?? "Không thể tải trạng thái bạn bè.";
        });
      }
    } catch (e) {
      setState(() {
        friendStatusError = "Lỗi kết nối: $e";
      });
    } finally {
      setState(() {
        isLoadingFriendStatuses = false;
        isFetchingMore = false;
      });
    }
  }

  Future<void> _addMyStatus(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.text_fields),
              title: Text("Trạng thái văn bản"),
              onTap: () {
                Navigator.pop(context);
                _showTextStatusDialog();
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library),
              title: Text("Chọn ảnh từ thư viện"),
              onTap: () async {
                Navigator.pop(context);
                await _pickAndPostMediaStatus(ImageSource.gallery, "image");
              },
            ),
            ListTile(
              leading: Icon(Icons.camera_alt),
              title: Text("Chụp ảnh mới"),
              onTap: () async {
                Navigator.pop(context);
                await _pickAndPostMediaStatus(ImageSource.camera, "image");
              },
            ),
            ListTile(
              leading: Icon(Icons.videocam),
              title: Text("Quay video mới"),
              onTap: () async {
                Navigator.pop(context);
                await _pickAndPostMediaStatus(ImageSource.camera, "video");
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTextStatusDialog() async {
    TextEditingController textController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Bạn đang nghĩ gì?"),
        content: TextField(
          controller: textController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: "Nhập trạng thái của bạn...",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Hủy"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              if (textController.text.trim().isNotEmpty) {
                await _postStatus("text", content: textController.text.trim());
              }
            },
            child: Text("Đăng"),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndPostMediaStatus(ImageSource source, String type) async {
    final ImagePicker _picker = ImagePicker();
    XFile? mediaFile;

    if (type == "image") {
      mediaFile = await _picker.pickImage(source: source);
    } else if (type == "video") {
      mediaFile = await _picker.pickVideo(source: source);
    }

    if (mediaFile != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Đang tải ${type} trạng thái lên...")),
      );
      final uploadResult = await AuthService.uploadFile(mediaFile.path);
      if (uploadResult['success']) {
        await _postStatus(type, mediaUrl: uploadResult['url']);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Đã đăng ${type} trạng thái!")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Tải ${type} lên thất bại: ${uploadResult['message']}")),
        );
      }
    }
  }

  Future<void> _postStatus(String type, {String? content, String? mediaUrl}) async {
    final result = await AuthService.postStatus(type, content: content, mediaUrl: mediaUrl);
    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Đăng trạng thái thành công!")),
      );
      _fetchMyStatuses(); // Tải lại trạng thái của tôi
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Đăng trạng thái thất bại: ${result['message']}")),
      );
    }
  }

  void _showPrivacySettings(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Tính năng cài đặt quyền riêng tư trạng thái sẽ được phát triển.")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.grey[300],
                        backgroundImage: myStatuses.isNotEmpty && myStatuses[0]['mediaUrl'] != null && myStatuses[0]['mediaUrl'].isNotEmpty
                            ? NetworkImage(myStatuses[0]['mediaUrl'])
                            : null,
                        child: myStatuses.isEmpty || (myStatuses.isNotEmpty && (myStatuses[0]['mediaUrl'] == null || myStatuses[0]['mediaUrl'].isEmpty))
                            ? Icon(Icons.person, size: 40, color: Colors.grey[600])
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          radius: 10,
                          backgroundColor: Color(0xFF075E54),
                          child: Icon(Icons.add, size: 15, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Trạng thái của tôi",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        isLoadingMyStatuses
                            ? Text("Đang tải...", style: TextStyle(fontSize: 14, color: Colors.grey[600]))
                            : myStatusError.isNotEmpty
                            ? Text(myStatusError, style: TextStyle(fontSize: 14, color: Colors.red))
                            : myStatuses.isEmpty
                            ? Text(
                          "Nhấn để thêm trạng thái",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        )
                            : Text(
                          myStatuses[0]['type'] == 'text'
                              ? myStatuses[0]['content']
                              : "Cập nhật ${timeago.format(DateTime.parse(myStatuses[0]['createdAt']))}",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.more_vert),
                    onPressed: () => _showPrivacySettings(context),
                  ),
                ],
              ),
            ),
            Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                "Cập nhật gần đây",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
            ),
            isLoadingFriendStatuses && friendStatuses.isEmpty
                ? Center(child: CircularProgressIndicator())
                : friendStatusError.isNotEmpty
                ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(friendStatusError, style: TextStyle(color: Colors.red)),
                    SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _fetchFriendStatuses,
                      child: Text("Thử lại"),
                    ),
                  ],
                ),
              ),
            )
                : ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: friendStatuses.length + (isFetchingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == friendStatuses.length) {
                  if (currentPage < totalPages) {
                    _fetchFriendStatuses(isLoadMore: true);
                    return Center(child: CircularProgressIndicator());
                  } else {
                    return SizedBox.shrink();
                  }
                }
                final status = friendStatuses[index];
                final user = status['user'];
                return ListTile(
                  leading: CircleAvatar(
                    radius: 25,
                    backgroundColor: Colors.blueGrey,
                    backgroundImage: user['profilePictureUrl'] != null && user['profilePictureUrl'].isNotEmpty
                        ? NetworkImage(user['profilePictureUrl'])
                        : null,
                    child: (user['profilePictureUrl'] == null || user['profilePictureUrl'].isEmpty)
                        ? Icon(Icons.person, color: Colors.white)
                        : null,
                  ),
                  title: Text(user['name'] ?? user['email']),
                  subtitle: Text(
                    status['type'] == 'text'
                        ? status['content']
                        : "Cập nhật ${timeago.format(DateTime.parse(status['createdAt']))}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Xem trạng thái của ${user['name']} sẽ được phát triển")),
                    );
                    // TODO: Mở màn hình xem trạng thái chi tiết
                  },
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addMyStatus(context),
        backgroundColor: Color(0xFF075E54),
        child: Icon(Icons.camera_alt, color: Colors.white),
      ),
    );
  }
}
