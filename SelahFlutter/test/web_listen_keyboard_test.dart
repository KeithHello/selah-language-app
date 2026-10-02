import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/web/data/learning_gateway.dart';
import 'package:selah/web/domain/learning_models.dart';
import 'package:selah/web/learning_controller.dart';
import 'package:selah/web/platform/learning_platform.dart';
import 'package:selah/web/ui/web_learning_app.dart';

class _KeyboardPlatform implements LearningPlatform {
  final actions = <String>[];
  Map<String, dynamic> audio = {
    'state': 'idle',
    'positionMs': 0,
    'durationMs': 0,
  };

  @override
  Future<Object?> invoke(
    String action, [
    Map<String, Object?> payload = const {},
  ]) async {
    actions.add(action);
    switch (action) {
      case 'load':
        return null;
      case 'save':
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
        return Map<String, dynamic>.from(audio);
      case 'audioCached':
        return true;
      case 'contentHash':
        return 'a' * 64;
      case 'audioPlay':
        audio = {
          'state': 'playing',
          'key': payload['key'],
          'positionMs': 0,
          'durationMs': 4000,
        };
        return null;
      case 'audioPause':
        audio['state'] = 'paused';
        return null;
      case 'audioResume':
        audio['state'] = 'playing';
        return null;
      case 'audioStop':
        audio = {'state': 'idle', 'positionMs': 0, 'durationMs': 0};
        return null;
      default:
        return null;
    }
  }
}

const _firstId = '00000000-0000-4000-8000-000000000021';
const _secondId = '00000000-0000-4000-8000-000000000022';
const _thirdId = '00000000-0000-4000-8000-000000000023';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LearningController controller;
  late _KeyboardPlatform platform;

  setUp(() async {
    TestWidgetsFlutterBinding
        .instance
        .platformDispatcher
        .accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: true,
    );
    platform = _KeyboardPlatform();
    controller = LearningController(
      gateway: UnconfiguredGateway(),
      platform: platform,
      seeds: const [],
      polling: false,
    );
    await controller.initialize();
    controller.state.preferences
      ..onboarded = true
      ..nativeLanguage = 'zh-Hans'
      ..motionEnabled = false;
    controller.state.sentences.addAll([
      LearnSentence(
        id: _firstId,
        source: '第一句',
        target: 'This is the first sentence.',
        category: 'work',
      ),
      LearnSentence(
        id: _secondId,
        source: '第二句',
        target: 'This is the second sentence.',
        category: 'work',
      ),
      LearnSentence(
        id: _thirdId,
        source: '第三句',
        target: 'This is the third sentence.',
        category: 'work',
      ),
    ]);
    controller.navigate(1);
    await controller.selectListenSentence(_firstId);
    platform.actions.clear();
  });

  tearDown(() {
    controller.dispose();
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearAccessibilityFeaturesTestValue();
  });

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(WebLearningApp(controller: controller));
    await tester.pumpAndSettle();
  }

  Future<void> focusByTab(WidgetTester tester, Finder target) async {
    final targetElement = tester.element(target);
    for (var attempt = 0; attempt < 80; attempt++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      var reached = false;
      FocusManager.instance.primaryFocus?.context?.visitAncestorElements((
        element,
      ) {
        if (identical(element, targetElement)) {
          reached = true;
          return false;
        }
        return true;
      });
      if (reached) return;
    }
    fail('Tab traversal did not reach $target');
  }

  testWidgets('left and right move exactly one sentence and play it', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(controller.activeSentence?.id, _secondId);
    expect(
      platform.actions.where((action) => action == 'audioPlay'),
      hasLength(1),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(controller.activeSentence?.id, _firstId);
    expect(
      platform.actions.where((action) => action == 'audioPlay'),
      hasLength(2),
    );
  });

  testWidgets('space follows idle, playing, paused and ended states once', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(
      platform.actions.where((action) => action == 'audioPlay'),
      hasLength(1),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(
      platform.actions.where((action) => action == 'audioPause'),
      hasLength(1),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(
      platform.actions.where((action) => action == 'audioResume'),
      hasLength(1),
    );

    controller.playback['state'] = 'ended';
    controller.notifyListeners();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(
      platform.actions.where((action) => action == 'audioPlay'),
      hasLength(2),
    );
  });

  testWidgets('holding right does not repeat sentence navigation', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);

    expect(controller.activeSentence?.id, _secondId);
    expect(
      platform.actions.where((action) => action == 'audioPlay'),
      hasLength(1),
    );
  });

  testWidgets('keyboard navigation is inactive on another tab', (tester) async {
    await pumpPage(tester);
    controller.navigate(0);
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    expect(controller.activeSentence?.id, _firstId);
    expect(platform.actions.where((action) => action == 'audioPlay'), isEmpty);
  });

  testWidgets('library modal blocks shortcuts and Escape restores focus', (
    tester,
  ) async {
    await pumpPage(tester);
    final libraryButton = find.byKey(const ValueKey('listen-library-button'));
    await tester.tap(libraryButton);
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(controller.activeSentence?.id, _firstId);
    expect(platform.actions.where((action) => action == 'audioPlay'), isEmpty);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('listen-sentence-picker')), findsNothing);
    expect(
      tester.widget<OutlinedButton>(libraryButton).focusNode?.hasFocus,
      isTrue,
    );
  });

  testWidgets('speed menu blocks listen shortcuts', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.byKey(const ValueKey('listen-speed-compact')));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    expect(controller.activeSentence?.id, _firstId);
    expect(platform.actions.where((action) => action == 'audioPlay'), isEmpty);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
  });

  testWidgets('focused progress slider keeps arrow keys for seeking', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.tap(find.byKey(const ValueKey('listen-playback')));
    await tester.pumpAndSettle();
    controller.playback['durationMs'] = 4000;
    controller.notifyListeners();
    await tester.pump();
    final activeId = controller.activeSentence?.id;
    await focusByTab(tester, find.byType(Slider));
    platform.actions.clear();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    expect(controller.activeSentence?.id, activeId);
    expect(platform.actions.where((action) => action == 'audioPlay'), isEmpty);
  });

  testWidgets('focused play button handles Space without a duplicate action', (
    tester,
  ) async {
    await pumpPage(tester);
    final playButton = find.byKey(const ValueKey('listen-playback'));
    await focusByTab(tester, playButton);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(
      platform.actions.where((action) => action == 'audioPlay'),
      hasLength(1),
    );
    platform.actions.clear();

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();

    expect(
      platform.actions.where((action) => action == 'audioPause'),
      hasLength(1),
    );
    expect(platform.actions.where((action) => action == 'audioPlay'), isEmpty);
  });
}
