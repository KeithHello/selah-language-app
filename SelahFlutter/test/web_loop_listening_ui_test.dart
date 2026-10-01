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
      final firstTrack = (payload['tracks'] as List).first as Map;
      final sentenceIds = (payload['tracks'] as List)
          .map((track) => (track as Map)['sentenceId'])
          .toSet();
      loop = {
        'sessionId': payload['sessionId'],
        'state': autoplayBlocked ? 'ready' : 'playing',
        'phase': autoplayBlocked ? null : 'target',
        'sentenceId': firstTrack['sentenceId'],
        'positionMs': autoplayBlocked ? null : 3000,
        'durationMs': autoplayBlocked ? null : 12000,
        'sentenceIndex': 0,
        'sentenceCount': sentenceIds.length,
        'remainingMs': payload['durationMs'],
        'order': payload['order'],
        'stopReason': autoplayBlocked ? 'autoplay_blocked' : null,
      };
    }
    if (action == 'audioLoopStatus') return loop;
    if (action == 'audioLoopOrder') loop['order'] = payload['order'];
    if (action == 'audioLoopPause') {
      loop['state'] = 'paused';
      return loop;
    }
    if (action == 'audioLoopResume') {
      loop['state'] = 'playing';
      return loop;
    }
    if (action == 'audioLoopNext') {
      loop['sentenceIndex'] = 0;
      return loop;
    }
    if (action == 'audioLoopStop') {
      loop = {'state': 'idle'};
      return loop;
    }
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

Future<void> _pumpUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void _setViewport(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
}

void _resetViewport(WidgetTester tester) {
  tester.view.resetPhysicalSize();
  tester.view.resetDevicePixelRatio();
}

