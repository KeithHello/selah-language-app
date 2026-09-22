import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/web/data/learning_gateway.dart';
import 'package:selah/web/domain/learning_models.dart';
import 'package:selah/web/learning_controller.dart';
import 'package:selah/web/platform/learning_platform.dart';
import 'package:selah/web/ui/web_learning_app.dart';

class _ListenPeekPlatform implements LearningPlatform {
  @override
  Future<Object?> invoke(
    String action, [
    Map<String, Object?> payload = const {},
  ]) async {
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

LearnSentence _listenSentence({
  required String id,
  required String source,
  required String target,
  List<Map<String, dynamic>> breakdown = const [],
}) => LearnSentence(
  id: id,
  source: source,
  target: target,
  category: 'work',
  breakdown: breakdown,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LearningController controller;

  setUp(() async {
    TestWidgetsFlutterBinding
        .instance
        .platformDispatcher
        .accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: true,
    );
    controller = LearningController(
      gateway: UnconfiguredGateway(),
      platform: _ListenPeekPlatform(),
      seeds: const [],
      polling: false,
    );
    await controller.initialize();
    controller.state.preferences
      ..onboarded = true
      ..nativeLanguage = 'zh-Hans';
    controller.state.sentences
      ..clear()
      ..addAll([
        _listenSentence(
          id: 'listen-one',
          source: '今天又加班到半夜，我真的会谢',
          target: "Pulled another all-nighter at work. I literally can't even.",
          breakdown: const [
            {
              'surfaceText': 'pulled another all-nighter',
              'meaning': '又加班到半夜、又熬夜',
            },
            {
              'surfaceText': "I literally can't even",
              'meaning': '我真的会谢、我真的不行了',
            },
          ],
        ),
        _listenSentence(
          id: 'listen-two',
          source: '我今天想早点休息。',
          target: 'I want to rest early today.',
        ),
      ]);
    controller.notifyListeners();
  });

  tearDown(() {
    controller.dispose();
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearAccessibilityFeaturesTestValue();
  });

  testWidgets('revealed listening answer opens one native gloss at a time', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    controller.navigate(1);
    await tester.pumpWidget(WebLearningApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('点选查看母语'), findsNothing);
    await tester.tap(find.text('看英文答案'));
    await tester.pumpAndSettle();
    expect(find.text('点选查看母语'), findsOneWidget);
    expect(
      find.bySemanticsLabel("拆解词组：I literally can't even"),
      findsOneWidget,
    );
    expect(find.text('我真的会谢、我真的不行了'), findsNothing);

    final beforeEvents = controller.state.events.length;
    await tester.tap(find.bySemanticsLabel("拆解词组：I literally can't even"));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.bySemanticsLabel("拆解词组：I literally can't even"),
    );
    expect(find.text('我真的会谢、我真的不行了'), findsOneWidget);
    expect(find.text('又加班到半夜、又熬夜'), findsNothing);
    expect(controller.state.events.length, beforeEvents);

    await tester.tap(find.byKey(const ValueKey('listen-gloss-close')));
    await tester.pumpAndSettle();
    expect(find.text('我真的会谢、我真的不行了'), findsNothing);
  });

  testWidgets('target phrase and chip share the selected native gloss', (
    tester,
  ) async {
    controller.navigate(1);
    await tester.pumpWidget(WebLearningApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('看英文答案'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('listen-target-b:0')));
    await tester.pumpAndSettle();
    expect(find.text('又加班到半夜、又熬夜'), findsOneWidget);
    expect(find.text('我真的会谢、我真的不行了'), findsNothing);

    await tester.ensureVisible(find.byKey(const ValueKey('listen-target-b:1')));
    await tester.tap(find.byKey(const ValueKey('listen-target-b:1')));
    await tester.pumpAndSettle();
    expect(find.text('又加班到半夜、又熬夜'), findsNothing);
    expect(find.text('我真的会谢、我真的不行了'), findsOneWidget);
  });

  testWidgets('changing sentence clears the selected native gloss', (
    tester,
  ) async {
    controller.navigate(1);
    await tester.pumpWidget(WebLearningApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('看英文答案'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('listen-target-b:1')));
    await tester.tap(find.byKey(const ValueKey('listen-target-b:1')));
    await tester.pumpAndSettle();
    expect(find.text('我真的会谢、我真的不行了'), findsOneWidget);

    await tester.ensureVisible(find.text('我今天想早点休息。'));
    await tester.tap(find.text('我今天想早点休息。'));
    await tester.pumpAndSettle();
    expect(find.text('我真的会谢、我真的不行了'), findsNothing);
    expect(find.text('看英文答案'), findsOneWidget);
  });
}
