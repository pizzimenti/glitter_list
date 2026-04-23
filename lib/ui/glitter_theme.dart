import 'dart:ui';

import 'package:flutter/material.dart';

@immutable
class GlitterTheme extends ThemeExtension<GlitterTheme> {
  const GlitterTheme({
    required this.content,
    required this.titleFontSize,
    required this.bodyFontSize,
  });

  final Color content;
  final double titleFontSize;
  final double bodyFontSize;

  @override
  GlitterTheme copyWith({
    Color? content,
    double? titleFontSize,
    double? bodyFontSize,
  }) =>
      GlitterTheme(
        content: content ?? this.content,
        titleFontSize: titleFontSize ?? this.titleFontSize,
        bodyFontSize: bodyFontSize ?? this.bodyFontSize,
      );

  @override
  GlitterTheme lerp(ThemeExtension<GlitterTheme>? other, double t) {
    if (other is! GlitterTheme) return this;
    return GlitterTheme(
      content: Color.lerp(content, other.content, t) ?? content,
      titleFontSize:
          lerpDouble(titleFontSize, other.titleFontSize, t) ?? titleFontSize,
      bodyFontSize:
          lerpDouble(bodyFontSize, other.bodyFontSize, t) ?? bodyFontSize,
    );
  }
}

extension GlitterThemeOf on BuildContext {
  GlitterTheme get glitter => Theme.of(this).extension<GlitterTheme>()!;
}
