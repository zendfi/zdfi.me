import 'package:flutter/material.dart';
import 'tokens.dart';

ThemeData buildZendPayTheme({Color? themeColor, Color? bgColor}) {
  final primary = themeColor ?? ZendColors.accent;
  final bg = bgColor ?? ZendColors.bgPrimary;

  return ThemeData(
    useMaterial3: true,
    fontFamily: 'DMSans',
    colorScheme: ColorScheme.light(
      primary: primary,
      secondary: ZendColors.accentBright,
      surface: bg,
      onPrimary: Colors.white,
      onSurface: ZendColors.textPrimary,
      error: ZendColors.destructive,
    ),
    scaffoldBackgroundColor: bg,
    splashFactory: InkRipple.splashFactory,
    dividerTheme: const DividerThemeData(color: ZendColors.border, thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ZendColors.bgSecondary,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ZendRadii.xl),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ZendRadii.xl),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ZendRadii.xl),
        borderSide: BorderSide(color: primary, width: 1.2),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 46),
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ZendRadii.pill),
        ),
        textStyle: const TextStyle(
          fontFamily: 'DMSans',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}
