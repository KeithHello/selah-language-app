import 'package:flutter/material.dart';

import 'selah_motion.dart';
import 'selah_motion_scope.dart';

/// 品牌化弹窗过渡：缩放＋淡入进入，退出走 easeInCubic 干脆收场。
///
/// Web 弹窗统一走这里，替代裸 showDialog 的默认 150ms 淡入。
/// 「動畫效果」关闭时过渡时长归零，内容直出。
Future<T?> showSelahDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  String? barrierLabel,
  bool useSafeArea = true,
  RouteSettings? settings,
}) {
  final motionOn = MotionScope.of(context);
  return Navigator.of(context, rootNavigator: true).push<T>(
    _SelahDialogRoute<T>(
      barrierDismissible: barrierDismissible,
      barrierLabel: barrierLabel ?? 'Dialog',
      barrierColor: barrierColor ?? Colors.black54,
      transitionDuration: motionOn ? SelahMotion.overlay : Duration.zero,
      reverseDuration: motionOn
          ? const Duration(milliseconds: 180)
          : Duration.zero,
      settings: settings,
      pageBuilder: (dialogContext, animation, secondaryAnimation) =>
          SafeArea(child: Builder(builder: builder)),
      transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
        if (!motionOn) return child;
        final curved = CurvedAnimation(
          parent: animation,
          curve: SelahMotion.standardCurve,
          reverseCurve: SelahMotion.exitCurve,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
}

class _SelahDialogRoute<T> extends RawDialogRoute<T> {
  _SelahDialogRoute({
    required super.pageBuilder,
    required this.reverseDuration,
    super.barrierDismissible,
    super.barrierColor,
    super.barrierLabel,
    super.transitionDuration,
    super.transitionBuilder,
    super.settings,
  });

  final Duration reverseDuration;

  @override
  Duration get reverseTransitionDuration => reverseDuration;
}
