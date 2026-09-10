import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/design/selah_theme.dart';
import 'package:selah/web/ui/web_start_action.dart';

Widget _host(WebStartAction action, {double width = 360}) {
  return MaterialApp(
    theme: SelahTheme.light(),
    home: Scaffold(
      body: Center(
        child: SizedBox(width: width, child: action),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('invalid onboarding state disables the action and explains why', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const WebStartAction(
          selectedCount: 2,
          hasName: false,
          busy: false,
          onStart: _noop,
        ),
      ),
    );

    expect(find.text('開始學習'), findsOneWidget);
    expect(find.text('先取名字'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });

  testWidgets('at least five selected sentences and a name enable one tap', (
    tester,
  ) async {
    var starts = 0;
    await tester.pumpWidget(
      _host(
        WebStartAction(
          selectedCount: 5,
          hasName: true,
          busy: false,
          onStart: () => starts += 1,
        ),
      ),
    );

    expect(find.text('可以開始了'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );

    await tester.tap(find.byType(FilledButton));
    expect(starts, 1);
  });

  testWidgets(
    'counts below five stay disabled while larger selections stay enabled',
    (tester) async {
      final handle = tester.ensureSemantics();
      try {
        for (final count in [0, 2, 4, 5, 6, 30]) {
          await tester.pumpWidget(
            _host(
              WebStartAction(
                selectedCount: count,
                hasName: true,
                busy: false,
                onStart: _noop,
              ),
            ),
          );
          expect(find.bySemanticsLabel('開始學習'), findsOneWidget);
          expect(
            tester.widget<FilledButton>(find.byType(FilledButton)).onPressed !=
                null,
            count >= 5,
          );
        }
      } finally {
        handle.dispose();
      }
    },
  );

  testWidgets('enabled action can be activated from the keyboard', (
    tester,
  ) async {
    var starts = 0;
    await tester.pumpWidget(
      _host(
        WebStartAction(
          selectedCount: 5,
          hasName: true,
          busy: false,
          onStart: () => starts += 1,
        ),
      ),
    );

    starts = 0;
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(starts, 1);
  });

  testWidgets('busy action is disabled and reduced motion stays static', (
    tester,
  ) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );

    await tester.pumpWidget(
      _host(
        const WebStartAction(
          selectedCount: 5,
          hasName: true,
          busy: true,
          onStart: _noop,
        ),
      ),
    );

    expect(find.text('準備中…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });

  testWidgets('compact width keeps the action inside its parent', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _host(
        const WebStartAction(
          selectedCount: 5,
          hasName: true,
          busy: false,
          onStart: _noop,
        ),
        width: 320,
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(WebStartAction)).width,
      lessThanOrEqualTo(320),
    );
  });
}

void _noop() {}
