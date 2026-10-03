import 'package:flutter/widgets.dart';

import 'selah_motion.dart';
import 'selah_motion_scope.dart';

/// Staggered entrance for a page's top-level cards.
///
/// The shell plays it once per first entry by flipping [animate]; later
/// visits keep the cards static and rely on the page transition. The tree
/// shape is stable regardless of the 「動畫效果」 switch: the animation
/// always exists and rests fully visible when motion is off.
class SelahStaggerEntrance extends StatefulWidget {
  const SelahStaggerEntrance({
    super.key,
    required this.children,
    this.animate = false,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
  });

  final List<Widget> children;
  final bool animate;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  State<SelahStaggerEntrance> createState() => _SelahStaggerEntranceState();
}

class _SelahStaggerEntranceState extends State<SelahStaggerEntrance>
    with SingleTickerProviderStateMixin {
  static const Duration _interval = Duration(milliseconds: 70);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _window,
    value: widget.animate ? 0 : 1,
  );

  Duration get _window =>
      SelahMotion.standard +
      _interval * (widget.children.length - 1).clamp(0, 64);

  @override
  void initState() {
    super.initState();
    if (!widget.animate) {
      _controller.value = 1;
    }
  }

  bool _resolvedInitialGate = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_resolvedInitialGate) return;
    _resolvedInitialGate = true;
    if (widget.animate && MotionScope.of(context)) {
      _controller.forward();
    } else {
      _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant SelahStaggerEntrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.children.length != oldWidget.children.length) {
      _controller.duration = _window;
    }
    if (widget.animate == oldWidget.animate) return;
    if (widget.animate && MotionScope.of(context)) {
      _controller
        ..duration = _window
        ..forward(from: 0);
    } else if (!widget.animate) {
      _controller.value = 1;
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
    if (!motionOn && (_controller.isAnimating || _controller.value != 1)) {
      _controller
        ..stop()
        ..value = 1;
    }
    final curve = SelahMotion.standardCurve;
    return Column(
      crossAxisAlignment: widget.crossAxisAlignment,
      children: [
        for (var index = 0; index < widget.children.length; index++)
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final raw =
                  (_controller.value * _window.inMicroseconds -
                      _interval.inMicroseconds * index) /
                  SelahMotion.standard.inMicroseconds;
              final t = motionOn ? raw.clamp(0.0, 1.0).toDouble() : 1.0;
              final eased = curve.transform(t);
              return Opacity(
                opacity: eased,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - eased)),
                  child: Transform.scale(
                    scale: 0.98 + 0.02 * eased,
                    child: child,
                  ),
                ),
              );
            },
            child: widget.children[index],
          ),
      ],
    );
  }
}
