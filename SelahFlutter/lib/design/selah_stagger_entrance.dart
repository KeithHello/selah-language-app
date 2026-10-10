import 'package:flutter/widgets.dart';

import 'selah_motion.dart';
import 'selah_motion_scope.dart';

/// Staggered entrance for a page's top-level cards.
///
/// The shell plays it once per first entry by flipping [animate]; later
/// visits keep the cards static and rely on the page transition. The tree
/// shape is stable regardless of the 「動畫效果」 switch: the animation
/// always exists and rests fully visible when motion is off.
///
/// Spacers (a [SizedBox] without a child) keep their layout space but take no
/// entrance slot, and content items enter in at most three waves 70ms apart.
/// The whole entrance therefore never runs longer than [SelahMotion.standard]
/// plus two intervals (490ms), however long the page is.
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
  static const int _maxWaves = 3;
  static const double _riseDistance = 20;
  static const double _startScale = 0.98;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _window,
    value: widget.animate ? 0 : 1,
  );

  static bool _isSpacer(Widget child) =>
      child is SizedBox && child.child == null;

  /// Number of entrance waves the current content needs.
  int get _waves => widget.children
      .where((child) => !_isSpacer(child))
      .length
      .clamp(1, _maxWaves);

  Duration get _window => SelahMotion.standard + _interval * (_waves - 1);

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
    if (_controller.duration != _window) {
      _controller.duration = _window;
    }
    if (widget.animate == oldWidget.animate) return;
    if (widget.animate && MotionScope.of(context)) {
      _controller.forward(from: 0);
    } else if (!widget.animate) {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _entrance(Widget child, int wave) {
    final window = _window.inMicroseconds;
    final delay = _interval * wave;
    final progress = _controller.drive(
      CurveTween(
        curve: Interval(
          delay.inMicroseconds / window,
          (delay + SelahMotion.standard).inMicroseconds / window,
          curve: SelahMotion.standardCurve,
        ),
      ),
    );
    return FadeTransition(
      opacity: progress,
      child: AnimatedBuilder(
        animation: progress,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, _riseDistance * (1 - progress.value)),
          child: child,
        ),
        child: ScaleTransition(
          scale: progress.drive(Tween<double>(begin: _startScale, end: 1)),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final motionOn = MotionScope.of(context);
    if (!motionOn && (_controller.isAnimating || _controller.value != 1)) {
      _controller
        ..stop()
        ..value = 1;
    }
    final children = <Widget>[];
    var slot = 0;
    for (final child in widget.children) {
      if (_isSpacer(child)) {
        children.add(child);
        continue;
      }
      children.add(_entrance(child, slot < _maxWaves ? slot : _maxWaves - 1));
      slot++;
    }
    return Column(
      crossAxisAlignment: widget.crossAxisAlignment,
      children: children,
    );
  }
}
