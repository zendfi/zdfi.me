import 'package:flutter/material.dart';

/// Parse a hex color string like '#2D6A4F' into a Flutter Color.
Color hexToColor(String hex, {Color fallback = const Color(0xFF2D6A4F)}) {
  try {
    final clean = hex.replaceAll('#', '');
    if (clean.length == 6) {
      return Color(int.parse('FF$clean', radix: 16));
    }
    if (clean.length == 8) {
      return Color(int.parse(clean, radix: 16));
    }
  } catch (_) {}
  return fallback;
}

/// Returns black or white depending on which has better contrast with [bg].
Color contrastColor(Color bg) {
  final luminance = bg.computeLuminance();
  return luminance > 0.4 ? const Color(0xFF1A1A1A) : Colors.white;
}
