import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/web/data/learning_gateway.dart';
import 'package:selah/web/domain/companion_names.dart';
import 'package:selah/web/domain/learning_models.dart';
import 'package:selah/web/learning_controller.dart';
import 'package:selah/web/platform/learning_platform.dart';
import 'package:selah/web/ui/companion_dice_button.dart';
import 'package:selah/web/ui/web_learning_app.dart';

class _FakePlatform implements LearningPlatform {
  Map<String, dynamic>? saved;
  bool failSave = false;
  final actions = <String>[];
  Map<String, dynamic> info = {
    'online': false,
    'storage': true,
    'audio': true,
    'storagePersisted': null,
    'installKind': 'unsupported',
    'installed': false,
    'canInstall': false,
    'updateAvailable': false,
    'buildId': 'dev',
  };

  @override
  Future<Object?> invoke(
    String action, [
    Map<String, Object?> payload = const {},
  ]) async {
    actions.add(action);
    switch (action) {
      case 'load':
        return saved;
      case 'save':
        if (failSave) throw const LearningFailure('本机保存失败，请重试。');
        saved = Map<String, dynamic>.from(payload['snapshot']! as Map);
        return true;
      case 'platformInfo':
        return Map<String, dynamic>.from(info);
      case 'audioStatus':
        return null;
      case 'requestStoragePersistence':
        return true;
      default:
        return null;
    }
  }
}

LearnSentence _seed(int index) => LearnSentence.seed({
  'id': 'seed-${index.toString().padLeft(3, '0')}',
  'zh_text': [
    '今天想早点休息。',
    '我终于把这件事做完了。',
    '周末想和朋友见面。',
    '明天早上要早点出门。',
    '我想把英语练习坚持下去。',
    '今天要记得给朋友回消息。',
  ][index - 1],
  'en_translation': [
    'I want to get some rest early today.',
    'I finally finished this.',
    'I want to see my friends this weekend.',
    'I need to leave early tomorrow morning.',
    'I want to keep up my English practice.',
    'I need to remember to reply to my friend today.',
  ][index - 1],
  'category': [
    'daily_life',
    'work',
    'friends',
    'friends',
    'daily_life',
    'work',
  ][index - 1],
  'deconstruction': const [],
  'vocab_candidates': const [],
});

