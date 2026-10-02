import 'package:flutter/material.dart';

class SelahWebMotion {
  const SelahWebMotion._();

  static const Duration button = Duration(milliseconds: 120);
  static const Duration state = Duration(milliseconds: 160);
  static const Duration content = Duration(milliseconds: 180);
  static const Duration detail = Duration(milliseconds: 220);
  static const Duration overlay = Duration(milliseconds: 280);
  static const Duration overlayExit = Duration(milliseconds: 190);
  static const Duration toast = Duration(milliseconds: 190);
  static const Duration toastExit = Duration(milliseconds: 160);
  static const Duration dice = Duration(milliseconds: 280);
  static const Duration stageScroll = Duration(milliseconds: 280);

  static const Curve enterCurve = Curves.easeOutCubic;
  static const Curve exitCurve = Curves.easeInCubic;

  static bool shouldReduceMotion(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);

  static Duration duration(BuildContext context, Duration value) =>
      shouldReduceMotion(context) ? Duration.zero : value;

  static AnimationStyle dialogStyle(BuildContext context) => AnimationStyle(
    duration: duration(context, overlay),
    reverseDuration: duration(context, overlayExit),
    curve: enterCurve,
    reverseCurve: exitCurve,
  );

  static AnimationStyle bottomSheetStyle(BuildContext context) =>
      AnimationStyle(
        duration: duration(context, overlay),
        reverseDuration: duration(context, overlayExit),
        curve: enterCurve,
        reverseCurve: exitCurve,
      );

  static ThemeData applyTo(ThemeData theme, BuildContext context) {
    final buttonDuration = duration(context, button);
    ButtonStyle withDuration(ButtonStyle? style) =>
        (style ?? const ButtonStyle()).copyWith(
          animationDuration: buttonDuration,
        );

    return theme.copyWith(
      filledButtonTheme: FilledButtonThemeData(
        style: withDuration(theme.filledButtonTheme.style),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: withDuration(theme.elevatedButtonTheme.style),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: withDuration(theme.outlinedButtonTheme.style),
      ),
      textButtonTheme: TextButtonThemeData(
        style: withDuration(theme.textButtonTheme.style),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: withDuration(theme.iconButtonTheme.style),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: withDuration(theme.segmentedButtonTheme.style),
      ),
    );
  }
}

class SelahWebStateTransition extends StatelessWidget {
  const SelahWebStateTransition({
    required this.stateKey,
    required this.child,
    this.axis = Axis.vertical,
    this.enterFrom = const Offset(0, -1),
    this.distance = 8,
    this.duration = SelahWebMotion.content,
    super.key,
  });

  final Object stateKey;
  final Widget child;
  final Axis axis;
  final Offset enterFrom;
  final double distance;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final transitionDuration = SelahWebMotion.duration(context, duration);
    return AnimatedSwitcher(
      duration: transitionDuration,
      reverseDuration: transitionDuration,
      switchInCurve: SelahWebMotion.enterCurve,
      switchOutCurve: SelahWebMotion.exitCurve,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: AnimatedBuilder(
          animation: animation,
          child: child,
          builder: (context, child) {
            final leaving = animation.status == AnimationStatus.reverse;
            final remaining = 1 - animation.value;
            final direction = leaving ? -1.0 : 1.0;
            final axisOffset = axis == Axis.horizontal
                ? Offset(enterFrom.dx, 0)
                : Offset(0, enterFrom.dy);
            final offset = axisOffset * (direction * distance * remaining);
            return IgnorePointer(
              ignoring: leaving,
              child: ExcludeSemantics(
                excluding: leaving,
                child: Transform.translate(offset: offset, child: child),
              ),
            );
          },
        ),
      ),
      child: KeyedSubtree(key: ValueKey(stateKey), child: child),
    );
  }
}