void main() {
  testWidgets(
    'loop mode shares the sentence card and keeps mode-specific controls',
    (tester) async {
      _setViewport(tester, const Size(1280, 900));
      addTearDown(() => _resetViewport(tester));
      final platform = _LoopPlatform();
      final controller = await _controllerFor(platform);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(home: WebLearningApp(controller: controller)),
      );
      controller.navigate(1);
      await _pumpUi(tester);
      await tester.tap(find.text('循環聽'));
      await _pumpUi(tester);

      expect(controller.listenLoopMode, isTrue);
      expect(find.byKey(const ValueKey('listen-focus-card')), findsOneWidget);
      expect(find.byKey(const ValueKey('loop-status')), findsOneWidget);
      expect(find.byKey(const ValueKey('listen-library-button')), findsNothing);
      expect(find.byKey(const ValueKey('loop-mini-player')), findsNothing);
      expect(find.text('我们一步一步来。'), findsOneWidget);
      expect(find.text('准备循环听'), findsNothing);

      final settingsButton = find.byKey(const ValueKey('listen-previous'));
      await tester.ensureVisible(settingsButton);
      await tester.tap(settingsButton);
      await _pumpUi(tester);
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('30 分鐘'), findsWidgets);
      await tester.tap(find.byTooltip(controller.strings.text('common.close')));
      await _pumpUi(tester);

      final playButton = find.byKey(const ValueKey('listen-playback'));
      await tester.tap(playButton);
      await _pumpUi(tester);
      expect(controller.loopReady, isTrue);
      expect(platform.loop['state'], 'idle');

      await tester.tap(playButton);
      await _pumpUi(tester);
      expect(controller.loopPlayback['state'], 'playing');
      expect(find.text('正在播放英語'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
      expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNull);

      await tester.tap(find.text('逐句聽'));
      await _pumpUi(tester);
      expect(controller.listenLoopMode, isFalse);
      expect(controller.loopPlayback['state'], 'paused');
      expect(find.byKey(const ValueKey('loop-status')), findsNothing);

      controller.playback = {'state': 'playing', 'positionMs': 1200};
      await tester.tap(find.text('循環聽'));
      await _pumpUi(tester);
      expect(controller.playback['state'], 'paused');
      expect(controller.loopPlayback['state'], 'paused');
      expect(find.byKey(const ValueKey('listen-focus-card')), findsOneWidget);

      controller.navigate(0);
      await _pumpUi(tester);
      expect(find.byKey(const ValueKey('loop-mini-player')), findsOneWidget);
    },
  );

  testWidgets('mobile loop settings open in a bottom sheet and save duration', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    addTearDown(() => _resetViewport(tester));
    final platform = _LoopPlatform();
    final controller = await _controllerFor(platform);
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
    await _pumpUi(tester);
    await tester.tap(find.text('循環聽'));
    await _pumpUi(tester);

    await tester.tap(find.byKey(const ValueKey('listen-previous')));
    await _pumpUi(tester);
    expect(find.byType(BottomSheet), findsOneWidget);
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
    await _pumpUi(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('自訂 · 45 分鐘'), findsOneWidget);
    expect(controller.state.preferences.loopOptions.durationMinutes, 45);
    // Let the auto-dismiss notice timer fire before the test ends.
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets(
    'loop card follows the audio queue instead of pinned listen order',
    (tester) async {
      final platform = _LoopPlatform();
      final controller = await _controllerFor(platform);
      addTearDown(controller.dispose);
      controller.state.sentences.add(
        LearnSentence(
          id: '00000000-0000-4000-8000-000000000002',
          source: '第二句排在逐句听前面。',
          target: 'The second sentence is pinned first.',
        ),
      );
      controller.state.pinnedSentenceIds.add(
        '00000000-0000-4000-8000-000000000002',
      );

      await tester.pumpWidget(
        MaterialApp(home: WebLearningApp(controller: controller)),
      );
      controller.navigate(1);
      await _pumpUi(tester);
      expect(find.text('第二句排在逐句听前面。'), findsOneWidget);

      await tester.tap(find.text('循環聽'));
      await _pumpUi(tester);
      final playButton = find.byKey(const ValueKey('listen-playback'));
      await tester.tap(playButton);
      await _pumpUi(tester);
      await tester.tap(playButton);
      await _pumpUi(tester);

      expect(find.text('我们一步一步来。'), findsOneWidget);
      expect(find.text('第二句排在逐句听前面。'), findsNothing);
      expect(find.text('第 1／2 句'), findsOneWidget);
    },
  );

  testWidgets('autoplay blocked status stays on the same card for retry', (
    tester,
  ) async {
    final controller = await _controllerFor(
      _LoopPlatform(autoplayBlocked: true),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: WebLearningApp(controller: controller)),
    );
    controller.navigate(1);
    await _pumpUi(tester);
    await tester.tap(find.text('循環聽'));
    await _pumpUi(tester);
    final playButton = find.byKey(const ValueKey('listen-playback'));
    await tester.tap(playButton);
    await _pumpUi(tester);
    await tester.tap(playButton);
    await _pumpUi(tester);

    expect(controller.loopPlayback['state'], 'ready');
    expect(find.text('再點一下繼續播放。'), findsOneWidget);
    expect(find.byKey(const ValueKey('listen-focus-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('loop-mini-player')), findsNothing);
    await tester.tap(playButton);
    await _pumpUi(tester);
    expect(controller.loopPlayback['state'], 'playing');
  });

  testWidgets('both listen modes fit the supported responsive breakpoints', (
    tester,
  ) async {
    final controller = await _controllerFor(_LoopPlatform());
    addTearDown(controller.dispose);
    addTearDown(() => _resetViewport(tester));
    controller.listenLoopMode = true;
    await tester.pumpWidget(
      MaterialApp(home: WebLearningApp(controller: controller)),
    );
    controller.navigate(1);
    await _pumpUi(tester);

    for (final width in <double>[320, 390, 759, 899, 900, 1280, 1440]) {
      _setViewport(tester, Size(width, 900));
      await _pumpUi(tester);
      expect(find.byKey(const ValueKey('listen-focus-card')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('listen-focus-controls')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull, reason: 'viewport $width');
    }
  });
}
