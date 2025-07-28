import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

class OtpScreen extends StatefulWidget {
  final String email;
  final String? testOtp;

  const OtpScreen({
    Key? key,
    required this.email,
    this.testOtp,
  }) : super(key: key);

  @override
  _OtpScreenState createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  List<TextEditingController> otpControllers = List.generate(6, (i) => TextEditingController());
  bool isLoading = false;
  bool isResending = false;

  @override
  void initState() {
    super.initState();
    if (widget.testOtp != null) {
      Future.delayed(Duration(milliseconds: 500), () {
        for (int i = 0; i < widget.testOtp!.length && i < 6; i++) {
          otpControllers[i].text = widget.testOtp![i];
        }
      });
    }
  }

  String _getOTP() {
    return otpControllers.map((c) => c.text).join();
  }

  Future<void> _verifyOTP() async {
    final otp = _getOTP();
    if (otp.length != 6) {
      _showMessage("Nhập đủ 6 số!", true);
      return;
    }

    setState(() => isLoading = true);

    try {
      final result = await AuthService.verifyOTP(
        widget.email,
        "",
        otp,
      );

      if (result['success']) {
        _showMessage("Xác thực thành công!", false);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomeScreen()),
        );
      } else {
        _showMessage(result['message'], true);
        _clearOTP();
      }
    } catch (e) {
      _showMessage("Lỗi: $e", true);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _resendOTP() async {
    setState(() => isResending = true);
    try {
      final result = await AuthService.sendOTP(widget.email);
      if (result['success']) {
        _showMessage("Mã OTP mới đã được gửi đến email của bạn!", false);
        _clearOTP(); // Xóa OTP cũ để người dùng nhập lại
      } else {
        _showMessage(result['message'], true);
      }
    } catch (e) {
      _showMessage("Lỗi khi gửi lại OTP: $e", true);
    } finally {
      setState(() => isResending = false);
    }
  }

  void _clearOTP() {
    for (var controller in otpControllers) {
      controller.clear();
    }
  }

  void _showMessage(String message, bool isError) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Xác thực OTP"),
        backgroundColor: Color(0xFF075E54),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            SizedBox(height: 50),

            Text(
              "Nhập mã OTP",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),

            SizedBox(height: 10),

            Text("Gửi đến: ${widget.email}"),

            SizedBox(height: 40),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(6, (index) {
                return Container(
                  width: 45,
                  height: 55,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: otpControllers[index],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 1,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      counterText: "",
                      border: InputBorder.none,
                    ),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (value) {
                      if (value.isNotEmpty && index < 5) {
                        FocusScope.of(context).nextFocus();
                      }
                      if (_getOTP().length == 6) {
                        _verifyOTP();
                      }
                    },
                  ),
                );
              }),
            ),

            SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isLoading ? null : _verifyOTP,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF075E54),
                  foregroundColor: Colors.white,
                ),
                child: isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text("Xác thực"),
              ),
            ),
            SizedBox(height: 20),
            TextButton(
              onPressed: isResending ? null : _resendOTP,
              child: isResending
                  ? CircularProgressIndicator(strokeWidth: 2)
                  : Text(
                "Gửi lại OTP",
                style: TextStyle(color: Color(0xFF075E54)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
