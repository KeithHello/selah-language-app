import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/web/ui/selah_web_motion.dart';

void main() {
  testWidgets('web motion and button feedback honor reduced-motion settings', (
    tester,
  ) async {
    late AnimationStyle dialogStyle;
    late Duration? buttonDuration;

    Widget surface(bool reduceMotion) => MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Builder(
        builder: (context) {
          dialogStyle = SelahWebMotion.dialogStyle(context);
          buttonDuration = SelahWebMotion.applyTo(
            ThemeData.light(),
            context,
          ).filledButtonTheme.style!.animationDuration;
          return const SizedBox.shrink();
        },
      ),
    );

    await tester.pumpWidget(surface(false));
    expect(dialogStyle.duration, SelahWebMotion.overlay);
    expect(dialogStyle.reverseDuration, SelahWebMotion.overlayExit);
    expect(buttonDuration, SelahWebMotion.button);

    await tester.pumpWidget(surface(true));
    expect(dialogStyle.duration, Duration.zero);
    expect(dialogStyle.reverseDuration, Duration.zero);
    expect(buttonDuration, Duration.zero);
  });

  testWidgets(
    'state transition removes outgoing content from input and semantics',
    (tester) async {
      var activeView = '句库';

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => MediaQuery(
              data: const MediaQueryData(disableAnimations: false),
              child: Column(
                children: [
                  TextButton(
                    key: const ValueKey('openDetail'),
                    onPressed: () => setState(() => activeView = '聆听详情'),
                    child: const Text('打开句子'),
                  ),
                  Expanded(
                    child: SelahWebStateTransition(
                      stateKey: activeView,
                      axis: Axis.horizontal,
                      enterFrom: const Offset(1, 0),
                      child: Semantics(
                        container: true,
                        label: activeView,
                        child: Center(child: Text(activeView)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('openDetail')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      final outgoingSemantics = find.ancestor(
        of: find.text('句库'),
        matching: find.byType(ExcludeSemantics),
      );
      final incomingSemantics = find.ancestor(
        of: find.text('聆听详情'),
        matching: find.byType(ExcludeSemantics),
      );
      final outgoingInput = find.ancestor(
        of: find.text('句库'),
        matching: find.byType(IgnorePointer),
      );

      expect(find.text('句库'), findsOneWidget);
      expect(find.text('聆听详情'), findsOneWidget);
      expect(outgoingSemantics, findsOneWidget);
      expect(incomingSemantics, findsOneWidget);
      expect(
        tester.widget<ExcludeSemantics>(outgoingSemantics).excluding,
        isTrue,
      );
      expect(
        tester.widget<ExcludeSemantics>(incomingSemantics).excluding,
        isFalse,
      );
      expect(
        tester
            .widgetList<IgnorePointer>(outgoingInput)
            .any((widget) => widget.ignoring),
        isTrue,
      );
      expect(find.text('聆听详情'), findsOneWidget);
    },
  );
}
