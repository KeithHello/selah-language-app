import 'package:flutter/widgets.dart';

/// App-level motion gate.
///
/// The in-app 「動畫效果」 setting is the single master switch: motion plays
/// by default and the OS reduce-motion preference no longer force-disables
/// it. Widget trees without a [MotionScope] ancestor (tests and the native
/// preview screens) keep the legacy system-driven behaviour.
class MotionScope extends InheritedWidget {
  const MotionScope({
    super.key,
    required this.motionEnabled,
    required super.child,
  });

  /// Whether UI motion should play. Backed by the device-local preference.
  final bool motionEnabled;

  /// Resolves the effective motion gate for [context].
  static bool of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<MotionScope>();
    if (scope != null) return scope.motionEnabled;
    return !_systemReduceMotion(context);
  }

  /// Collapses a motion [token] to zero when motion is turned off.
  static Duration durationOf(BuildContext context, Duration token) =>
      of(context) ? token : Duration.zero;

  static bool _systemReduceMotion(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context) ||
      WidgetsBinding
          .instance
          .platformDispatcher
          .accessibilityFeatures
          .disableAnimations;

  @override
  bool updateShouldNotify(MotionScope oldWidget) =>
      oldWidget.motionEnabled != motionEnabled;
}
