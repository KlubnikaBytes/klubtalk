import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Colors - WhatsApp Inspired
  static const Color primaryGreen = Color(0xFF075E54);
  static const Color accentGreen = Color(0xFF25D366);
  static const Color lightBackground = Color(0xFFF8F9FA); 
  static const Color darkBackground = Color(0xFF121212);
  
  // Chat Specific
  static const Color chatBackgroundLight = Color(0xFFECE5DD); // Wallpaper color
  static const Color chatBackgroundDark = Color(0xFF0B141A);  // Dark wallpaper
  
  static const Color sentMessageLight = Color(0xFFDCF8C6); // Classic light green
  static const Color sentMessageDark = Color(0xFF005C4B);  // Dark mode green
  static const Color receivedMessageLight = Colors.white;
  static const Color receivedMessageDark = Color(0xFF202C33);

  static const Color unreadBadgeColor = Color(0xFF25D366);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: primaryGreen,
    scaffoldBackgroundColor: lightBackground,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryGreen,
      brightness: Brightness.light,
      primary: primaryGreen,
      secondary: accentGreen,
      surface: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryGreen,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    textTheme: GoogleFonts.interTextTheme(),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primaryGreen,
      foregroundColor: Colors.white,
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: primaryGreen,
    scaffoldBackgroundColor: darkBackground,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryGreen,
      brightness: Brightness.dark,
      primary: primaryGreen,
      secondary: accentGreen,
      surface: const Color(0xFF1F1F1F),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1F1F1F), 
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primaryGreen,
      foregroundColor: Colors.white,
    ),
  );
}
