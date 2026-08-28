import 'package:flutter/material.dart';

/// PeerPlay Theme — Netflix-dark meets Apple precision
/// Matches the original React Native theme.ts exactly
class AppTheme {
  AppTheme._();

  // ─── Colors ───
  static const background = Color(0xFF0A0A0F);
  static const backgroundAlt = Color(0xFF111118);
  static const surface = Color(0xFF181820);
  static const surfaceLight = Color(0xFF222230);
  static const surfaceHover = Color(0xFF2A2A3A);

  static const primary = Color(0xFF5856D6);
  static const primaryLight = Color(0xFF7B79E8);
  static const primaryDark = Color(0xFF4240B0);
  static const primaryGlow = Color(0x335856D6);

  static const accent = Color(0xFF1DB954);
  static const accentRed = Color(0xFFE50914);
  static const accentBlue = Color(0xFF0A84FF);
  static const accentPurple = Color(0xFF9E86FF);
  static const accentAmber = Color(0xFFFFB347);

  static const text = Color(0xFFF5F5F7);
  static const textSecondary = Color(0xFF98989F);
  static const textTertiary = Color(0xFF636366);
  static const textMuted = Color(0xFF48484A);

  static const success = Color(0xFF1DB954);
  static const warning = Color(0xFFFFB347);
  static const error = Color(0xFFFF453A);
  static const info = Color(0xFF0A84FF);

  static const border = Color(0xFF1C1C2A);
  static const borderLight = Color(0xFF2C2C3E);
  static const overlay = Color(0xB8000000);
  static const overlayLight = Color(0x73000000);

  // ─── Spacing (4px grid) ───
  static const double spacingXxs = 2;
  static const double spacingXs = 4;
  static const double spacingSm = 8;
  static const double spacingMd = 12;
  static const double spacingBase = 16;
  static const double spacingLg = 20;
  static const double spacingXl = 24;
  static const double spacingXxl = 32;
  static const double spacingXxxl = 48;
  static const double spacingSection = 40;

  // ─── Border Radius ───
  static const double radiusXs = 4;
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 20;
  static const double radiusXxl = 24;
  static const double radiusPoster = 10;
  static const double radiusCard = 12;
  static const double radiusChip = 20;
  static const double radiusRound = 999;

  // ─── Font Sizes ───
  static const double fontSizeCaption = 11;
  static const double fontSizeSmall = 12;
  static const double fontSizeBody = 14;
  static const double fontSizeBodyLarge = 16;
  static const double fontSizeSubtitle = 18;
  static const double fontSizeTitle = 22;
  static const double fontSizeHeading = 28;
  static const double fontSizeHero = 36;
  static const double fontSizeBillboard = 44;

  // ─── Full Material Theme ───
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: accent,
        surface: surface,
        error: error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: text,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: text,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: text),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: text,
        unselectedLabelColor: textMuted,
        indicatorColor: primary,
        labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: background,
        selectedItemColor: text,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        hintStyle: const TextStyle(color: textMuted, fontSize: 16),
        contentPadding: const EdgeInsets.symmetric(horizontal: spacingBase, vertical: spacingMd),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          fixedSize: Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(color: text, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5),
        headlineMedium: TextStyle(color: text, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3),
        titleLarge: TextStyle(color: text, fontSize: 18, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(color: text, fontSize: 16, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: text, fontSize: 16),
        bodyMedium: TextStyle(color: textSecondary, fontSize: 14),
        bodySmall: TextStyle(color: textTertiary, fontSize: 12),
        labelLarge: TextStyle(color: text, fontSize: 14, fontWeight: FontWeight.w700),
        labelMedium: TextStyle(color: textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
        labelSmall: TextStyle(color: textTertiary, fontSize: 11),
      ),
    );
  }
}
