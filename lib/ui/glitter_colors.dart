import 'package:flutter/material.dart';

/// Baked palette — role-named constants. Values chosen during dev-panel
/// iteration and locked in here.
class GlitterColors {
  const GlitterColors._();

  static const lightBg = Color(0xFFFFD8F3);
  static const darkBg = Color(0xFF2A1A3E);
  static const lightChrome = Color(0xFF4A3270);
  static const darkChrome = Color(0xFFFCDDE7);
  // Content text inverts with brightness for legibility on the saturated
  // glitter backgrounds: light mode uses a dark royal purple — still
  // contrasty against the pink, but visibly purple instead of the
  // near-black it was at `darkBg`'s value. Dark mode keeps the pale
  // lilac that pops on the deep-purple bg.
  static const lightContent = Color(0xFF3D2266);
  static const darkContent = Color(0xFFD4BBEF);
  static const accent = Color(0xFFFF4FA3);
  static const onAccent = Color(0xFF2A1A3E);

  static Color bgFor(Brightness b) => b == Brightness.dark ? darkBg : lightBg;
  static Color chromeFor(Brightness b) =>
      b == Brightness.dark ? darkChrome : lightChrome;
  static Color contentFor(Brightness b) =>
      b == Brightness.dark ? darkContent : lightContent;
}
