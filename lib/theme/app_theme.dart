import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Vercel Geist dark palette
class V {
  // Backgrounds
  static const bg       = Color(0xFF000000);
  static const surface  = Color(0xFF0A0A0A);
  static const card     = Color(0xFF111111);
  static const card2    = Color(0xFF1A1A1A);

  // Borders
  static const border   = Color(0xFF1F1F1F);
  static const border2  = Color(0xFF2A2A2A);
  static const border3  = Color(0xFF333333);

  // Text
  static const text     = Color(0xFFEDEDED);
  static const textSub  = Color(0xFF888888);
  static const textMute = Color(0xFF444444);

  // Accent (Vercel blue)
  static const blue     = Color(0xFF006BFF);
  static const blueDim  = Color(0xFF003D99);
  static const blueBg   = Color(0xFF0D1F3C);

  // Status
  static const red      = Color(0xFFFC0035);
  static const green    = Color(0xFF28A948);
  static const amber    = Color(0xFFFFAE00);

  // Radius
  static const rSm = Radius.circular(6);
  static const rMd = Radius.circular(12);
  static const rLg = Radius.circular(16);
  static const rFull = Radius.circular(9999);

  // Text styles
  static TextStyle mono({double size = 14, Color color = text, FontWeight weight = FontWeight.w400}) =>
    GoogleFonts.jetBrainsMono(fontSize: size, color: color, fontWeight: weight, height: 1.6);

  static TextStyle sans({double size = 14, Color color = text, FontWeight weight = FontWeight.w400}) =>
    GoogleFonts.inter(fontSize: size, color: color, fontWeight: weight, height: 1.5);
}

ThemeData buildTheme() => ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: V.bg,
  colorScheme: const ColorScheme.dark(
    surface: V.surface,
    primary: V.blue,
    onPrimary: Colors.white,
    error: V.red,
  ),
  textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).apply(
    bodyColor: V.text,
    displayColor: V.text,
  ),
  dividerColor: V.border,
  dividerTheme: const DividerThemeData(color: V.border, thickness: 1, space: 1),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: V.card,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.all(V.rSm),
      borderSide: const BorderSide(color: V.border2),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(V.rSm),
      borderSide: const BorderSide(color: V.border2),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(V.rSm),
      borderSide: const BorderSide(color: V.blue),
    ),
    hintStyle: V.sans(color: V.textMute),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: V.bg,
    foregroundColor: V.text,
    elevation: 0,
    titleTextStyle: V.sans(size: 14, weight: FontWeight.w500),
    iconTheme: const IconThemeData(color: V.textSub, size: 18),
    surfaceTintColor: Colors.transparent,
  ),
  pageTransitionsTheme: const PageTransitionsTheme(
    builders: {TargetPlatform.android: ZoomPageTransitionsBuilder()},
  ),
);
