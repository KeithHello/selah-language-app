import 'package:flutter/material.dart';

/// Selah 品牌色彩 Token。
/// 来源：`Selah/DesignTokens/Colors.swift`（Quiet Growth 方向，暖米色基底）。
class SelahColors {
  const SelahColors._();

  // 背景 / 表面
  static const Color bgPrimary = Color(0xFFFBF8F4);
  static const Color bgSecondary = Color(0xFFF8F5F0);
  static const Color cardPrimary = Color(0xFFFFFFFF);
  static const Color cardSoft = Color(0xFFFDFBF8);

  // 文本
  static const Color textPrimary = Color(0xFF1A1614);
  static const Color textSecondary = Color(0xFF706B65);
  static const Color textTertiary = Color(0xFFA9A49E);
  static const Color textOnAccent = Color(0xFFFFFFFF);

  // 边框
  static const Color border = Color(0xFFEBE7E1);
  static const Color borderLight = Color(0xFFF3F0EC);

  // 品牌强调色（各带 soft 变体，用于浅色填充背景）
  static const Color coral = Color(0xFFE06B54);
  static const Color coralSoft = Color(0xFFFEF0ED);
  static const Color sage = Color(0xFF5A9E82);
  static const Color sageSoft = Color(0xFFECF7F1);
  static const Color amber = Color(0xFFE5A244);
  static const Color amberSoft = Color(0xFFFDF5E6);
  static const Color lavender = Color(0xFF8B7FC7);
  static const Color lavenderSoft = Color(0xFFF0EEF8);
  static const Color sky = Color(0xFF5B9FD4);
  static const Color skySoft = Color(0xFFEAF3FB);
  static const Color rose = Color(0xFFD4829C);
  static const Color roseSoft = Color(0xFFF9EEF2);

  // 语义色
  static const Color success = sage;
  static const Color warning = amber;
  static const Color danger = coral;
  static const Color info = sky;
  static const Color listen = lavender;

  // 暗色模式表面（谨慎扩展，先保持与品牌一致）
  static const Color darkBg = Color(0xFF16120F);
  static const Color darkCard = Color(0xFF221D19);
  static const Color darkTextPrimary = Color(0xFFF5F1EC);
  static const Color darkTextSecondary = Color(0xFFC4BDB5);
  static const Color darkTextTertiary = Color(0xFF8E8780);
  static const Color darkBorder = Color(0xFF3A332D);
}
