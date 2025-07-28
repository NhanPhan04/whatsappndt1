import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'screens/landing_screen.dart'; // LandingScreen sẽ là màn hình chính
import 'screens/home_screen.dart';
import 'screens/camera_screen.dart';
import 'screens/otp_screen.dart'; // Vẫn dùng OtpScreen

List<CameraDescription> cameras = [];

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WhatsApp NDT',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Color(0xFF075E54),
      ),
      home: LandingScreen(), // Bắt đầu từ LandingScreen
    );
  }
}
