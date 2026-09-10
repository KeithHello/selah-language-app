import 'package:flutter_test/flutter_test.dart';
import 'package:selah/web/domain/learning_models.dart';
import 'package:selah/web/domain/loop_listening.dart';

void main() {
  test('loop preferences default for old snapshots and round-trip', () {
    final legacy = LearnPreferences();
    expect(legacy.loopOptions.order, LoopOrder.targetFirst);
    expect(legacy.loopOptions.durationMinutes, 30);

    final updated = LearnPreferences.fromJson({
      ...legacy.toJson(),
      'loopOptions': const LoopOptions(
        order: LoopOrder.sourceFirst,
        durationMinutes: 45,
      ).toJson(),
    });

    expect(updated.loopOptions.order, LoopOrder.sourceFirst);
    expect(updated.loopOptions.durationMinutes, 45);
    expect(updated.toJson()['loopOptions'], {
      'order': 'sourceFirst',
      'durationMinutes': 45,
    });
  });

  test('invalid loop preferences fail closed to preference validation', () {
    expect(
      () => LearnPreferences.fromJson({
        'loopOptions': {'order': 'random', 'durationMinutes': 30},
      }),
      throwsFormatException,
    );
  });
}
