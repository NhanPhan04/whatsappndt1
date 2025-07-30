import 'package:flutter/material.dart';

class AppThemes {
  // Chủ đề sáng: Giữ màu xanh lá cây đặc trưng của WhatsApp
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: const Color(0xFF075E54), // Màu xanh lá cây đậm
    hintColor: const Color(0xFF25D366), // Màu xanh lá cây sáng hơn (cho FAB, v.v.)
    appBarTheme: const AppBarTheme(
      color: Color(0xFF075E54),
      foregroundColor: Colors.white,
      iconTheme: IconThemeData(color: Colors.white),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFF25D366),
      foregroundColor: Colors.white,
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.black87),
      bodyMedium: TextStyle(color: Colors.black54),
      titleLarge: TextStyle(color: Colors.white),
    ),
    scaffoldBackgroundColor: Colors.white,
    cardColor: Colors.white,
    dialogBackgroundColor: Colors.white,
    colorScheme: ColorScheme.fromSwatch(
      primarySwatch: MaterialColor(0xFF075E54, <int, Color>{
        50: Color(0xFFE1F5FE), 100: Color(0xFFB3E5FC), 200: Color(0xFF81D4FA),
        300: Color(0xFF4FC3F7), 400: Color(0xFF29B6F6), 500: Color(0xFF075E54),
        600: Color(0xFF039BE5), 700: Color(0xFF0288D1), 800: Color(0xFF0277BD),
        900: Color(0xFF01579B),
      }),
    ).copyWith(
      secondary: const Color(0xFF25D366),
      primary: const Color(0xFF075E54),
      surface: Colors.white,
      onSurface: Colors.black87,
      background: Colors.white,
      onBackground: Colors.black87,
      brightness: Brightness.light,
    ),
  );

  // Chủ đề tối: Sử dụng các màu tối nhưng vẫn giữ điểm nhấn xanh lá cây
  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: const Color(0xFF121B22), // Màu nền chính tối
    hintColor: const Color(0xFF25D366), // Vẫn giữ màu xanh lá cây sáng cho điểm nhấn
    appBarTheme: const AppBarTheme(
      color: Color(0xFF1F2C34), // Màu tối hơn cho AppBar
      foregroundColor: Colors.white,
      iconTheme: IconThemeData(color: Colors.white),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFF25D366),
      foregroundColor: Colors.white,
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.white70),
      bodyMedium: TextStyle(color: Colors.white54),
      titleLarge: TextStyle(color: Colors.white),
    ),
    scaffoldBackgroundColor: const Color(0xFF0B141A), // Nền tối nhất
    cardColor: const Color(0xFF1F2C34), // Màu thẻ tối
    dialogBackgroundColor: const Color(0xFF1F2C34),
    colorScheme: ColorScheme.fromSwatch(
      primarySwatch: MaterialColor(0xFF075E54, <int, Color>{
        50: Color(0xFFE1F5FE), 100: Color(0xFFB3E5FC), 200: Color(0xFF81D4FA),
        300: Color(0xFF4FC3F7), 400: Color(0xFF29B6F6), 500: Color(0xFF075E54),
        600: Color(0xFF039BE5), 700: Color(0xFF0288D1), 800: Color(0xFF0277BD),
        900: Color(0xFF01579B),
      }),
    ).copyWith(
      secondary: const Color(0xFF25D366),
      primary: const Color(0xFF121B22),
      surface: const Color(0xFF1F2C34),
      onSurface: Colors.white70,
      background: const Color(0xFF0B141A),
      onBackground: Colors.white70,
      brightness: Brightness.dark,
    ),
  );
}
