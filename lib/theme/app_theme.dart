import 'package:flutter/material.dart';

class AppTheme {
  // Military color palette
  static const Color primaryRed = Color(0xFFCC2233);
  static const Color primaryCyan = Color(0xFF00D4FF);
  static const Color darkBg = Color(0xFF0A0E17);
  static const Color darkCard = Color(0xFF141B2D);
  static const Color darkSurface = Color(0xFF1A2332);
  static const Color metalGray = Color(0xFF8B95A8);
  static const Color metalLight = Color(0xFFC5CDD9);
  static const Color goldTrump = Color(0xFFFFD700);
  static const Color purpleMusketeer = Color(0xFF9B59B6);
  static const Color cyanJoker = Color(0xFF00D4FF);
  static const Color warRed = Color(0xFFFF3344);
  static const Color winGreen = Color(0xFF00FF88);
  static const Color player1Color = Color(0xFF00D4FF);
  static const Color player2Color = Color(0xFFFF3344);

  static ThemeData get darkTheme => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: darkBg,
        colorScheme: const ColorScheme.dark(
          primary: primaryRed,
          secondary: primaryCyan,
          surface: darkSurface,
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontFamily: 'RobotoCondensed',
            fontWeight: FontWeight.w900,
            fontSize: 32,
            color: metalLight,
            letterSpacing: 2,
          ),
          headlineMedium: TextStyle(
            fontFamily: 'RobotoCondensed',
            fontWeight: FontWeight.w700,
            fontSize: 24,
            color: metalLight,
            letterSpacing: 1.5,
          ),
          titleLarge: TextStyle(
            fontFamily: 'RobotoCondensed',
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: metalLight,
          ),
          titleMedium: TextStyle(
            fontFamily: 'RobotoCondensed',
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: metalGray,
          ),
          bodyLarge: TextStyle(
            fontFamily: 'RobotoCondensed',
            fontSize: 16,
            color: metalGray,
          ),
          bodyMedium: TextStyle(
            fontFamily: 'RobotoCondensed',
            fontSize: 14,
            color: metalGray,
          ),
          labelLarge: TextStyle(
            fontFamily: 'RobotoCondensed',
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: metalLight,
            letterSpacing: 1.5,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryRed,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
              side: const BorderSide(color: primaryRed, width: 2),
            ),
            textStyle: const TextStyle(
              fontFamily: 'RobotoCondensed',
              fontWeight: FontWeight.w700,
              fontSize: 16,
              letterSpacing: 2,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: darkSurface.withValues(alpha: 0.7),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: primaryRed.withValues(alpha: 0.5)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: primaryRed.withValues(alpha: 0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: primaryRed, width: 2),
          ),
          hintStyle: TextStyle(
            color: metalGray.withValues(alpha: 0.5),
            fontFamily: 'RobotoCondensed',
            letterSpacing: 1,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        cardTheme: CardThemeData(
          color: darkCard,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: metalGray.withValues(alpha: 0.2)),
          ),
        ),
      );
}
