class MessageModel {
  String? id; // THÊM TRƯỜNG NÀY để lưu _id từ MongoDB
  String message;
  String sourceEmail;
  String targetEmail; // Vẫn giữ cho tin nhắn cá nhân
  String? groupId; // THÊM TRƯỜNG NÀY cho tin nhắn nhóm
  String? groupName; // THÊM TRƯỜNG NÀY cho tin nhắn nhóm
  String? senderName; // THÊM TRƯỜNG NÀY để hiển thị tên người gửi trong nhóm
  DateTime timestamp;
  bool isMe;
  String type;
  String? contentUrl;
  String status; // THÊM TRƯỜNG NÀY: "sent", "delivered", "read"

  MessageModel({
    this.id, // Cho phép null khi tạo mới trên client
    required this.message,
    required this.sourceEmail,
    required this.timestamp,
    this.targetEmail = "", // Mặc định rỗng nếu là tin nhắn nhóm
    this.groupId,
    this.groupName,
    this.senderName,
    this.isMe = false,
    this.type = "text",
    this.contentUrl,
    this.status = "sent", // Mặc định là "sent"
  });

  factory MessageModel.fromJson(Map<String, dynamic> json, String currentLoggedInUserEmail) {
    final isGroupMessage = json['group'] != null;

    return MessageModel(
      id: json['_id'], // Lấy _id từ JSON
      message: json['content'], // Backend dùng 'content' thay vì 'message'
      sourceEmail: json['sender']['email'], // Lấy email từ đối tượng sender đã populate
      targetEmail: isGroupMessage ? "" : json['receiver']['email'], // Rỗng nếu là nhóm
      groupId: isGroupMessage ? json['group']['_id'] : null, // Lấy groupId nếu là nhóm
      groupName: isGroupMessage ? json['group']['name'] : null, // Lấy tên nhóm nếu là nhóm
      senderName: json['sender']['name'], // Lấy tên người gửi
      timestamp: DateTime.parse(json['createdAt']), // Backend dùng 'createdAt'
      isMe: json['sender']['email'] == currentLoggedInUserEmail,
      type: json['type'] ?? "text",
      contentUrl: json['contentUrl'],
      status: json['status'] ?? "sent", // Lấy trạng thái
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'message': message,
      'sourceEmail': sourceEmail,
      'targetEmail': targetEmail,
      'groupId': groupId,
      'groupName': groupName,
      'senderName': senderName,
      'timestamp': timestamp.toIso8601String(),
      'isMe': isMe,
      'type': type,
      'contentUrl': contentUrl,
      'status': status,
    };
  }
}
