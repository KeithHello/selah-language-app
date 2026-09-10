import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/web/data/learning_gateway.dart';
import 'package:selah/web/domain/learning_models.dart';
import 'package:selah/web/learning_controller.dart';
import 'package:selah/web/platform/learning_platform.dart';
import 'package:selah/web/ui/web_learning_app.dart';

class _NotesFakePlatform implements LearningPlatform {
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

LearnSentence _note({
  required String id,
  required String source,
  required String target,
  List<Map<String, dynamic>> breakdown = const [],
  List<VocabularyEntry> vocabulary = const [],
}) => LearnSentence(
  id: id,
  source: source,
  target: target,
  category: 'work',
  breakdown: breakdown,
  vocabulary: vocabulary,
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
      platform: _NotesFakePlatform(),
      seeds: const [],
      polling: false,
    );
    await controller.initialize();
    controller.state.preferences
      ..onboarded = true
      ..uiLocale = 'zh-Hans';
    controller.state.sentences
      ..clear()
      ..addAll([
        _note(
          id: 'one',
          source: '老板又在开空头支票。',
          target: 'My boss is making empty promises again.',
          breakdown: const [
            {'surfaceText': 'empty promises', 'explanation': '承诺不会兑现的事情。'},
          ],
          vocabulary: [
            VocabularyEntry(
              id: 'v1',
              text: 'empty promises',
              meaning: '不会兑现的承诺',
            ),
          ],
        ),
        _note(
          id: 'two',
          source: '今天又要加班到很晚。',
          target: 'I have to work late again today.',
        ),
        _note(
          id: 'three',
          source: '我会把这件事记下来。',
          target: 'I will keep this in mind.',
          breakdown: const [
            {'surfaceText': 'keep this in mind', 'explanation': '记住并在之后留意。'},
          ],
        ),
      ]);
    controller.notifyListeners();
  });

  tearDown(() {
    controller.dispose();
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearAccessibilityFeaturesTestValue();
  });

  testWidgets('notes show complete bilingual cards without selecting first', (
    tester,
  ) async {
    controller.navigate(3);
    await tester.pumpWidget(WebLearningApp(controller: controller));
    await tester.pumpAndSettle();

    expect(
      tester
          .widgetList<RichText>(find.byType(RichText))
          .any(
            (richText) =>
                richText.text.toPlainText().replaceAll(
                  '\uFFFC',
                  'empty promises',
                ) ==
                'My boss is making empty promises again.',
          ),
      isTrue,
    );
    expect(find.text('I have to work late again today.'), findsOneWidget);
    expect(find.text('选一句查看详情'), findsNothing);
    expect(find.text('Boss is making empty promises again. ...'), findsNothing);
  });

  testWidgets('notes expand breakdown in place and allow multiple cards open', (
    tester,
  ) async {
    controller.navigate(3);
    await tester.pumpWidget(WebLearningApp(controller: controller));
    await tester.pumpAndSettle();

    final expandButtons = find.ancestor(
      of: find.text('展开拆解'),
      matching: find.byType(OutlinedButton),
    );
    await tester.ensureVisible(expandButtons.first);
    await tester.tap(expandButtons.first);
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.text.toPlainText().contains('承诺不会兑现的事情。'),
      ),
      findsOneWidget,
    );
    expect(find.text('I have to work late again today.'), findsOneWidget);

    final remainingExpandButtons = find.ancestor(
      of: find.text('展开拆解'),
      matching: find.byType(OutlinedButton),
    );
    await tester.ensureVisible(remainingExpandButtons.first);
    await tester.tap(remainingExpandButtons.first);
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.text.toPlainText().contains('承诺不会兑现的事情。'),
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(OutlinedButton, '收起拆解'), findsNWidgets(2));
  });

  testWidgets('notes open a vocabulary panel without navigating away', (
    tester,
  ) async {
    controller.navigate(3);
    await tester.pumpWidget(WebLearningApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('empty promises').first);
    await tester.pumpAndSettle();
    expect(find.text('不会兑现的承诺'), findsOneWidget);
    expect(find.text('笔记'), findsWidgets);
    expect(controller.tab, 3);
  });

  testWidgets('notes open the selected non-featured vocabulary entry', (
    tester,
  ) async {
    controller.state.sentences.first.vocabulary.add(
      VocabularyEntry(id: 'v2', text: 'boss', meaning: '老板'),
    );
    controller.notifyListeners();
    controller.navigate(3);
    await tester.pumpWidget(WebLearningApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('boss').first);
    await tester.pumpAndSettle();
    expect(find.text('老板'), findsOneWidget);
    expect(find.text('不会兑现的承诺'), findsNothing);
  });

  testWidgets('notes hide optional controls when a sentence has no extras', (
    tester,
  ) async {
    controller.navigate(3);
    await tester.pumpWidget(WebLearningApp(controller: controller));
    await tester.pumpAndSettle();

    final secondCard = find.ancestor(
      of: find.text('I have to work late again today.'),
      matching: find.byType(Card),
    );
    expect(
      find.descendant(of: secondCard, matching: find.text('重点表达')),
      findsNothing,
    );
    expect(
      find.descendant(of: secondCard, matching: find.text('展开拆解')),
      findsNothing,
    );
  });

  testWidgets('notes preserve search and expanded cards within a session', (
    tester,
  ) async {
    controller.navigate(3);
    await tester.pumpWidget(WebLearningApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '老板');
    final expand = find.text('展开拆解').first;
    await tester.ensureVisible(expand);
    await tester.tap(expand);
    await tester.pumpAndSettle();

    controller.navigate(0);
    await tester.pumpAndSettle();
    controller.navigate(3);
    await tester.pumpAndSettle();

    expect(find.text('My boss is making empty promises again.'), findsNothing);
    expect(find.text('老板又在开空头支票。'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '收起拆解'), findsOneWidget);
  });

  testWidgets('notes show the matching empty state and can clear the query', (
    tester,
  ) async {
    controller.navigate(3);
    await tester.pumpWidget(WebLearningApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '完全不存在');
    await tester.pumpAndSettle();
    expect(find.text('没有匹配的句子'), findsOneWidget);
    await tester.tap(find.text('显示全部'));
    await tester.pumpAndSettle();
    expect(find.text('老板又在开空头支票。'), findsOneWidget);
  });

  testWidgets(
    'notes actions select a sentence before listening or practicing',
    (tester) async {
      controller.navigate(3);
      await tester.pumpWidget(WebLearningApp(controller: controller));
      await tester.pumpAndSettle();

      await tester.tap(find.text('听这句').first);
      await tester.pumpAndSettle();
      expect(controller.tab, 1);
      expect(controller.activeSentence?.id, 'one');

      controller.navigate(3);
      await tester.pumpAndSettle();
      await tester.tap(find.text('练这句').first);
      await tester.pumpAndSettle();
      expect(controller.tab, 2);
      expect(controller.activeSentence?.id, 'one');
    },
  );

  testWidgets('notes remain usable across target viewports and large text', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final width in [320.0, 390.0, 768.0, 1130.0, 1440.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      controller.navigate(3);
      await tester.pumpWidget(WebLearningApp(controller: controller));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'width=$width');
      expect(find.text('听这句'), findsWidgets, reason: 'width=$width');
    }

    await tester.binding.setSurfaceSize(const Size(390, 900));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(WebLearningApp(controller: controller));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final listen = find.text('听这句').first;
    await tester.ensureVisible(listen);
    expect(tester.getRect(listen).bottom, lessThanOrEqualTo(900));
  });

  test('vocabularySpans highlights the longest first match only', () {
    final spans = vocabularySpans('My boss is making empty promises again.', [
      VocabularyEntry(id: 'a', text: 'empty', meaning: '空的'),
      VocabularyEntry(id: 'b', text: 'empty promises', meaning: '不会兑现的承诺'),
    ]);
    expect(spans, hasLength(1));
    expect(spans.single.entry.id, 'b');
    expect(spans.single.start, 18);
  });

  test('featuredVocabulary returns only the first existing entry', () {
    final sentence = _note(
      id: 'featured',
      source: 'A sentence.',
      target: 'A sentence.',
      vocabulary: [
        VocabularyEntry(id: 'first', text: 'sentence', meaning: '句子'),
        VocabularyEntry(id: 'second', text: 'a', meaning: '一个'),
      ],
    );
    expect(featuredVocabulary(sentence)?.id, 'first');
    expect(
      featuredVocabulary(_note(id: 'empty', source: 'A', target: 'A')),
      isNull,
    );
  });

  test('vocabularySpans stays empty when the phrase is absent', () {
    final spans = vocabularySpans('See you tomorrow.', [
      VocabularyEntry(id: 'a', text: 'empty promises', meaning: '不会兑现的承诺'),
    ]);
    expect(spans, isEmpty);
  });
}
