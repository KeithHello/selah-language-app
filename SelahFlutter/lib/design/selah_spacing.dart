import 'package:flutter/material.dart';

/// Selah 间距 / 圆角 / 阴影 Token。
/// 来源：`Selah/DesignTokens/SpacingAndShadows.swift`（4pt 基准网格）。
class SelahSpacing {
  const SelahSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double page = 20;

  /// 触控目标最小尺寸（iOS 44pt / Android 48dp，取 44 作为跨端下限）。
  static const double minTouchTarget = 44;
}

class SelahCornerRadius {
  const SelahCornerRadius._();

  static const double xs = 6;
  static const double sm = 10;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 22;
  static const double pill = 999;
}

class SelahShadow {
  const SelahShadow._();

  static List<BoxShadow> sm({Brightness brightness = Brightness.light}) {
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 2,
        offset: const Offset(0, 1),
      ),
    ];
  }

  static List<BoxShadow> md({Brightness brightness = Brightness.light}) {
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.06),
        blurRadius: 8,
        offset: const Offset(0, 4),
      ),
    ];
  }

  static List<BoxShadow> lg({Brightness brightness = Brightness.light}) {
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.08),
        blurRadius: 20,
        offset: const Offset(0, 10),
      ),
    ];
  }
}