void main() {
  group('CompanionNamePool data integrity', () {
    test('contains exactly 100 unique entries', () {
      expect(CompanionNamePool.all.length, 100);
      final ids = CompanionNamePool.all.map((e) => e.id).toSet();
      expect(ids.length, 100);
      expect(ids.reduce(min), 1);
      expect(ids.reduce(max), 100);
    });

    test('category distributions match approved design', () {
      final workplace = CompanionNamePool.all
          .where((e) => e.category == CompanionNameCategory.workplace)
          .toList();
      final campus = CompanionNamePool.all
          .where((e) => e.category == CompanionNameCategory.campus)
          .toList();
      final lowBattery = CompanionNamePool.all
          .where((e) => e.category == CompanionNameCategory.lowBattery)
          .toList();
      final gentleTwist = CompanionNamePool.all
          .where((e) => e.category == CompanionNameCategory.gentleTwist)
          .toList();
      final foodSupply = CompanionNamePool.all
          .where((e) => e.category == CompanionNameCategory.foodSupply)
          .toList();
      final absurd = CompanionNamePool.all
          .where((e) => e.category == CompanionNameCategory.absurdEasterEgg)
          .toList();

      expect(workplace.length, 20);
      expect(campus.length, 20);
      expect(lowBattery.length, 20);
      expect(gentleTwist.length, 20);
      expect(foodSupply.length, 10);
      expect(absurd.length, 10);

      // Default pool only contains lowBattery, gentleTwist, foodSupply, absurdEasterEgg (60 items)
      expect(CompanionNamePool.defaultInitialPool.length, 60);
      expect(
        CompanionNamePool.defaultInitialPool.every((e) => e.isInitialDefault),
        isTrue,
      );
      expect(workplace.every((e) => !e.isInitialDefault), isTrue);
      expect(campus.every((e) => !e.isInitialDefault), isTrue);
    });

    test('every entry has valid non-empty fields in all 3 languages', () {
      for (final e in CompanionNamePool.all) {
        expect(e.concept.trim(), isNotEmpty);
        expect(e.zhHant.trim(), isNotEmpty);
        expect(e.zhHans.trim(), isNotEmpty);
        expect(e.ja.trim(), isNotEmpty);
        expect(e.tone.trim(), isNotEmpty);

        expect(e.nameForLanguage('zh-Hant'), e.zhHant);
        expect(e.nameForLanguage('zh-Hans'), e.zhHans);
        expect(e.nameForLanguage('ja'), e.ja);
      }
    });

    test('initialDefaultName draws from the 60 initial default pool', () {
      final defaultHantNames = CompanionNamePool.defaultInitialPool
          .map((e) => e.zhHant)
          .toSet();
      for (var i = 0; i < 30; i++) {
        final name = CompanionNamePool.initialDefaultName('zh-Hant');
        expect(defaultHantNames.contains(name), isTrue);
      }
    });

    test('randomName avoids returning the current name when possible', () {
      final first = CompanionNamePool.randomName('zh-Hant');
      final second = CompanionNamePool.randomName(
        'zh-Hant',
        currentName: first,
      );
      expect(second, isNot(equals(first)));
    });
  });

  group('CompanionDiceButton and Settings integration', () {
    late _FakePlatform platform;
    late LearningController controller;

    setUp(() async {
      TestWidgetsFlutterBinding
          .instance
          .platformDispatcher
          .accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: true,
      );
      platform = _FakePlatform();
      controller = LearningController(
        gateway: UnconfiguredGateway(),
        platform: platform,
        seeds: List.generate(6, (index) => _seed(index + 1)),
        polling: false,
      );
      await controller.initialize();
      controller.state.preferences.uiLocale = 'zh-Hans';
    });

    tearDown(() {
      controller.dispose();
      TestWidgetsFlutterBinding.instance.platformDispatcher
          .clearAccessibilityFeaturesTestValue();
    });

    testWidgets('CompanionDiceButton animates and rolls a new name', (
      tester,
    ) async {
      String? rolled;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompanionDiceButton(
              tooltip: '隨機換一個名字',
              languageCode: 'zh-Hant',
              currentName: '加班芽',
              onRolled: (name) => rolled = name,
            ),
          ),
        ),
      );

      expect(find.byType(CompanionDiceButton), findsOneWidget);
      expect(find.byIcon(Icons.casino_outlined), findsOneWidget);

      await tester.tap(find.byType(CompanionDiceButton));
      await tester.pump();
      expect(rolled, isNotNull);
      expect(rolled, isNot(equals('加班芽')));
    });

    testWidgets('Settings dialog exposes dice button and allows updating name', (
      tester,
    ) async {
      controller.state.preferences.onboarded = true;
      controller.state.preferences.name = '小芽';

      await tester.pumpWidget(WebLearningApp(controller: controller));
      await tester.pumpAndSettle();

      // Navigate to settings tab
      await tester.tap(find.text('设置'));
      await tester.pumpAndSettle();

      // Find the companion section in settings
      expect(find.byType(CompanionDiceButton), findsOneWidget);

      final textField = find.byType(TextField).first;
      expect(tester.widget<TextField>(textField).controller!.text, '小芽');

      // Ensure dice button is scrolled into view in Settings dialog
      await tester.ensureVisible(find.byType(CompanionDiceButton));
      await tester.pumpAndSettle();

      // Tap dice button to roll a new name
      await tester.tap(find.byType(CompanionDiceButton));
      await tester.pump();

      final updatedName =
          tester.widget<TextField>(textField).controller!.text;
      expect(updatedName, isNotEmpty);
      expect(updatedName, isNot(equals('小芽')));

      // Save the newly rolled name
      await tester.tap(find.text('保存'));
      await tester.runAsync(() async {
        for (var i = 0; i < 20 && controller.busy; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      });
      await tester.pump(const Duration(milliseconds: 100));

      expect(controller.state.preferences.name, updatedName);
    });
  });
}
