import 'package:flutter/widgets.dart';

import 'selah_motion.dart';
import 'selah_motion_scope.dart';

/// Wraps a primary call-to-action so pressing it plays a gentle scale-down.
///
/// The widget tree shape is stable whether or not motion is enabled: the
/// scale transition always exists and simply rests at scale 1 while the
/// in-app 「動畫效果」 switch is off.
class SelahPressable extends StatefulWidget {
  const SelahPressable({
    super.key,
    required this.child,
    this.pressedScale = 0.97,
  });

  final Widget child;
  final double pressedScale;

  @override
  State<SelahPressable> createState() => _SelahPressableState();
}

class _SelahPressableState extends State<SelahPressable>
    with SingleTickerProviderStateMixin {
  static const Duration _pressDuration = Duration(milliseconds: 110);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _pressDuration,
    value: 1,
  );

  late final Animation<double> _scale =
      Tween<double>(begin: widget.pressedScale, end: 1).animate(
        CurvedAnimation(parent: _controller, curve: SelahMotion.standardCurve),
      );

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
    return Listener(
      onPointerDown: (_) => _press(),
      onPointerUp: (_) => _release(),
      onPointerCancel: (_) => _release(),
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}
