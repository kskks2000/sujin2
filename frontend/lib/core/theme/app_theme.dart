import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color canvas = Color(0xFFF1F5F8);
  static const Color shell = Color(0xFFFBFDFF);
  static const Color ink = Color(0xFF10202D);
  static const Color muted = Color(0xFF66788A);
  static const Color line = Color(0xFFD4DDE6);
  static const Color copper = Color(0xFF0F5D91);
  static const Color ember = Color(0xFFD97706);
  static const Color pine = Color(0xFF0F9F8F);
  static const Color wheat = Color(0xFFE7F3F7);
  static const Color mist = Color(0xFFDBE7EE);

  static ThemeData get lightTheme {
    final baseText = GoogleFonts.notoSansKrTextTheme();

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: canvas,
      colorScheme: const ColorScheme.light(
        primary: copper,
        secondary: pine,
        tertiary: ember,
        surface: shell,
        onSurface: ink,
      ),
      textTheme: baseText.copyWith(
        displayLarge: baseText.displayLarge?.copyWith(
          color: ink,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.8,
        ),
        displaySmall: baseText.displaySmall?.copyWith(
          color: ink,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.2,
          height: 1.15,
        ),
        headlineMedium: baseText.headlineMedium?.copyWith(
          color: ink,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.7,
        ),
        titleLarge: baseText.titleLarge?.copyWith(
          color: ink,
          fontWeight: FontWeight.w800,
        ),
        bodyLarge: baseText.bodyLarge?.copyWith(color: ink, height: 1.5),
        bodyMedium: baseText.bodyMedium?.copyWith(color: muted, height: 1.55),
        labelLarge: baseText.labelLarge?.copyWith(
          color: muted,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: shell.withOpacity(0.94),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
          side: const BorderSide(color: line),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.92),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: copper, width: 1.4),
        ),
      ),
    );
  }
}
