import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/design/selah_motion_scope.dart';
import 'package:selah/design/selah_pressable.dart';
import 'package:selah/design/selah_stagger_entrance.dart';

Widget _host({required bool motionEnabled, required Widget child}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: MotionScope(motionEnabled: motionEnabled, child: child),
  );
}

double _pressableScale(WidgetTester tester) {
  final transition = tester.widget<ScaleTransition>(
    find.descendant(
      of: find.byType(SelahPressable),
      matching: find.byType(ScaleTransition),
    ),
  );
  return transition.scale.value;
}

double _firstStaggerOpacity(WidgetTester tester) {
  final opacity = tester.widget<Opacity>(
    find
        .descendant(
          of: find.byType(SelahStaggerEntrance),
          matching: find.byType(Opacity),
        )
        .first,
  );
  return opacity.opacity;
}

void main() {
  testWidgets(
    'SelahPressable scales down while pressed and restores on release',
    (tester) async {
      await tester.pumpWidget(
        _host(
          motionEnabled: true,
          child: SelahPressable(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: const SizedBox(width: 100, height: 44),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(SelahPressable)),
      );
      await tester.pumpAndSettle();
      expect(_pressableScale(tester), moreOrLessEquals(0.97));

      await gesture.up();
      await tester.pumpAndSettle();
      expect(_pressableScale(tester), 1);
    },
  );

  testWidgets('SelahPressable ignores presses when motion is off', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        motionEnabled: false,
        child: SelahPressable(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: const SizedBox(width: 100, height: 44),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(SelahPressable)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(_pressableScale(tester), 1);

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('SelahStaggerEntrance plays once per first entry', (
    tester,
  ) async {
    var animate = false;
    late StateSetter setInnerState;
    await tester.pumpWidget(
      _host(
        motionEnabled: true,
        child: StatefulBuilder(
          builder: (context, setState) {
            setInnerState = setState;
            return SelahStaggerEntrance(
              animate: animate,
              children: const [
                SizedBox(height: 20),
                SizedBox(height: 20),
                SizedBox(height: 20),
              ],
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_firstStaggerOpacity(tester), 1);

    setInnerState(() => animate = true);
    await tester.pump();
    expect(_firstStaggerOpacity(tester), 0);

    await tester.pump(const Duration(milliseconds: 120));
    final mid = _firstStaggerOpacity(tester);
    expect(mid, greaterThan(0));
    expect(mid, lessThan(1));

    await tester.pumpAndSettle();
    expect(_firstStaggerOpacity(tester), 1);
  });

  testWidgets('SelahStaggerEntrance shows cards instantly when motion is off', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        motionEnabled: false,
        child: SelahStaggerEntrance(
          animate: true,
          children: const [SizedBox(height: 20), SizedBox(height: 20)],
        ),
      ),
    );
    await tester.pump();
    expect(_firstStaggerOpacity(tester), 1);
    await tester.pumpAndSettle();
    expect(_firstStaggerOpacity(tester), 1);
  });
}
