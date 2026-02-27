import 'dart:math' as math;

import 'package:flutter/material.dart';

class ResponsiveUtils {
  static double width(BuildContext context) => MediaQuery.sizeOf(context).width;

  static bool isNarrowPhone(BuildContext context) => width(context) < 390;

  static double spacingScale(BuildContext context) {
    final factor = width(context) / 400;
    return factor.clamp(0.84, 1.06);
  }

  static double typographyScale(BuildContext context) {
    final factor = width(context) / 430;
    return factor.clamp(0.82, 1.00);
  }

  static double textScaleFactor(BuildContext context) {
    final userScale = MediaQuery.textScalerOf(context).scale(1);
    return math.min(userScale, 1.08);
  }

  static TextTheme scaledTextTheme(TextTheme base, double factor) {
    TextStyle? scale(TextStyle? style) {
      if (style == null || style.fontSize == null) return style;
      return style.copyWith(fontSize: style.fontSize! * factor);
    }

    return base.copyWith(
      displayLarge: scale(base.displayLarge),
      displayMedium: scale(base.displayMedium),
      displaySmall: scale(base.displaySmall),
      headlineLarge: scale(base.headlineLarge),
      headlineMedium: scale(base.headlineMedium),
      headlineSmall: scale(base.headlineSmall),
      titleLarge: scale(base.titleLarge),
      titleMedium: scale(base.titleMedium),
      titleSmall: scale(base.titleSmall),
      bodyLarge: scale(base.bodyLarge),
      bodyMedium: scale(base.bodyMedium),
      bodySmall: scale(base.bodySmall),
      labelLarge: scale(base.labelLarge),
      labelMedium: scale(base.labelMedium),
      labelSmall: scale(base.labelSmall),
    );
  }
}
