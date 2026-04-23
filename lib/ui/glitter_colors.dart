import 'package:flutter/material.dart';

class GlitterColors {
  const GlitterColors._();

  static const lightPink = Color(0xFFFCDDE7);
  static const deepPurple = Color(0xFF2A1A3E);
  static const hotPink = Color(0xFFFF4FA3);
  static const lightPurple = Color(0xFFD4BBEF);

  static Color contentOn(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? lightPurple
          : deepPurple;
}
