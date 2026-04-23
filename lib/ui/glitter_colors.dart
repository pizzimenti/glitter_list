import 'package:flutter/material.dart';

/// Baked palette — role-named constants. Values chosen during dev-panel
/// iteration and locked in here.
class GlitterColors {
  const GlitterColors._();

  static const lightBg = Color(0xFFFFD8F3);
  static const darkBg = Color(0xFF2A1A3E);
  static const lightChrome = Color(0xFF4A3270);
  static const darkChrome = Color(0xFFFCDDE7);
  static const lightContent = Color(0xFFA32D6E);
  static const darkContent = Color(0xFFD4BBEF);
  static const accent = Color(0xFFFF4FA3);
  static const onAccent = Color(0xFF2A1A3E);

  static Color bgFor(Brightness b) => b == Brightness.dark ? darkBg : lightBg;
  static Color chromeFor(Brightness b) =>
      b == Brightness.dark ? darkChrome : lightChrome;
  static Color contentFor(Brightness b) =>
      b == Brightness.dark ? darkContent : lightContent;
}
