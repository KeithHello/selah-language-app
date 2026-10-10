import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/design/selah_nav_bounce.dart';
import 'package:selah/design/selah_motion_scope.dart';
import 'package:selah/design/selah_pressable.dart';
import 'package:selah/design/selah_stagger_entrance.dart';
import 'package:selah/web/ui/listen_focus_controls.dart';

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
  final fade = tester.widget<FadeTransition>(
    find
        .descendant(
          of: find.byType(SelahStaggerEntrance),
          matching: find.byType(FadeTransition),
        )
        .first,
  );
  return fade.opacity.value;
}

double _textOpacity(WidgetTester tester, String label) {
  final fade = tester.widget<FadeTransition>(
    find
        .ancestor(of: find.text(label), matching: find.byType(FadeTransition))
        .first,
  );
  return fade.opacity.value;
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
      expect(_pressableScale(tester), moreOrLessEquals(0.94));

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

  testWidgets('SelahPressable icon variant uses the deepest press scale', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        motionEnabled: true,
        child: SelahPressable(
          variant: SelahPressVariant.icon,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: const SizedBox(width: 40, height: 40),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(SelahPressable)),
    );
    await tester.pumpAndSettle();
    expect(_pressableScale(tester), moreOrLessEquals(0.90));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(_pressableScale(tester), 1);
  });

  testWidgets('SelahPressable gives no press feedback when disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        motionEnabled: true,
        child: SelahPressable(
          enabled: false,
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(_pressableScale(tester), 1);

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets(
    'SelahPressable restores its scale once a drag exceeds touch slop',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          motionEnabled: true,
          child: SelahPressable(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => taps++,
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
      expect(_pressableScale(tester), moreOrLessEquals(0.94));

      // A small wobble inside the touch slop keeps the press feedback.
      await gesture.moveBy(const Offset(0, -10));
      await tester.pumpAndSettle();
      expect(_pressableScale(tester), moreOrLessEquals(0.94));

      // Dragging past the slop turns the touch into a scroll: release at once,
      // even though the finger is still down.
      await gesture.moveBy(const Offset(0, -20));
      await tester.pumpAndSettle();
      expect(_pressableScale(tester), 1);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(taps, 0);
    },
  );

  testWidgets('SelahPressable keeps tap behavior unchanged', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        motionEnabled: true,
        child: SelahPressable(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => taps++,
            child: const SizedBox(width: 100, height: 44),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SelahPressable));
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(_pressableScale(tester), 1);
  });

  testWidgets('SelahNavBounce scales past 1 mid bounce and settles at 1', (
    tester,
  ) async {
    var selected = false;
    late StateSetter setInnerState;
    await tester.pumpWidget(
      _host(
        motionEnabled: true,
        child: StatefulBuilder(
          builder: (context, setState) {
            setInnerState = setState;
            return Center(
              child: SelahNavBounce(
                selected: selected,
                child: const SizedBox(width: 24, height: 24),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    setInnerState(() => selected = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final midTransform = tester
        .widget<Transform>(find.byType(Transform).first)
        .transform
        .storage[0];
    expect(midTransform, greaterThan(1.0));

    await tester.pumpAndSettle();
    final settledTransform = tester
        .widget<Transform>(find.byType(Transform).first)
        .transform
        .storage[0];
    expect(settledTransform, moreOrLessEquals(1.0));
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
              children: const [Text('a'), Text('b'), Text('c')],
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
          children: const [Text('a'), Text('b')],
        ),
      ),
    );
    await tester.pump();
    expect(_firstStaggerOpacity(tester), 1);
    await tester.pumpAndSettle();
    expect(_firstStaggerOpacity(tester), 1);
  });

  testWidgets('SelahStaggerEntrance spacers do not take an entrance slot', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        motionEnabled: true,
        child: const SelahStaggerEntrance(
          animate: true,
          children: [
            Text('header'),
            SizedBox(height: 14),
            Text('mode'),
            SizedBox(height: 12),
            Text('position'),
            SizedBox(height: 10),
            Text('card'),
          ],
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_textOpacity(tester, 'header'), greaterThan(0));
    expect(_textOpacity(tester, 'position'), 0);
    expect(_textOpacity(tester, 'card'), 0);

    // The fourth content item starts with the third wave, not after the
    // three spacers: 140ms in, it is already on its way.
    await tester.pump(const Duration(milliseconds: 60));
    expect(_textOpacity(tester, 'card'), greaterThan(0));

    await tester.pump(const Duration(milliseconds: 340));
    for (final label in ['header', 'mode', 'position', 'card']) {
      expect(_textOpacity(tester, label), 1, reason: label);
    }
  });

  testWidgets('SelahStaggerEntrance never lasts longer than three waves', (
    tester,
  ) async {
    final labels = [for (var i = 0; i < 8; i++) 'item$i'];
    await tester.pumpWidget(
      _host(
        motionEnabled: true,
        child: SelahStaggerEntrance(
          animate: true,
          children: [for (final label in labels) Text(label)],
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 160));
    // From the third item on, every item shares the last wave.
    final third = _textOpacity(tester, 'item2');
    expect(third, greaterThan(0));
    expect(_textOpacity(tester, 'item7'), closeTo(third, 0.001));

    await tester.pump(const Duration(milliseconds: 340));
    for (final label in labels) {
      expect(_textOpacity(tester, label), 1, reason: label);
    }
  });

  group('ListenFocusControls', () {
    Widget controls({bool busy = false}) => MotionScope(
      motionEnabled: true,
      child: MaterialApp(
        home: Scaffold(
          body: ListenFocusControls(
            uiLocale: 'zh-Hans',
            playbackState: const {'state': 'idle'},
            busy: busy,
            onPlayback: () async {},
            onPrevious: () async {},
            onNext: () async {},
          ),
        ),
      ),
    );

    double scaleOf(WidgetTester tester, String key) => tester
        .widget<ScaleTransition>(
          find
              .ancestor(
                of: find.byKey(ValueKey(key)),
                matching: find.byType(ScaleTransition),
              )
              .first,
        )
        .scale
        .value;

    Future<double> pressedScale(WidgetTester tester, String key) async {
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(ValueKey(key))),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final scale = scaleOf(tester, key);
      await gesture.up();
      await tester.pumpAndSettle();
      return scale;
    }

    testWidgets('all three buttons press with the secondary scale', (
      tester,
    ) async {
      await tester.pumpWidget(controls());
      await tester.pumpAndSettle();
      for (final key in ['listen-previous', 'listen-playback', 'listen-next']) {
        expect(await pressedScale(tester, key), moreOrLessEquals(0.96));
      }
    });

    testWidgets('disabled buttons give no press feedback', (tester) async {
      await tester.pumpWidget(controls(busy: true));
      await tester.pumpAndSettle();
      for (final key in ['listen-previous', 'listen-playback', 'listen-next']) {
        expect(await pressedScale(tester, key), 1);
      }
    });
  });
}
