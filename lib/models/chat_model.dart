class ChatModel {
  final String name;
  final String icon;
  final bool isGroup;
  final String time;
  final String email;
  String currentMessage;
  String status;
  int id;
  String? profilePictureUrl;
  String? userId; // For individual chats
  String? groupId; // For group chats
  List<dynamic>? members; // For group chats
  DateTime? lastMessageAt; // New field
  String? lastMessageContent; // New field

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
    this.userId,
    this.groupId,
    this.members,
    this.lastMessageAt, // New
    this.lastMessageContent, // New
  });
}
