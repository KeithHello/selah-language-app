import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/web/domain/learning_models.dart';
import 'package:selah/web/data/learning_gateway.dart';
import 'package:selah/web/learning_controller.dart';
import 'package:selah/web/platform/learning_platform.dart';
import 'package:selah/web/ui/web_learning_app.dart';

class _LoopPlatform implements LearningPlatform {
  _LoopPlatform({this.autoplayBlocked = false});

  final bool autoplayBlocked;
  Map<String, dynamic> loop = {'state': 'idle'};

  @override
  Future<Object?> invoke(
    String action, [
    Map<String, Object?> payload = const {},
  ]) async {
    if (action == 'platformInfo') return {'online': true};
    if (action == 'contentHash') return 'a' * 64;
    if (action == 'audioCached') return true;
    if (action == 'audioLoopStart') {
      loop = {
        'sessionId': payload['sessionId'],
        'state': autoplayBlocked ? 'ready' : 'playing',
        'phase': 'target',
        'sentenceIndex': 0,
        'sentenceCount': 1,
        'remainingMs': payload['durationMs'],
        'order': payload['order'],
        'stopReason': autoplayBlocked ? 'autoplay_blocked' : null,
      };
    }
    if (action == 'audioLoopStatus') return loop;
    if (action == 'audioLoopOrder') loop['order'] = payload['order'];
    if (action == 'audioLoopPause') loop['state'] = 'paused';
    if (action == 'audioLoopResume') loop['state'] = 'playing';
    if (action == 'audioLoopNext') loop['sentenceIndex'] = 0;
    if (action == 'audioLoopStop') loop = {'state': 'idle'};
    return null;
  }
}

Future<LearningController> _controllerFor(_LoopPlatform platform) async {
  final controller = LearningController(
    gateway: _Gateway(),
    platform: platform,
    polling: false,
    seeds: const [],
  );
  controller.state.sentences.add(
    LearnSentence(
      id: '00000000-0000-4000-8000-000000000001',
      source: '我们一步一步来。',
      target: 'One step at a time.',
    ),
  );
  controller.state.preferences.onboarded = true;
  controller.initialized = true;
  return controller;
}

class _Gateway extends UnconfiguredGateway {
  @override
  Future<LearningSnapshot> synchronize(LearningSnapshot local) async => local;
  @override
  Future<Map<String, dynamic>> invoke(
    String function,
    Map<String, dynamic> body, {
    bool get = false,
  }) async => {};
}

void main() {
  testWidgets('listen page exposes loop setup and starts a bilingual loop', (
    tester,
  ) async {
    final platform = _LoopPlatform();
    final controller = LearningController(
      gateway: _Gateway(),
      platform: platform,
      polling: false,
      seeds: const [],
    );
    controller.state.sentences.add(
      LearnSentence(
        id: '00000000-0000-4000-8000-000000000001',
        source: '我们一步一步来。',
        target: 'One step at a time.',
      ),
    );
    controller.state.preferences.onboarded = true;
    controller.initialized = true;

    await tester.pumpWidget(
      MaterialApp(home: WebLearningApp(controller: controller)),
    );
    controller.navigate(1);
    await tester.pump();
    await tester.tap(find.text('循環聽'));
    await tester.pump();

    expect(find.text('英語 → 中文'), findsOneWidget);
    expect(find.text('30 分鐘'), findsWidgets);
    expect(find.text('開始循環聽'), findsOneWidget);

    final startButton = find.text('開始循環聽');
    await tester.ensureVisible(startButton);
    await tester.tap(
      find.ancestor(of: startButton, matching: find.byType(FilledButton)),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('正在播放英語'), findsOneWidget);
    expect(find.textContaining('30:00'), findsWidgets);
    expect(find.text('預設語速'), findsOneWidget);
    expect(find.text('1x'), findsWidgets);
    expect(find.text('1.25x'), findsWidgets);
    await tester.ensureVisible(find.text('1.25x'));
    await tester.tap(find.text('1.25x'));
    await tester.pump();
    expect(controller.state.preferences.speed, 1.25);
  });

  testWidgets('custom duration keeps the chip visible and saves free input', (
    tester,
  ) async {
    final platform = _LoopPlatform();
    final controller = LearningController(
      gateway: _Gateway(),
      platform: platform,
      polling: false,
      seeds: const [],
    );
    addTearDown(controller.dispose);
    controller.state.sentences.add(
      LearnSentence(
        id: '00000000-0000-4000-8000-000000000002',
        source: '我们一步一步来。',
        target: 'One step at a time.',
      ),
    );
    controller.state.preferences.onboarded = true;
    controller.initialized = true;

    await tester.pumpWidget(
      MaterialApp(home: WebLearningApp(controller: controller)),
    );
    controller.navigate(1);
    await tester.pump();
    await tester.tap(find.text('循環聽'));
    await tester.pump();

    expect(find.text('自訂'), findsOneWidget);
    await tester.tap(find.text('自訂'));
    await tester.pump();
    expect(find.byType(TextField), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '30',
    );
    await tester.enterText(find.byType(TextField), '45');
    await tester.tap(find.text('確認'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // The save is asynchronous; one extra frame lets the controller's
    // notification close the dialog after the write completes.
    await tester.pump();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('自訂 · 45 分鐘'), findsOneWidget);
    expect(controller.state.preferences.loopOptions.durationMinutes, 45);
  });

  testWidgets('loop setup explains when the browser blocks autoplay', (
    tester,
  ) async {
    final controller = await _controllerFor(_LoopPlatform(autoplayBlocked: true));
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: WebLearningApp(controller: controller)),
    );
    controller.navigate(1);
    await tester.pump();
    await tester.tap(find.text('循環聽'));
    await tester.pump();
    final startButton = find.text('開始循環聽');
    await tester.ensureVisible(startButton);
    await tester.tap(
      find.ancestor(of: startButton, matching: find.byType(FilledButton)),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('音訊已準備好，請點擊播放。'), findsOneWidget);
  });
}
