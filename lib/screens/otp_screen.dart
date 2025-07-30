import 'package:flutter/material.dart';
import 'package:whatsappndt1/screens/home_screen.dart';
import 'package:whatsappndt1/services/auth_service.dart';

import '../services/auth_service.dart';
import 'home_screen.dart'; // Import AuthService

class OtpScreen extends StatefulWidget {
  final String email;
  final String? testOtp; // Thêm trường này để nhận test OTP nếu có

  const OtpScreen({super.key, required this.email, this.testOtp});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  TextEditingController otpController = TextEditingController();
  bool isLoading = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.testOtp != null) {
      otpController.text = widget.testOtp!; // Tự động điền test OTP nếu có
    }
  }

  Future<void> _verifyOtp() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final otp = otpController.text.trim();
    if (otp.isEmpty) {
      setState(() {
        errorMessage = "Vui lòng nhập OTP.";
        isLoading = false;
      });
      return;
    }

    try {
      final result = await AuthService.verifyOTP(widget.email, otp); // Đã sửa lỗi: verifyOTP
      if (result['success']) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => HomeScreen()),
              (route) => false,
        );
      } else {
        setState(() {
          errorMessage = result['message'] ?? "Xác thực OTP thất bại.";
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "Lỗi kết nối: $e";
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _resendOtp() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final result = await AuthService.sendOTP(widget.email); // Đã sửa lỗi: sendOTP
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("OTP mới đã được gửi!")),
        );
      } else {
        setState(() {
          errorMessage = result['message'] ?? "Gửi lại OTP thất bại.";
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "Lỗi kết nối: $e";
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Xác thực OTP'),
        backgroundColor: const Color(0xFF075E54),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Nhập mã OTP đã gửi đến email của bạn',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: otpController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Mã OTP',
                  hintText: '123456',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.vpn_key),
                ),
              ),
              if (errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Text(
                    errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 24),
              isLoading
                  ? const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF075E54)),
              )
                  : Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _verifyOtp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF075E54),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Xác thực OTP',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _resendOtp,
                    child: const Text(
                      'Gửi lại OTP',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF075E54),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    otpController.dispose();
    super.dispose();
  }
}
