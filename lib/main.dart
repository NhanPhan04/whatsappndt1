import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'screens/landing_screen.dart';
import 'screens/home_screen.dart';
import 'screens/camera_screen.dart';
import 'screens/otp_screen.dart';

List<CameraDescription> cameras = [];
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    cameras = await availableCameras();
  } catch (e) {
    print("Error initializing cameras: $e");
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, ThemeMode currentMode, child) {
        return MaterialApp(
          title: 'WhatsApp NDT',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            primaryColor: Color(0xFF075E54), // Màu chính của bạn
            // Thêm các thuộc tính theme khác nếu cần
          ),
          darkTheme: ThemeData(
            primaryColor: Color(0xFF075E54), // Màu chính cho dark theme
            brightness: Brightness.dark,
          ),
          themeMode: currentMode, // Kết nối với themeNotifier
          home: LandingScreen(), // Bắt đầu từ LandingScreen
        );
      },
    );
  }
}