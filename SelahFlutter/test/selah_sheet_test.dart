import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/design/selah_motion_scope.dart';
import 'package:selah/design/selah_sheet.dart';

Widget _app({required bool motion}) => MotionScope(
  motionEnabled: motion,
  child: MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => showSelahSheet<void>(
              context: context,
              builder: (_) =>
                  const SizedBox(height: 120, child: Text('sheet body')),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('sheet content fades in without a second slide', (tester) async {
    await tester.pumpWidget(_app(motion: true));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    final entrance = find.byType(SelahSheetEntrance);
    // The route already slides the sheet up; the content must not move again.
    expect(
      find.descendant(of: entrance, matching: find.byType(Transform)),
      findsNothing,
    );
    final fade = tester.widget<FadeTransition>(
      find
          .descendant(of: entrance, matching: find.byType(FadeTransition))
          .first,
    );
    expect(fade.opacity.value, allOf(greaterThan(0), lessThan(1)));

    await tester.pumpAndSettle();
    expect(find.text('sheet body'), findsOneWidget);
  });

  testWidgets('sheet content is fully visible at once when motion is off', (
    tester,
  ) async {
    await tester.pumpWidget(_app(motion: false));
    await tester.tap(find.text('open'));
    await tester.pump();

    final fade = tester.widget<FadeTransition>(
      find
          .descendant(
            of: find.byType(SelahSheetEntrance),
            matching: find.byType(FadeTransition),
          )
          .first,
    );
    expect(fade.opacity.value, 1);
    expect(find.text('sheet body'), findsOneWidget);
  });
}
