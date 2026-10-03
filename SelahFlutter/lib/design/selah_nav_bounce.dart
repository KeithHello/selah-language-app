import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'selah_motion_scope.dart';

/// tab 选中切换时播放一次 200ms 的半波弹跳（放大后回落）。
///
/// 树形稳定：缩放始终存在，未选中或「動畫效果」关闭时静止在 scale 1。
class SelahNavBounce extends StatefulWidget {
  const SelahNavBounce({
    super.key,
    required this.selected,
    required this.child,
  });

  final bool selected;
  final Widget child;

  @override
  State<SelahNavBounce> createState() => _SelahNavBounceState();
}

class _SelahNavBounceState extends State<SelahNavBounce>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );

  @override
  void didUpdateWidget(covariant SelahNavBounce oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.selected && widget.selected && MotionScope.of(context)) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motionOn = MotionScope.of(context);
    if (!motionOn && _controller.isAnimating) {
      _controller.stop();
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = motionOn ? _controller.value : 0.0;
        return Transform.scale(
          scale: 1 + 0.12 * math.sin(math.pi * t),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
