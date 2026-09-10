import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// Selah 字体 Token（Plus Jakarta Sans + JetBrains Mono）。
/// 来源：`Selah/DesignTokens/Fonts.swift`。
class SelahTypography {
  const SelahTypography._();

  static const String displayFamily = 'Plus Jakarta Sans';
  static const String monoFamily = 'JetBrains Mono';
  static const List<String>? webFallback = kIsWeb ? ['Noto Sans SC'] : null;

  static TextStyle displayLarge({Color? color}) => TextStyle(
        fontFamily: displayFamily,
        fontFamilyFallback: webFallback,
        fontWeight: FontWeight.w800,
        fontSize: 30,
        height: 1.25,
        letterSpacing: -0.5,
        color: color,
      );

  static TextStyle displayMedium({Color? color}) => TextStyle(
        fontFamily: displayFamily,
        fontFamilyFallback: webFallback,
        fontWeight: FontWeight.w700,
        fontSize: 22,
        height: 1.3,
        letterSpacing: -0.2,
        color: color,
      );

  static TextStyle headlineLarge({Color? color}) => TextStyle(
        fontFamily: displayFamily,
        fontFamilyFallback: webFallback,
        fontWeight: FontWeight.w700,
        fontSize: 18,
        height: 1.35,
        color: color,
      );

  static TextStyle headlineMedium({Color? color}) => TextStyle(
        fontFamily: displayFamily,
        fontFamilyFallback: webFallback,
        fontWeight: FontWeight.w600,
        fontSize: 15,
        height: 1.4,
        color: color,
      );

  static TextStyle headlineSmall({Color? color}) => TextStyle(
        fontFamily: displayFamily,
        fontFamilyFallback: webFallback,
        fontWeight: FontWeight.w600,
        fontSize: 13,
        height: 1.4,
        color: color,
      );

  static TextStyle bodyLarge({Color? color}) => TextStyle(
        fontFamily: displayFamily,
        fontFamilyFallback: webFallback,
        fontWeight: FontWeight.w400,
        fontSize: 14,
        height: 1.5,
        color: color,
      );

  static TextStyle bodyMedium({Color? color}) => TextStyle(
        fontFamily: displayFamily,
        fontFamilyFallback: webFallback,
        fontWeight: FontWeight.w400,
        fontSize: 12,
        height: 1.5,
        color: color,
      );

  static TextStyle bodySmall({Color? color}) => TextStyle(
        fontFamily: displayFamily,
        fontFamilyFallback: webFallback,
        fontWeight: FontWeight.w400,
        fontSize: 11,
        height: 1.45,
        color: color,
      );

  static TextStyle labelLarge({Color? color}) => TextStyle(
        fontFamily: displayFamily,
        fontFamilyFallback: webFallback,
        fontWeight: FontWeight.w600,
        fontSize: 12,
        height: 1.3,
        letterSpacing: 0.2,
        color: color,
      );

  static TextStyle labelMedium({Color? color}) => TextStyle(
        fontFamily: displayFamily,
        fontFamilyFallback: webFallback,
        fontWeight: FontWeight.w600,
        fontSize: 10,
        height: 1.3,
        letterSpacing: 0.3,
        color: color,
      );

  static TextStyle labelSmall({Color? color}) => TextStyle(
        fontFamily: displayFamily,
        fontFamilyFallback: webFallback,
        fontWeight: FontWeight.w600,
        fontSize: 9,
        height: 1.3,
        letterSpacing: 0.4,
        color: color,
      );

  static TextStyle monoMedium({Color? color}) => TextStyle(
        fontFamily: monoFamily,
        fontFamilyFallback: webFallback,
        fontWeight: FontWeight.w500,
        fontSize: 11,
        height: 1.5,
        color: color,
      );
}
