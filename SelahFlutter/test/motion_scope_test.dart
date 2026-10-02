import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/design/selah_motion_scope.dart';
import 'package:selah/web/domain/learning_models.dart';
import 'package:selah/web/learning_controller.dart';

import 'web_controller_test.dart';

Widget _harness({
  bool? motionEnabled,
  bool systemReduce = false,
  required ValueChanged<bool> onResolve,
}) {
  Widget resolve() => Builder(
        builder: (context) {
          onResolve(MotionScope.of(context));
          return const SizedBox.shrink();
        },
      );
  return MediaQuery(
    data: MediaQueryData(disableAnimations: systemReduce),
    child: motionEnabled == null
        ? resolve()
        : MotionScope(motionEnabled: motionEnabled, child: resolve()),
  );
}

void main() {
  testWidgets('without a scope the gate falls back to the system setting', (
    tester,
  ) async {
    var allowed = true;
    await tester.pumpWidget(
      _harness(systemReduce: true, onResolve: (value) => allowed = value),
    );
    expect(allowed, isFalse);
  });

  testWidgets('the in-app toggle overrides the system preference', (
    tester,
  ) async {
    var allowedWithSystemReduce = false;
    await tester.pumpWidget(
      _harness(
        motionEnabled: true,
        systemReduce: true,
        onResolve: (value) => allowedWithSystemReduce = value,
      ),
    );
    expect(allowedWithSystemReduce, isTrue);

    var allowed = true;
    await tester.pumpWidget(
      _harness(motionEnabled: false, onResolve: (value) => allowed = value),
    );
    expect(allowed, isFalse);
  });

  testWidgets('durationOf collapses tokens to zero when motion is off', (
    tester,
  ) async {
    const token = Duration(milliseconds: 200);
    var resolved = token;
    await tester.pumpWidget(
      MotionScope(
        motionEnabled: false,
        child: Builder(
          builder: (context) {
            resolved = MotionScope.durationOf(context, token);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(resolved, Duration.zero);
  });

  test('motion defaults to on and tolerates legacy snapshots', () {
    expect(LearnPreferences().motionEnabled, isTrue);
    final legacy = LearnPreferences().toJson()..remove('motionEnabled');
    expect(LearnPreferences.fromJson(legacy).motionEnabled, isTrue);
    final off = LearnPreferences.fromJson(
      LearnPreferences().toJson()..['motionEnabled'] = false,
    );
    expect(off.motionEnabled, isFalse);
    expect(off.toJson()['motionEnabled'], false);
  });

  test('updatePreferences stores the motion toggle on the device', () async {
    final controller = LearningController(
      gateway: CaptureGateway(),
      platform: MemoryPlatform(),
      seeds: const [],
      polling: false,
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    expect(controller.state.preferences.motionEnabled, isTrue);
    await controller.updatePreferences(motionEnabled: false);
    expect(controller.state.preferences.motionEnabled, isFalse);
    expect(controller.state.preferences.toJson()['motionEnabled'], false);
  });
}
