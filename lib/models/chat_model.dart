class ChatModel {
  String name;
  String icon;
  bool isGroup;
  String time;
  String currentMessage;
  String status;
  int id;
  String email;
  String? profilePictureUrl;
  String? userId; // THÊM TRƯỜNG NÀY để lưu _id từ MongoDB
  String? groupId; // THÊM TRƯỜNG NÀY để lưu _id của nhóm
  List<dynamic>? members; // THÊM TRƯỜNG NÀY để lưu thành viên nhóm

  ChatModel({
    required this.name,
    required this.icon,
    required this.isGroup,
    required this.time,
    required this.currentMessage,
    required this.status,
    required this.id,
    required this.email,
    this.profilePictureUrl,
    this.userId, // Cho phép null
    this.groupId, // Cho phép null
    this.members, // Cho phép null
  });
}
