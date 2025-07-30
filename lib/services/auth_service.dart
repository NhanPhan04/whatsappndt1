import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // Đã cập nhật baseUrl và socketUrl theo yêu cầu của bạn
  static const String baseUrl = 'http://192.168.2.34:3000/api';
  static const String socketUrl = 'http://192.168.2.34:3000'; // Base URL cho các tài nguyên tĩnh

  static String? _token;
  static Map<String, dynamic>? _currentUserData;
  static IO.Socket? _socket;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    final userDataString = prefs.getString('userData');
    if (userDataString != null) {
      _currentUserData = jsonDecode(userDataString);
    }
  }

  static IO.Socket getSocket() {
    _socket ??= IO.io(socketUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });
    return _socket!;
  }

  static String? getToken() {
    return _token;
  }

  static Map<String, dynamic>? getCurrentUserData() {
    return _currentUserData;
  }

  static bool isLoggedIn() {
    return _token != null && _currentUserData != null;
  }

  static Future<void> saveUserData(String token, Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    _token = token;
    _currentUserData = userData;
    await prefs.setString('token', token);
    await prefs.setString('userData', jsonEncode(userData));
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('userData');
    _token = null;
    _currentUserData = null;
    _socket?.disconnect();
    _socket = null;
  }

  static Future<Map<String, dynamic>> sendOTP(String email) async {
    final response = await http.post(
      Uri.parse('$baseUrl/send-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> sendTestOTP(String email) async {
    final response = await http.post(
      Uri.parse('$baseUrl/test-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> verifyOTP(String email, String otp) async {
    final response = await http.post(
      Uri.parse('$baseUrl/verify-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'otp': otp}),
    );
    final data = jsonDecode(response.body);
    if (data['success']) {
      await saveUserData(data['token'], data['user']);
    }
    return data;
  }

  static Future<Map<String, dynamic>> fetchUserProfile() async {
    if (_token == null) {
      return {'success': false, 'message': 'No token found'};
    }
    final response = await http.get(
      Uri.parse('$baseUrl/profile'),
      headers: {'Authorization': 'Bearer $_token'},
    );
    final data = jsonDecode(response.body);
    if (data['success']) {
      _currentUserData = data['user'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userData', jsonEncode(data['user']));
    }
    return data;
  }

  static Future<Map<String, dynamic>> updateProfile(String name, String status, String? profilePictureUrl) async {
    if (_token == null) {
      return {'success': false, 'message': 'No token found'};
    }
    final response = await http.post(
      Uri.parse('$baseUrl/profile/update'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      },
      body: jsonEncode({
        'name': name,
        'status': status,
        'profilePictureUrl': profilePictureUrl,
      }),
    );
    final data = jsonDecode(response.body);
    if (data['success']) {
      await fetchUserProfile();
    }
    return data;
  }

  static Future<Map<String, dynamic>> fetchUsers({int page = 1, int limit = 1000, String? searchQuery, bool excludeVirtual = false}) async {
    if (_token == null) {
      return {'success': false, 'message': 'No token found'};
    }
    String queryParams = '?page=$page&limit=$limit';
    if (searchQuery != null && searchQuery.isNotEmpty) {
      queryParams += '&search=$searchQuery';
    }
    if (excludeVirtual) {
      queryParams += '&excludeVirtual=true';
    }
    final response = await http.get(
      Uri.parse('$baseUrl/users$queryParams'),
      headers: {'Authorization': 'Bearer $_token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load users: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> uploadFile(String filePath) async {
    if (_token == null) {
      return {'success': false, 'message': 'No token found'};
    }
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/upload/file'),
    );
    request.headers['Authorization'] = 'Bearer $_token';
    request.files.add(await http.MultipartFile.fromPath('file', filePath));

    var response = await request.send();
    var responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      return jsonDecode(responseBody);
    } else {
      throw Exception('Failed to upload file: $responseBody');
    }
  }

  static Future<Map<String, dynamic>> fetchMessages(String chatId, {int page = 1, int limit = 30}) async {
    if (_token == null) {
      return {'success': false, 'message': 'No token found'};
    }
    final response = await http.get(
      Uri.parse('$baseUrl/messages/$chatId?page=$page&limit=$limit'),
      headers: {'Authorization': 'Bearer $_token'},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load messages: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> markMessagesAsRead(List<String> messageIds) async {
    if (_token == null) {
      return {'success': false, 'message': 'No token found'};
    }
    final response = await http.post(
      Uri.parse('$baseUrl/messages/read'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      },
      body: jsonEncode({'messageIds': messageIds}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> postStatus(String type, {String? content, String? mediaUrl}) async {
    if (_token == null) {
      return {'success': false, 'message': 'No token found'};
    }
    final response = await http.post(
      Uri.parse('$baseUrl/status'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      },
      body: jsonEncode({
        'type': type,
        'content': content,
        'mediaUrl': mediaUrl,
      }),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> fetchMyStatuses() async {
    if (_token == null) {
      return {'success': false, 'message': 'No token found'};
    }
    final response = await http.get(
      Uri.parse('$baseUrl/my-statuses'),
      headers: {'Authorization': 'Bearer $_token'},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load my statuses: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> fetchStatuses({int page = 1, int limit = 10}) async {
    if (_token == null) {
      return {'success': false, 'message': 'No token found'};
    }
    final response = await http.get(
      Uri.parse('$baseUrl/statuses?page=$page&limit=$limit'),
      headers: {'Authorization': 'Bearer $_token'},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load statuses: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> fetchCalls({int page = 1, int limit = 10, String? filterType, String? filterDate}) async {
    if (_token == null) {
      return {'success': false, 'message': 'No token found'};
    }
    String queryParams = '?page=$page&limit=$limit';
    if (filterType != null && filterType.isNotEmpty) {
      queryParams += '&type=$filterType';
    }
    if (filterDate != null && filterDate.isNotEmpty) {
      queryParams += '&date=$filterDate';
    }
    final response = await http.get(
      Uri.parse('$baseUrl/calls$queryParams'),
      headers: {'Authorization': 'Bearer $_token'},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load calls: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> deleteChatHistory(String chatId) async {
    if (_token == null) {
      return {'success': false, 'message': 'No token found'};
    }
    final response = await http.delete(
      Uri.parse('$baseUrl/messages/$chatId'),
      headers: {'Authorization': 'Bearer $_token'},
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> createGroup(String name, List<String> memberIds, String? description, String? profilePictureUrl) async {
    if (_token == null) {
      return {'success': false, 'message': 'No token found'};
    }
    final response = await http.post(
      Uri.parse('$baseUrl/groups'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      },
      body: jsonEncode({
        'name': name,
        'memberIds': memberIds,
        'description': description,
        'profilePictureUrl': profilePictureUrl,
      }),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> fetchGroups({int page = 1, int limit = 10}) async {
    if (_token == null) {
      return {'success': false, 'message': 'No token found'};
    }
    final response = await http.get(
      Uri.parse('$baseUrl/groups?page=$page&limit=$limit'),
      headers: {'Authorization': 'Bearer $_token'},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load groups: ${response.body}');
    }
  }

  // Hàm tiện ích để lấy URL ảnh đầy đủ
  static String getFullImageUrl(String? relativeUrl) {
    // Nếu relativeUrl là null hoặc rỗng, sử dụng đường dẫn ảnh mặc định của backend.
    // Điều này giả định backend phục vụ ảnh mặc định tại /uploads/default-user.png
    final String effectiveRelativeUrl = (relativeUrl == null || relativeUrl.isEmpty)
        ? "/uploads/default-user.png" // Sử dụng đường dẫn mặc định của backend
        : relativeUrl;

    // Kiểm tra nếu URL đã là tuyệt đối
    if (effectiveRelativeUrl.startsWith('http://') || effectiveRelativeUrl.startsWith('https://')) {
      return effectiveRelativeUrl;
    }
    // Nếu là đường dẫn tương đối, ghép với socketUrl (base URL của backend)
    // Đảm bảo không có dấu '/' thừa hoặc thiếu
    return '$socketUrl${effectiveRelativeUrl.startsWith('/') ? '' : '/'}$effectiveRelativeUrl';
  }
}
