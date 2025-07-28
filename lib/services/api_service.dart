import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // ⚠️ ĐỔI THÀNH PORT 3000 (giống server)
  static const String baseUrl = 'http://192.168.2.34:3000/api';

  static Future<Map<String, dynamic>> sendOTP(String phone, String countryCode) async {
    try {
      print('📱 Sending OTP to: $countryCode$phone');

      final response = await http.post(
        Uri.parse('$baseUrl/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phoneNumber': phone,
          'countryCode': countryCode,
        }),
      ).timeout(Duration(seconds: 30));

      print('📤 Response: ${response.statusCode} - ${response.body}');
      return jsonDecode(response.body);
    } catch (e) {
      print('❌ Error: $e');
      return {'success': false, 'message': 'Lỗi kết nối: $e'};
    }
  }

  static Future<Map<String, dynamic>> sendTestOTP(String phone, String countryCode) async {
    try {
      print('🧪 Creating test OTP for: $countryCode$phone');

      final response = await http.post(
        Uri.parse('$baseUrl/test-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phoneNumber': phone,
          'countryCode': countryCode,
        }),
      );

      print('🧪 Test Response: ${response.statusCode} - ${response.body}');
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối: $e'};
    }
  }

  static Future<Map<String, dynamic>> verifyOTP(String phone, String countryCode, String otp) async {
    try {
      print('🔐 Verifying OTP: $otp for $countryCode$phone');

      final response = await http.post(
        Uri.parse('$baseUrl/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phoneNumber': phone,
          'countryCode': countryCode,
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
