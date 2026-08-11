import 'package:flutter/material.dart';

/// Selah 动效 Token。
/// 来源：`Selah/DesignTokens/SpacingAndShadows.swift` 动画常量。
class SelahMotion {
  const SelahMotion._();

  static const Duration quick = Duration(milliseconds: 200);
  static const Duration standard = Duration(milliseconds: 350);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration push = Duration(milliseconds: 400);

  /// 品牌标准缓动：快速进入、柔和收尾。
  static const Curve standardCurve = Curves.easeOutCubic;

  /// 弹跳（精灵跳起 / 完成庆祝）。
  static const Curve bounceCurve = Curves.easeOutBack;
}
