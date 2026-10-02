import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/web/data/learning_gateway.dart';
import 'package:selah/web/domain/learning_models.dart';
import 'package:selah/web/learning_controller.dart';
import 'package:selah/web/platform/learning_platform.dart';
import 'package:selah/web/ui/listen_focus_controls.dart';
import 'package:selah/web/ui/web_learning_app.dart';

class _FocusPlatform implements LearningPlatform {
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
          'durationMs': 3000,
        };
        return null;
      case 'audioStop':
        audio = {'state': 'idle', 'positionMs': 0, 'durationMs': 0};
        return null;
      default:
        return null;
    }
  }
}

class _FocusSwitchingGateway extends UnconfiguredGateway {
  _FocusSwitchingGateway(this.current);

  String? current;
  final changes = StreamController<String?>.broadcast(sync: true);

  @override
  bool get configured => true;

  @override
  String? get userId => current;

  @override
  Stream<String?> get accountChanges => changes.stream;

  void switchTo(String? id) {
    current = id;
    changes.add(id);
  }

  Future<void> dispose() => changes.close();
}

const _pageFirstId = '00000000-0000-4000-8000-000000000011';
const _pageSecondId = '00000000-0000-4000-8000-000000000012';

Future<void> _pumpControls(
  WidgetTester tester, {
  String locale = 'zh-Hant',
  String state = 'idle',
  bool busy = false,
  double textScale = 1,
  Future<void> Function()? onPrevious,
  Future<void> Function()? onNext,
  Future<void> Function()? onPlayback,
}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: ListenFocusControls(
                uiLocale: locale,
                playbackState: {'state': state},
                busy: busy,
                onPrevious: onPrevious,
                onNext: onNext,
                onPlayback: onPlayback ?? () async {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('playback state labels follow the current sentence state', (
    tester,
  ) async {
    await _pumpControls(tester, state: 'idle');
    expect(find.text('播放'), findsOneWidget);

    await _pumpControls(tester, state: 'playing');
    expect(find.text('暫停'), findsOneWidget);

    await _pumpControls(tester, state: 'paused');
    expect(find.text('繼續播放'), findsOneWidget);

    await _pumpControls(tester, state: 'ended');
    expect(find.text('重聽'), findsOneWidget);

    await _pumpControls(tester, state: 'loading');
    expect(find.text('準備音訊…'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const ValueKey('listen-playback')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('listen-next')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('edge buttons disable while available callbacks run once', (
    tester,
  ) async {
    var previousCalls = 0;
    var nextCalls = 0;
    var playbackCalls = 0;
    await _pumpControls(
      tester,
      onPrevious: null,
      onNext: () async {
        nextCalls++;
      },
      onPlayback: () async {
        playbackCalls++;
      },
    );

    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const ValueKey('listen-previous')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const ValueKey('listen-next')));
    await tester.tap(find.byKey(const ValueKey('listen-playback')));
    await tester.pump();
    expect(previousCalls, 0);
    expect(nextCalls, 1);
    expect(playbackCalls, 1);

    await _pumpControls(
      tester,
      busy: true,
      onPrevious: () async {
        previousCalls++;
      },
      onNext: () async {
        nextCalls++;
      },
    );
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const ValueKey('listen-previous')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('listen-next')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('Japanese controls remain readable without overflow at 200%', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpControls(
      tester,
      locale: 'ja',
      state: 'paused',
      textScale: 2,
      onPrevious: () async {},
      onNext: () async {},
    );

    expect(find.text('前の文'), findsOneWidget);
    expect(find.text('次の文を聞く'), findsOneWidget);
    expect(find.text('再生を再開'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('ordinary listen page focus layout', () {
    late LearningController controller;
    late _FocusPlatform platform;
    late _FocusSwitchingGateway gateway;

    setUp(() async {
      TestWidgetsFlutterBinding
          .instance
          .platformDispatcher
          .accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: true,
      );
      platform = _FocusPlatform();
      gateway = _FocusSwitchingGateway('listen-account-a');
      controller = LearningController(
        gateway: gateway,
        platform: platform,
        seeds: const [],
        polling: false,
      );
      await controller.initialize();
      controller.state.preferences
        ..onboarded = true
        ..nativeLanguage = 'zh-Hant'
        ..motionEnabled = false;
      controller.state.sentences.addAll([
        LearnSentence(
          id: _pageFirstId,
          source: '今天我想慢慢整理自己的心情',
          target: List.filled(
            18,
            'I want to take a little time to understand how I feel today.',
          ).join(' '),
          category: 'daily_life',
        ),
        LearnSentence(
          id: _pageSecondId,
          source: '晚一點我會回覆你的訊息',
          target: 'I will reply to your message a little later.',
          category: 'friends',
        ),
      ]);
      controller.navigate(1);
      await controller.selectListenSentence(_pageFirstId);
    });

    tearDown(() async {
      controller.dispose();
      await gateway.dispose();
      TestWidgetsFlutterBinding.instance.platformDispatcher
          .clearAccessibilityFeaturesTestValue();
    });

    Future<void> pumpPage(
      WidgetTester tester, {
      Size size = const Size(390, 844),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(WebLearningApp(controller: controller));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'starts on one silent sentence and opens the library on demand',
      (tester) async {
        await pumpPage(tester);

        expect(
          find.byKey(const ValueKey('listen-sentence-picker')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('listen-library-button')),
          findsOneWidget,
        );
        expect(platform.actions, isNot(contains('audioPlay')));
      },
    );

    testWidgets('mobile controls stay fixed while answer content scrolls', (
      tester,
    ) async {
      await pumpPage(tester, size: const Size(390, 844));
      final controls = find.byKey(const ValueKey('listen-focus-controls'));
      final before = tester.getRect(controls);
      final scrollable = find.descendant(
        of: find.byKey(const ValueKey('listen-content-scroll')),
        matching: find.byType(Scrollable),
      );

      await tester.tap(find.byKey(const ValueKey('listen-reveal-answer')));
      await tester.pumpAndSettle();
      await tester.drag(scrollable, const Offset(0, -5000));
      await tester.pumpAndSettle();
      final scrollState = tester.state<ScrollableState>(scrollable);
      expect(scrollState.position.maxScrollExtent, greaterThan(0));
      expect(scrollState.position.pixels, scrollState.position.maxScrollExtent);

      expect(tester.getRect(controls).top, before.top);

      await tester.tap(find.byKey(const ValueKey('listen-next')));
      await tester.pumpAndSettle();
      expect(controller.activeSentence?.id, _pageSecondId);
      expect(scrollState.position.pixels, 0);
      expect(tester.getRect(controls).top, before.top);
      expect(tester.takeException(), isNull);
    });

    testWidgets('desktop keeps the sentence library closed until requested', (
      tester,
    ) async {
      await pumpPage(tester, size: const Size(1440, 900));

      expect(
        find.byKey(const ValueKey('listen-sentence-picker')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('listen-library-button')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('listen-focus-card')), findsOneWidget);
      expect(platform.actions, isNot(contains('audioPlay')));
    });

    testWidgets(
      'compact speed choices preserve presets and open custom alone',
      (tester) async {
        await pumpPage(tester);
        final strings = controller.strings;
        final speedButton = find.byKey(const ValueKey('listen-speed-compact'));
        final speedLabel = strings.translateLegacy('语速');
        expect(
          find.descendant(
            of: speedButton,
            matching: find.text('$speedLabel 1×'),
          ),
          findsOneWidget,
        );

        await tester.tap(speedButton);
        await tester.pumpAndSettle();
        expect(find.text(strings.text('listen.speedTitle')), findsOneWidget);
        for (final label in ['0.5×', '0.75×', '1×', '1.25×', '1.5×']) {
          expect(find.text(label), findsOneWidget);
        }
        await tester.tap(find.text(strings.text('settings.speed.custom')));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text(strings.text('listen.speedTitle')), findsNothing);
        final customSlider = tester.widget<Slider>(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(Slider),
          ),
        );
        expect(customSlider.min, minPlaybackSpeed);
        expect(customSlider.max, maxPlaybackSpeed);
        await tester.tap(find.text(strings.text('common.cancel')));
        await tester.pumpAndSettle();

        controller.state.preferences.speed = 1.125;
        controller.notifyListeners();
        await tester.pump();
        expect(
          find.descendant(
            of: speedButton,
            matching: find.text('$speedLabel 1.13×'),
          ),
          findsOneWidget,
        );

        await tester.tap(speedButton);
        await tester.pumpAndSettle();
        await tester.tap(find.text('1.25×'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text(strings.text('listen.speedTitle')), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'library selection is silent and its pin button does not select',
      (tester) async {
        await pumpPage(tester);
        await tester.tap(find.byKey(const ValueKey('listen-library-button')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('listen-sentence-picker')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(ValueKey('listen-pin-$_pageSecondId')));
        await tester.pumpAndSettle();
        expect(controller.activeSentence?.id, _pageFirstId);
        expect(
          find.byKey(const ValueKey('listen-sentence-picker')),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(ValueKey('listen-sentence-row-$_pageSecondId')),
        );
        await tester.pumpAndSettle();
        expect(controller.activeSentence?.id, _pageSecondId);
        expect(platform.actions, isNot(contains('audioPlay')));
      },
    );

    testWidgets('switching account dismisses the open sentence library', (
      tester,
    ) async {
      await pumpPage(tester);
      await tester.tap(find.byKey(const ValueKey('listen-library-button')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('listen-sentence-picker')),
        findsOneWidget,
      );

      gateway.switchTo('listen-account-b');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(controller.listenAccountScope, 'listen-account-b');
      expect(
        find.byKey(const ValueKey('listen-sentence-picker')),
        findsNothing,
      );
    });

    testWidgets('focus layout fits supported narrow and desktop viewports', (
      tester,
    ) async {
      const sizes = [
        Size(320, 640),
        Size(390, 844),
        Size(430, 932),
        Size(844, 390),
        Size(900, 700),
        Size(1024, 768),
        Size(1440, 900),
      ];
      for (final size in sizes) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(WebLearningApp(controller: controller));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('listen-focus-controls')),
          findsOneWidget,
          reason: 'focus controls should remain available at $size',
        );
        expect(tester.takeException(), isNull, reason: 'viewport $size');
      }
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    });
  });
}
