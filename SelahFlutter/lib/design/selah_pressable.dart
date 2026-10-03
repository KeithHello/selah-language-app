import 'package:flutter/widgets.dart';

import 'selah_motion.dart';
import 'selah_motion_scope.dart';

/// 按压反馈强度分级：主 CTA 幅度最大且回弹带过冲，次级与图标按钮轻量。
enum SelahPressVariant { primary, secondary, icon }

/// Wraps a button so pressing it plays a visible scale-down.
///
/// The widget tree shape is stable whether or not motion is enabled: the
/// scale transition always exists and simply rests at scale 1 while the
/// in-app 「動畫效果」 switch is off.
class SelahPressable extends StatefulWidget {
  const SelahPressable({
    super.key,
    required this.child,
    this.variant = SelahPressVariant.primary,
    this.pressedScale,
  });

  final Widget child;
  final SelahPressVariant variant;
  final double? pressedScale;

  double get effectivePressedScale {
    if (pressedScale != null) return pressedScale!;
    switch (variant) {
      case SelahPressVariant.primary:
        return 0.94;
      case SelahPressVariant.secondary:
        return 0.96;
      case SelahPressVariant.icon:
        return 0.90;
    }
  }

  Duration get pressDuration {
    switch (variant) {
      case SelahPressVariant.primary:
        return SelahMotion.press;
      case SelahPressVariant.secondary:
        return const Duration(milliseconds: 120);
      case SelahPressVariant.icon:
        return const Duration(milliseconds: 110);
    }
  }

  Curve get releaseCurve {
    switch (variant) {
      case SelahPressVariant.primary:
        return SelahMotion.bounceCurve;
      case SelahPressVariant.secondary:
      case SelahPressVariant.icon:
        return SelahMotion.standardCurve;
    }
  }

  @override
  State<SelahPressable> createState() => _SelahPressableState();
}

class _SelahPressableState extends State<SelahPressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.pressDuration,
    value: 1,
  );

  late final CurvedAnimation _curve = CurvedAnimation(
    // 松开（forward）按变体走回弹或标准曲线，按下（reverse）统一标准曲线。
    parent: _controller,
    curve: widget.releaseCurve,
    reverseCurve: SelahMotion.standardCurve,
  );

  late final Animation<double> _scale = Tween<double>(
    begin: widget.effectivePressedScale,
    end: 1,
  ).animate(_curve);

  void _press() {
    if (!MotionScope.of(context)) return;
    _controller.reverse();
  }

  void _release() {
    if (!MotionScope.of(context)) return;
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _curve.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motionOn = MotionScope.of(context);
    if (!motionOn && (_controller.isAnimating || _controller.value != 1)) {
      _controller
        ..stop()
        ..value = 1;
    }
    _curve.curve = widget.releaseCurve;
    _curve.reverseCurve = SelahMotion.standardCurve;
    return Listener(
      onPointerDown: (_) => _press(),
      onPointerUp: (_) => _release(),
      onPointerCancel: (_) => _release(),
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}
