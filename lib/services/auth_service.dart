import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:path/path.dart';

class AuthService {
  static const String baseUrl = 'http://localhost:3000/api';
  static const String socketUrl = 'http://localhost:3000';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static IO.Socket? _socket;

  static IO.Socket getSocket() {
    if (_socket == null) {
      _socket = IO.io(socketUrl, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
      });
      _socket!.onConnect((_) => print('🔌 Socket Connected'));
      _socket!.onDisconnect((_) => print('🔌 Socket Disconnected'));
      _socket!.onError((error) => print('🔌 Socket Error: $error'));
    }
    return _socket!;
  }

  static Future<bool> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(Duration(seconds: 10));

      print('🔍 Health check: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('📊 Server info: ${data}');
      }
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Connection error: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>> sendOTP(String email) async {
    try {
      print('📱 Sending REAL OTP to email: $email');

      final response = await http.post(
        Uri.parse('$baseUrl/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
        }),
      ).timeout(Duration(seconds: 30));

      print('📤 OTP Response: ${response.statusCode}');
      print('📤 Response body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'OTP đã được gửi',
          'email': data['email'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Lỗi không xác định',
          'error': data['error'],
          'code': data['code'],
          'suggestion': data['suggestion'],
        };
      }
    } catch (e) {
      print('❌ Send OTP error: $e');
      return {
        'success': false,
        'message': 'Lỗi kết nối: $e',
        'suggestion': 'Kiểm tra kết nối internet và thử lại',
      };
    }
  }

  static Future<Map<String, dynamic>> sendTestOTP(String email) async {
    try {
      print('🧪 Creating test OTP for email: $email');

      final response = await http.post(
        Uri.parse('$baseUrl/test-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
        }),
      );

      final data = jsonDecode(response.body);

      return {
        'success': response.statusCode == 200,
        'message': data['message'] ?? 'Unknown error',
        'testOtp': data['testOtp'],
        'email': data['email'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Lỗi kết nối: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> verifyOTP(
      String email,
      String countryCode,
      String otp,
      ) async {
    try {
      print('🔐 Verifying OTP: $otp for email: $email');

      final response = await http.post(
        Uri.parse('$baseUrl/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'otp': otp,
        }),
      );

      print('🔐 Verify Response: ${response.statusCode} - ${response.body}');
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        await saveUserData(data['token'], data['user']);
        print('✅ Authentication successful');
      }

      return {
        'success': response.statusCode == 200,
        'message': data['message'] ?? 'Unknown error',
        'token': data['token'],
        'user': data['user'],
        'attemptsLeft': data['attemptsLeft'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Lỗi kết nối: $e',
      };
    }
  }

  static Future<String?> getToken() async {
    return await _storage.read(key: 'auth_token');
  }

  static Future<Map<String, dynamic>?> getUserData() async {
    final userDataString = await _storage.read(key: 'user_data');
    if (userDataString != null) {
      return jsonDecode(userDataString);
    }
    return null;
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  static Future<void> logout() async {
    await _storage.delete(key: 'auth_token');
    await _storage.delete(key: 'user_data');
    _socket?.disconnect();
    print('👋 User logged out');
  }

  static Future<void> saveUserData(String token, Map<String, dynamic> userData) async {
    await _storage.write(key: 'auth_token', value: token);
    await _storage.write(key: 'user_data', value: jsonEncode(userData));
  }

  static Future<Map<String, dynamic>> fetchUserProfile() async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Không có token xác thực'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200,
        'message': data['message'] ?? 'Unknown error',
        'user': data['user'],
      };
    } catch (e) {
      print('❌ Fetch profile error: $e');
      return {'success': false, 'message': 'Lỗi kết nối: $e'};
    }
  }

  static Future<Map<String, dynamic>> updateProfile(String? name, String? status, String? profilePictureUrl) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Không có token xác thực'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/profile/update'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': name,
          'status': status,
          'profilePictureUrl': profilePictureUrl,
        }),
      );

      final data = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200,
        'message': data['message'] ?? 'Unknown error',
        'user': data['user'],
      };
    } catch (e) {
      print('❌ Update profile error: $e');
      return {'success': false, 'message': 'Lỗi kết nối: $e'};
    }
  }

  static Future<Map<String, dynamic>> fetchUsers({int page = 1, int limit = 10}) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Không có token xác thực'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/users?page=$page&limit=$limit'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200,
        'message': data['message'] ?? 'Unknown error',
        'users': data['users'],
        'currentPage': data['currentPage'],
        'totalPages': data['totalPages'],
        'totalUsers': data['totalUsers'],
      };
    } catch (e) {
      print('❌ Fetch users error: $e');
      return {'success': false, 'message': 'Lỗi kết nối: $e'};
    }
  }

  static Future<Map<String, dynamic>> uploadFile(String filePath) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Không có token xác thực'};
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/upload/file'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath('file', filePath, filename: basename(filePath)));

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();
      final data = jsonDecode(responseBody);

      if (response.statusCode == 200) {
        return {'success': true, 'url': data['url'], 'message': data['message']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Lỗi upload file'};
      }
    } catch (e) {
      print('❌ Upload file error: $e');
      return {'success': false, 'message': 'Lỗi kết nối hoặc upload file: $e'};
    }
  }

  // --- API mới cho Tin nhắn (Chat History) ---
  static Future<Map<String, dynamic>> fetchMessages(String chatId, {int page = 1, int limit = 30}) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Không có token xác thực'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/messages/$chatId?page=$page&limit=$limit'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200,
        'message': data['message'] ?? 'Unknown error',
        'messages': data['messages'],
        'currentPage': data['currentPage'],
        'totalPages': data['totalPages'],
        'totalMessages': data['totalMessages'],
      };
    } catch (e) {
      print('❌ Fetch messages error: $e');
      return {'success': false, 'message': 'Lỗi kết nối: $e'};
    }
  }

  static Future<Map<String, dynamic>> markMessagesAsRead(List<String> messageIds) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Không có token xác thực'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/messages/read'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'messageIds': messageIds}),
      );

      final data = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200,
        'message': data['message'] ?? 'Unknown error',
      };
    } catch (e) {
      print('❌ Mark messages as read error: $e');
      return {'success': false, 'message': 'Lỗi kết nối: $e'};
    }
  }

  static Future<Map<String, dynamic>> deleteChatHistory(String chatId) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Không có token xác thực'};
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/messages/$chatId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200,
        'message': data['message'] ?? 'Unknown error',
      };
    } catch (e) {
      print('❌ Delete chat history error: $e');
      return {'success': false, 'message': 'Lỗi kết nối: $e'};
    }
  }

  // --- API mới cho Trạng thái (Status) ---
  static Future<Map<String, dynamic>> postStatus(String type, {String? content, String? mediaUrl}) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Không có token xác thực'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'type': type,
          'content': content,
          'mediaUrl': mediaUrl,
        }),
      );

      final data = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200,
        'message': data['message'] ?? 'Unknown error',
        'status': data['status'],
      };
    } catch (e) {
      print('❌ Post status error: $e');
      return {'success': false, 'message': 'Lỗi kết nối: $e'};
    }
  }

  static Future<Map<String, dynamic>> fetchStatuses({int page = 1, int limit = 10}) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Không có token xác thực'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/statuses?page=$page&limit=$limit'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200,
        'message': data['message'] ?? 'Unknown error',
        'statuses': data['statuses'],
        'currentPage': data['currentPage'],
        'totalPages': data['totalPages'],
        'totalStatuses': data['totalStatuses'],
      };
    } catch (e) {
      print('❌ Fetch statuses error: $e');
      return {'success': false, 'message': 'Lỗi kết nối: $e'};
    }
  }

  static Future<Map<String, dynamic>> fetchMyStatuses() async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Không có token xác thực'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/my-statuses'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200,
        'message': data['message'] ?? 'Unknown error',
        'statuses': data['statuses'],
      };
    } catch (e) {
      print('❌ Fetch my statuses error: $e');
      return {'success': false, 'message': 'Lỗi kết nối: $e'};
    }
  }

  // --- API mới cho Cuộc gọi (Call History) ---
  static Future<Map<String, dynamic>> logCall(String receiverEmail, String callType, String callStatus, {int duration = 0}) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Không có token xác thực'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/calls/log'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'receiverEmail': receiverEmail,
          'callType': callType,
          'callStatus': callStatus,
          'duration': duration,
        }),
      );

      final data = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200,
        'message': data['message'] ?? 'Unknown error',
        'call': data['call'],
      };
    } catch (e) {
      print('❌ Log call error: $e');
      return {'success': false, 'message': 'Lỗi kết nối: $e'};
    }
  }

  static Future<Map<String, dynamic>> fetchCalls({int page = 1, int limit = 10, String? type, String? date}) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Không có token xác thực'};
      }

      String queryParams = '?page=$page&limit=$limit';
      if (type != null && type.isNotEmpty) {
        queryParams += '&type=$type';
      }
      if (date != null && date.isNotEmpty) {
        queryParams += '&date=$date';
      }

      final response = await http.get(
        Uri.parse('$baseUrl/calls$queryParams'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200,
        'message': data['message'] ?? 'Unknown error',
        'calls': data['calls'],
        'currentPage': data['currentPage'],
        'totalPages': data['totalPages'],
        'totalCalls': data['totalCalls'],
      };
    } catch (e) {
      print('❌ Fetch calls error: $e');
      return {'success': false, 'message': 'Lỗi kết nối: $e'};
    }
  }

  // --- API mới cho Nhóm chat (Group Chat) ---
  static Future<Map<String, dynamic>> createGroup(String name, List<String> memberIds, {String? description, String? profilePictureUrl}) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Không có token xác thực'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/groups'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': name,
          'memberIds': memberIds,
          'description': description,
          'profilePictureUrl': profilePictureUrl,
        }),
      );

      final data = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200,
        'message': data['message'] ?? 'Unknown error',
        'group': data['group'],
      };
    } catch (e) {
      print('❌ Create group error: $e');
      return {'success': false, 'message': 'Lỗi kết nối: $e'};
    }
  }

  static Future<Map<String, dynamic>> fetchGroups({int page = 1, int limit = 10}) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Không có token xác thực'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/groups?page=$page&limit=$limit'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200,
        'message': data['message'] ?? 'Unknown error',
        'groups': data['groups'],
        'currentPage': data['currentPage'],
        'totalPages': data['totalPages'],
        'totalGroups': data['totalGroups'],
      };
    } catch (e) {
      print('❌ Fetch groups error: $e');
      return {'success': false, 'message': 'Lỗi kết nối: $e'};
    }
  }
}
