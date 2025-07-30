import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:email_validator/email_validator.dart';
import '../services/auth_service.dart';
import 'otp_screen.dart';
import 'home_screen.dart'; // Import HomeScreen

class LandingScreen extends StatefulWidget {
  @override
  _LandingScreenState createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  TextEditingController emailController = TextEditingController();
  bool isLoading = false;
  @override
  void initState() {
    super.initState();
    _checkLoginStatus(); // Kiểm tra trạng thái đăng nhập khi khởi động
  }

  Future<void> _checkLoginStatus() async {
    await AuthService.init(); // Khởi tạo AuthService để tải token/user data
    final isLoggedIn = AuthService.isLoggedIn(); // Đã sửa lỗi: isLoggedIn
    if (isLoggedIn) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen()),
      );
    }
  }

  Future<void> _sendOTP() async {
    print('🚀 Send OTP button pressed');
    if (emailController.text.trim().isEmpty) {
      _showSnackBar("Vui lòng nhập địa chỉ email", isError: true);
      return;
    }
    if (!EmailValidator.validate(emailController.text.trim())) {
      _showSnackBar("Địa chỉ email không hợp lệ", isError: true);
      return;
    }
    setState(() {
      isLoading = true;
    });
    try {
      final useRealOTP = await _showOTPChoiceDialog();
      if (useRealOTP == null) {
        setState(() {
          isLoading = false;
        });
        return;
      }
      print('🎯 User chose: ${useRealOTP ? "Real OTP" : "Test OTP"}');
      Map<String, dynamic> result;
      if (useRealOTP) {
        result = await AuthService.sendOTP( // Đã sửa lỗi: sendOTP
          emailController.text.trim(),
        );
      } else {
        result = await AuthService.sendTestOTP( // Đã sửa lỗi: sendTestOTP
          emailController.text.trim(),
        );
      }
      print('📤 OTP Result: $result');
      if (result['success']) {
        _showSnackBar(result['message'], isError: false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OtpScreen(
              email: emailController.text.trim(),
              testOtp: result['testOtp'],
            ),
          ),
        );
      } else {
        _showSnackBar(result['message'], isError: true);
      }
    } catch (e) {
      print('❌ Send OTP Exception: $e');
      _showSnackBar("Lỗi không xác định: $e", isError: true);
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<bool?> _showOTPChoiceDialog() async {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Chọn loại OTP"),
          content: Text("Bạn muốn sử dụng OTP thật (gửi Email) hay OTP test?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text("Test OTP (123456)", style: TextStyle(color: Colors.orange)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text("OTP thật (Email)", style: TextStyle(color: Color(0xFF075E54))),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: 80),
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Color(0xFF075E54),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Icon(Icons.chat, size: 50, color: Colors.white),
                ),
                SizedBox(height: 30),
                Text(
                  "WhatsApp NDT",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF075E54),
                  ),
                ),
                SizedBox(height: 20),
                SizedBox(height: 40),
                Text(
                  "Nhập địa chỉ email của bạn",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 20),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: "Địa chỉ email",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    prefixIcon: Icon(Icons.email),
                  ),
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _sendOTP,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF075E54),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: isLoading
                        ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : Text(
                      "Gửi OTP",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  "Chúng tôi sẽ gửi mã OTP đến email của bạn",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }
}
