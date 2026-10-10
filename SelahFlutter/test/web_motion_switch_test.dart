import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/design/selah_motion_scope.dart';
import 'package:selah/web/data/learning_gateway.dart';
import 'package:selah/web/domain/research_profile.dart';
import 'package:selah/web/learning_controller.dart';
import 'package:selah/web/platform/learning_platform.dart';
import 'package:selah/web/research_profile_controller.dart';
import 'package:selah/web/ui/companion_dice_button.dart';
import 'package:selah/web/ui/research_profile_widgets.dart';
import 'package:selah/web/ui/web_learning_app.dart';

class _MotionPlatform implements LearningPlatform {
  Map<String, dynamic>? saved;

  @override
  Future<Object?> invoke(
    String action, [
    Map<String, Object?> payload = const {},
  ]) async {
    switch (action) {
      case 'load':
        return saved;
      case 'save':
        saved = Map<String, dynamic>.from(payload['snapshot']! as Map);
        return true;
      case 'platformInfo':
        return const {
          'online': false,
          'storage': true,
          'audio': true,
          'storagePersisted': null,
          'installKind': 'unsupported',
          'installed': false,
          'canInstall': false,
          'updateAvailable': false,
          'buildId': 'test',
        };
      case 'audioStatus':
        return const {'state': 'idle', 'positionMs': 0, 'durationMs': 0};
      case 'audioCached':
        return true;
      case 'contentHash':
        return 'a' * 64;
      default:
        return null;
    }
  }
}

Future<LearningController> _controller({required bool motion}) async {
  final controller = LearningController(
    gateway: UnconfiguredGateway(),
    platform: _MotionPlatform(),
    seeds: const [],
    polling: false,
  );
  await controller.initialize();
  controller.state.preferences
    ..onboarded = true
    ..uiLocale = 'zh-Hans'
    ..motionEnabled = motion;
  return controller;
}

Widget _host(Widget child, {required bool motion}) => MotionScope(
  motionEnabled: motion,
  child: MaterialApp(home: Scaffold(body: child)),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('toast notice', () {
    Future<({double dy, double opacity})> showToast(
      WidgetTester tester, {
      required bool motion,
    }) async {
      final controller = await _controller(motion: motion);
      addTearDown(controller.dispose);
      controller.navigate(4);
      await tester.pumpWidget(WebLearningApp(controller: controller));
      await tester.pumpAndSettle();
      controller.notice = '偏好已保存。';
      controller.notifyListeners();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final toast = find.byKey(const ValueKey('webFeedbackToast'));
      final slide = tester.widget<SlideTransition>(
        find.ancestor(of: toast, matching: find.byType(SlideTransition)).first,
      );
      final fade = tester.widget<FadeTransition>(
        find.ancestor(of: toast, matching: find.byType(FadeTransition)).first,
      );
      final result = (dy: slide.position.value.dy, opacity: fade.opacity.value);
      controller.dismissNotice();
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('appears in its final state when motion is off', (
      tester,
    ) async {
      final toast = await showToast(tester, motion: false);
      expect(toast.dy, 0);
      expect(toast.opacity, 1);
    });

    testWidgets('still slides and fades in when motion is on', (tester) async {
      final toast = await showToast(tester, motion: true);
      expect(toast.dy, lessThan(0));
      expect(toast.opacity, lessThan(1));
    });
  });

  group('mobile navigation indicator', () {
    Future<List<double>> indicatorValuesAfterSwitch(
      WidgetTester tester, {
      required bool motion,
    }) async {
      final controller = await _controller(motion: motion);
      addTearDown(controller.dispose);
      await tester.pumpWidget(WebLearningApp(controller: controller));
      await tester.pumpAndSettle();
      controller.navigate(1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final values = tester
          .widgetList<NavigationIndicator>(find.byType(NavigationIndicator))
          .map((indicator) => indicator.animation.value)
          .toList();
      await tester.pumpAndSettle();
      return values;
    }

    testWidgets('jumps to the selected tab when motion is off', (tester) async {
      final values = await indicatorValuesAfterSwitch(tester, motion: false);
      expect(values, isNotEmpty);
      expect(values.every((value) => value == 0 || value == 1), isTrue);
    });

    testWidgets('keeps the indicator animation when motion is on', (
      tester,
    ) async {
      final values = await indicatorValuesAfterSwitch(tester, motion: true);
      expect(values.any((value) => value > 0 && value < 1), isTrue);
    });
  });

  group('companion dice button', () {
    Future<({bool moving, String? rolled})> rollDice(
      WidgetTester tester, {
      required bool motion,
    }) async {
      String? rolled;
      await tester.pumpWidget(
        _host(
          Center(
            child: CompanionDiceButton(
              tooltip: 'roll',
              languageCode: 'zh-Hant',
              currentName: '加班芽',
              onRolled: (name) => rolled = name,
            ),
          ),
          motion: motion,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CompanionDiceButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      final moving = tester
          .widgetList<Transform>(
            find.descendant(
              of: find.byType(CompanionDiceButton),
              matching: find.byType(Transform),
            ),
          )
          .any((transform) => !transform.transform.isIdentity());
      await tester.pumpAndSettle();
      return (moving: moving, rolled: rolled);
    }

    testWidgets('rolls a name without rotating when motion is off', (
      tester,
    ) async {
      final result = await rollDice(tester, motion: false);
      expect(result.rolled, isNotNull);
      expect(result.rolled, isNot('加班芽'));
      expect(result.moving, isFalse);
    });

    testWidgets('rotates and scales while rolling when motion is on', (
      tester,
    ) async {
      final result = await rollDice(tester, motion: true);
      expect(result.rolled, isNotNull);
      expect(result.moving, isTrue);
    });
  });

  group('research profile background section', () {
    Future<double> heightOneFrameAfterTap(
      WidgetTester tester, {
      required bool motion,
    }) async {
      final controller = ResearchProfileController(
        gateway: UnconfiguredGateway(),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _host(
          SingleChildScrollView(
            child: ResearchProfileForm(
              controller: controller,
              uiLocale: 'zh-Hans',
              initial: const ResearchProfile(),
              showIdentityFields: true,
            ),
          ),
          motion: motion,
        ),
      );
      await tester.tap(find.text('更多背景资料（可选）'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      final first = tester.getSize(find.byType(ExpansionTile)).height;
      await tester.pumpAndSettle();
      final settled = tester.getSize(find.byType(ExpansionTile)).height;
      return first / settled;
    }

    testWidgets('expands in one frame when motion is off', (tester) async {
      expect(await heightOneFrameAfterTap(tester, motion: false), 1);
    });

    testWidgets('expands gradually when motion is on', (tester) async {
      expect(await heightOneFrameAfterTap(tester, motion: true), lessThan(1));
    });
  });

  testWidgets('web theme uses the ripple Flutter picks for the web', (
    tester,
  ) async {
    final controller = await _controller(motion: true);
    addTearDown(controller.dispose);
    await tester.pumpWidget(WebLearningApp(controller: controller));
    await tester.pumpAndSettle();
    final theme = Theme.of(tester.element(find.byType(Scaffold).first));
    expect(theme.splashFactory, same(InkRipple.splashFactory));
  });
}
