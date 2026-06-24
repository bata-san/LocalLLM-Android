import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class V {
  // Backgrounds — warm charcoal (Claude-inspired)
  static const bg      = Color(0xFF1A1817);
  static const bgDeep  = Color(0xFF111110);
  static const surface = Color(0xFF221F1C);
  static const card    = Color(0xFF2A2623);
  static const card2   = Color(0xFF322E2B);

  // Borders
  static const border  = Color(0xFF2E2B28);
  static const border2 = Color(0xFF3A3633);

  // Text
  static const text    = Color(0xFFF0EDE8);
  static const textSub = Color(0xFF8C847D);
  static const textMute= Color(0xFF524D49);

  // Accent — amber/orange (Claude's signature warmth)
  static const amber   = Color(0xFFE07B39);
  static const amberDim= Color(0xFF7B3F18);
  static const amberBg = Color(0xFF2E1C0E);

  // Semantic
  static const red     = Color(0xFFE05252);
  static const green   = Color(0xFF4CAF82);

  // Radius
  static const rSm   = Radius.circular(8);
  static const rMd   = Radius.circular(16);
  static const rLg   = Radius.circular(20);
  static const rFull = Radius.circular(9999);

  static TextStyle mono({double size = 13, Color color = text, FontWeight weight = FontWeight.w400}) =>
    GoogleFonts.jetBrainsMono(fontSize: size, color: color, fontWeight: weight, height: 1.6);

  static TextStyle sans({double size = 14, Color color = text, FontWeight weight = FontWeight.w400, double? height}) =>
    GoogleFonts.inter(fontSize: size, color: color, fontWeight: weight, height: height ?? 1.55);
}

ThemeData buildTheme() => ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: V.bg,
  colorScheme: const ColorScheme.dark(
    surface: V.surface,
    primary: V.amber,
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
      borderSide: const BorderSide(color: V.amber, width: 1.5),
    ),
    hintStyle: V.sans(color: V.textMute),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: V.bg,
    foregroundColor: V.text,
    elevation: 0,
    titleTextStyle: V.sans(size: 14, weight: FontWeight.w500),
    iconTheme: const IconThemeData(color: V.textSub, size: 20),
    surfaceTintColor: Colors.transparent,
  ),
  drawerTheme: const DrawerThemeData(
    backgroundColor: V.bgDeep,
    surfaceTintColor: Colors.transparent,
    width: 280,
  ),
  pageTransitionsTheme: const PageTransitionsTheme(
    builders: {TargetPlatform.android: ZoomPageTransitionsBuilder()},
  ),
);
