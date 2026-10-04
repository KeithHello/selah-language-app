import 'package:flutter/material.dart';

import 'selah_motion.dart';
import 'selah_motion_scope.dart';

/// 品牌化底部抽屉：默认上滑落定的同时，内容淡入＋轻微上移。
Future<T?> showSelahSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool useSafeArea = false,
  Color? backgroundColor,
  bool showDragHandle = false,
  RouteSettings? settings,
}) {
  final motionOn = MotionScope.of(context);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    backgroundColor: backgroundColor,
    showDragHandle: showDragHandle,
    routeSettings: settings,
    sheetAnimationStyle: motionOn ? null : AnimationStyle.noAnimation,
    builder: (sheetContext) {
      return SelahSheetEntrance(child: Builder(builder: builder));
    },
  );
}

/// 抽屉内容入场：淡入＋16px 上移，280ms easeOutCubic。
class SelahSheetEntrance extends StatefulWidget {
  const SelahSheetEntrance({super.key, required this.child});

  final Widget child;

  @override
  State<SelahSheetEntrance> createState() => _SelahSheetEntranceState();
}

class _SelahSheetEntranceState extends State<SelahSheetEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: SelahMotion.toastIn,
  );

  late final CurvedAnimation _fade = CurvedAnimation(
    parent: _controller,
    curve: SelahMotion.standardCurve,
  );

  bool _resolvedGate = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_resolvedGate) return;
    _resolvedGate = true;
    if (MotionScope.of(context)) {
      _controller.forward();
    } else {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _fade.dispose();
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final eased = motionOn ? _fade.value : 1.0;
        return Opacity(
          opacity: eased,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - eased)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
