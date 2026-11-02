import 'package:flutter/material.dart';

Color successColor(ColorScheme colors) {
  return colors.brightness == Brightness.light
      ? const Color(0xFF087F5B)
      : const Color(0xFF69DBA7);
}

Color warningColor(ColorScheme colors) {
  return colors.brightness == Brightness.light
      ? const Color(0xFFA16207)
      : const Color(0xFFFACD66);
}

/// Keeps a user-selected accent visible on the active theme surface.
Color themeAccentColor(Color source, ColorScheme colors) {
  final HSLColor hsl = HSLColor.fromColor(source);
  if (colors.brightness == Brightness.dark) {
    return hsl
        .withSaturation(hsl.saturation.clamp(0.45, 0.85))
        .withLightness(hsl.lightness.clamp(0.62, 0.78))
        .toColor();
  }
  return hsl
      .withSaturation(hsl.saturation.clamp(0.50, 0.90))
      .withLightness(hsl.lightness.clamp(0.28, 0.42))
      .toColor();
}
