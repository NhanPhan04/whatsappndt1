import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Updated to use localhost for development
  static const String baseUrl = 'http://localhost:3000/api';

  static Future<Map<String, dynamic>> sendOTP(String email) async {
    try {
      print('📱 Sending OTP to: $email');

      final response = await http.post(
        Uri.parse('$baseUrl/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
        }),
      ).timeout(Duration(seconds: 30));

      print('📤 Response: ${response.statusCode} - ${response.body}');
      return jsonDecode(response.body);
    } catch (e) {
      print('❌ Error: $e');
      return {'success': false, 'message': 'Lỗi kết nối: $e'};
    }
  }

  static Future<Map<String, dynamic>> sendTestOTP(String email) async {
    try {
      print('🧪 Creating test OTP for: $email');

      final response = await http.post(
        Uri.parse('$baseUrl/test-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
        }),
      );

      print('🧪 Test Response: ${response.statusCode} - ${response.body}');
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối: $e'};
    }
  }

  static Future<Map<String, dynamic>> verifyOTP(String email, String otp) async {
    try {
      print('🔐 Verifying OTP: $otp for $email');

      final response = await http.post(
        Uri.parse('$baseUrl/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'otp': otp,
        }),
      );

      print('🔐 Verify Response: ${response.statusCode} - ${response.body}');
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối: $e'};
    }
  }

  // Test connection
  static Future<bool> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(Duration(seconds: 10));

      print('🔍 Health check: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Connection error: $e');
      return false;
    }
  }
}
