import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors from HTML Custom Tailwind Config
  static const Color primaryOrange = Color(0xFFFF5722); // primary-container / brand color
  static const Color primaryLight = Color(0xFFFFB5A0); // primary
  static const Color darkBackground = Color(0xFF131316); // background / surface
  static const Color surfaceContainer = Color(0xFF1F1F22); // surface-container
  static const Color borderGray = Color(0xFF353438); // surface-container-highest / outline
  static const Color textPrimary = Color(0xFFE4E1E6); // on-background / on-surface
  static const Color textSecondary = Color(0xFFE4BEB4); // on-surface-variant

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryOrange,
      scaffoldBackgroundColor: darkBackground,
      cardColor: surfaceContainer,
      colorScheme: const ColorScheme.dark(
        primary: primaryOrange,
        onPrimary: Colors.white,
        surface: surfaceContainer,
        onSurface: textPrimary,
        outline: borderGray,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.anybody(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: textPrimary,
          letterSpacing: -1.0,
        ).copyWith(inherit: true),
        displayMedium: GoogleFonts.anybody(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: textPrimary,
          letterSpacing: -0.5,
        ).copyWith(inherit: true),
        bodyLarge: GoogleFonts.hankenGrotesk(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: textPrimary,
          height: 1.6,
        ).copyWith(inherit: true),
        bodyMedium: GoogleFonts.hankenGrotesk(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: textSecondary,
          height: 1.4,
        ).copyWith(inherit: true),
        labelLarge: GoogleFonts.hankenGrotesk(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: 0.1,
        ).copyWith(inherit: true),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryOrange,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.hankenGrotesk(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ).copyWith(inherit: true),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryOrange,
          padding: const EdgeInsets.symmetric(vertical: 18),
          textStyle: GoogleFonts.hankenGrotesk(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ).copyWith(inherit: true),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF252528),
        contentTextStyle: GoogleFonts.hankenGrotesk(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFF353438)),
        ),
      ),
    );
  }
}
