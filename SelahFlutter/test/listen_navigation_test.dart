import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:selah/web/data/learning_gateway.dart';
import 'package:selah/web/domain/learning_models.dart';
import 'package:selah/web/learning_controller.dart';
import 'package:selah/web/platform/learning_platform.dart';

class _PlatformCall {
  const _PlatformCall(this.action, this.payload);

  final String action;
  final Map<String, Object?> payload;
}

class _NavigationPlatform implements LearningPlatform {
  final calls = <_PlatformCall>[];
  final snapshots = <String, Object?>{};
  Map<String, dynamic> audio = {
    'state': 'idle',
    'positionMs': 0,
    'durationMs': 0,
  };
  Completer<void>? audioPlayGate;
  Completer<void>? audioPlayStarted;
  Object? audioPlayError;

  @override
  Future<Object?> invoke(
    String action, [
    Map<String, Object?> payload = const {},
  ]) async {
    calls.add(_PlatformCall(action, Map<String, Object?>.from(payload)));
    switch (action) {
      case 'load':
        return snapshots[payload['accountId']];
      case 'save':
        snapshots[payload['accountId'] as String] = payload['snapshot'];
        return null;
      case 'platformInfo':
        return {'online': false};
      case 'contentHash':
        return 'a' * 64;
      case 'audioCached':
        return true;
      case 'audioStatus':
        return Map<String, dynamic>.from(audio);
      case 'audioPlay':
        if (!(audioPlayStarted?.isCompleted ?? true)) {
          audioPlayStarted!.complete();
        }
        await audioPlayGate?.future;
        if (audioPlayError case final error?) throw error;
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
      case 'audioPause':
        audio['state'] = 'paused';
        return null;
      case 'audioResume':
        audio['state'] = 'playing';
        return null;
      default:
        return null;
    }
  }
}

class _SwitchingGateway extends UnconfiguredGateway {
  _SwitchingGateway(this.current);

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

class _Harness {
  const _Harness(this.controller, this.platform);

  final LearningController controller;
  final _NavigationPlatform platform;
}

Future<_Harness> _harness({LearningGateway? gateway}) async {
  final platform = _NavigationPlatform();
  final controller = LearningController(
    gateway: gateway ?? UnconfiguredGateway(),
    platform: platform,
    seeds: const [],
    polling: false,
  );
  addTearDown(controller.dispose);
  await controller.initialize();
  return _Harness(controller, platform);
}

LearnSentence _sentence(String id, {bool archived = false}) => LearnSentence(
  id: id,
  source: '句子 $id',
  target: 'English $id',
  archived: archived,
);

const _a = '00000000-0000-4000-8000-000000000001';
const _b = '00000000-0000-4000-8000-000000000002';
const _c = '00000000-0000-4000-8000-000000000003';
const _old = '00000000-0000-4000-8000-000000000004';
const _only = '00000000-0000-4000-8000-000000000005';

int _countAction(_NavigationPlatform platform, String action) =>
    platform.calls.where((call) => call.action == action).length;

void main() {
  test(
    'listen sentences omit archived rows and follow current pin order',
    () async {
      final harness = await _harness();
      final controller = harness.controller;
      final first = _sentence(_a);
      final second = _sentence(_b);
      final pinned = _sentence(_c);
      controller.state.sentences.addAll([
        first,
        second,
        pinned,
        _sentence(_old, archived: true),
      ]);

      controller.togglePinnedSentence(pinned.id);

      expect(controller.listenSentences.map((sentence) => sentence.id), [
        _c,
        _a,
        _b,
      ]);
      expect(controller.listenAccountScope, 'guest');
    },
  );

  test(
    'previous and next navigate from the current position and play',
    () async {
      final harness = await _harness();
      final controller = harness.controller;
      final sentences = [_sentence(_a), _sentence(_b), _sentence(_c)];
      controller.state.sentences.addAll(sentences);
      controller.selectSentence(sentences[1]);

      await controller.moveListenSentence(_b, -1);
      expect(controller.activeSentence?.id, _a);
      await controller.moveListenSentence(_a, 1);
      expect(controller.activeSentence?.id, _b);

      expect(_countAction(harness.platform, 'audioPlay'), 2);
      expect(controller.state.events, isEmpty);
    },
  );

  test('navigation stops at both ends and ignores invalid offsets', () async {
    final harness = await _harness();
    final controller = harness.controller;
    final first = _sentence(_a);
    final last = _sentence(_b);
    controller.state.sentences.addAll([first, last]);

    controller.selectSentence(first);
    await controller.moveListenSentence(first.id, -1);
    await controller.moveListenSentence(first.id, 0);
    expect(controller.activeSentence?.id, first.id);

    controller.selectSentence(last);
    await controller.moveListenSentence(last.id, 1);
    expect(controller.activeSentence?.id, last.id);
    await controller.moveListenSentence('missing', 1);

    expect(_countAction(harness.platform, 'audioPlay'), 0);
  });

  test('empty and one-sentence lists do not wrap or play', () async {
    final harness = await _harness();
    final controller = harness.controller;
    await controller.moveListenSentence('missing', -1);
    expect(
      harness.platform.calls.where((call) => call.action == 'audioPlay'),
      isEmpty,
    );

    final only = _sentence(_only);
    controller.state.sentences.add(only);
    controller.selectSentence(only);
    await controller.moveListenSentence(only.id, -1);
    await controller.moveListenSentence(only.id, 1);

    expect(controller.activeSentence?.id, only.id);
    expect(_countAction(harness.platform, 'audioPlay'), 0);
  });

  test('pin changes are reflected in the next-sentence calculation', () async {
    final harness = await _harness();
    final controller = harness.controller;
    final first = _sentence(_a);
    final pinned = _sentence(_b);
    final third = _sentence(_c);
    controller.state.sentences.addAll([first, pinned, third]);
    controller.togglePinnedSentence(pinned.id);
    controller.selectSentence(first);

    await controller.moveListenSentence(first.id, 1);

    expect(controller.activeSentence?.id, third.id);
    expect(_countAction(harness.platform, 'audioPlay'), 1);
  });

  test(
    'recent entry selects the exact pinned position silently and repeats',
    () async {
      final harness = await _harness();
      final controller = harness.controller;
      final first = _sentence(_a);
      final second = _sentence(_b);
      final third = _sentence(_c);
      controller.state.sentences.addAll([first, second, third]);
      controller.togglePinnedSentence(third.id);
      await controller.setListenLoopMode(true);

      await controller.openRecentListenSentence(second.id);
      final position = controller.listenSentences.indexWhere(
        (sentence) => sentence.id == second.id,
      );
      expect(controller.tab, 1);
      expect(controller.activeSentence?.id, second.id);
      expect(controller.todayLessonFocus, isFalse);
      expect(controller.listenLoopMode, isFalse);
      expect(position, 2);
      expect(controller.listenFocusRequest, 1);
      expect(_countAction(harness.platform, 'audioPlay'), 0);
      expect(controller.state.events, isEmpty);

      await controller.openRecentListenSentence(second.id);
      expect(controller.activeSentence?.id, second.id);
      expect(controller.listenFocusRequest, 2);
      expect(_countAction(harness.platform, 'audioPlay'), 0);
    },
  );

  test(
    'recent entry rejects archived and cross-account sentence IDs',
    () async {
      final archivedHarness = await _harness();
      archivedHarness.controller.state.sentences.add(
        _sentence(_old, archived: true),
      );
      await archivedHarness.controller.openRecentListenSentence(_old);
      expect(
        archivedHarness.controller.errorCode,
        'listen_sentence_unavailable',
      );
      expect(_countAction(archivedHarness.platform, 'audioPlay'), 0);

      final gateway = _SwitchingGateway('account-a');
      addTearDown(gateway.dispose);
      final accountHarness = await _harness(gateway: gateway);
      final previousAccountSentence = _sentence(_a);
      accountHarness.controller.state.sentences.add(previousAccountSentence);
      gateway.switchTo('account-b');
      await pumpEventQueue();
      expect(accountHarness.controller.listenAccountScope, 'account-b');

      await accountHarness.controller.openRecentListenSentence(
        previousAccountSentence.id,
      );

      expect(accountHarness.controller.activeSentence, isNull);
      expect(
        accountHarness.controller.errorCode,
        'listen_sentence_unavailable',
      );
      expect(_countAction(accountHarness.platform, 'audioPlay'), 0);
    },
  );

  test(
    'silent selection stops another sentence and same-sentence selection preserves progress',
    () async {
      final harness = await _harness();
      final controller = harness.controller;
      final first = _sentence(_a);
      final second = _sentence(_b);
      controller.state.sentences.addAll([first, second]);

      await controller.selectListenSentence(first.id, autoplay: true);
      controller.playback['positionMs'] = 1250;
      final stopsBeforeSameSelection = _countAction(
        harness.platform,
        'audioStop',
      );
      await controller.selectListenSentence(first.id);

      expect(controller.playback['positionMs'], 1250);
      expect(
        _countAction(harness.platform, 'audioStop'),
        stopsBeforeSameSelection,
      );

      await controller.selectListenSentence(second.id);

      expect(controller.activeSentence?.id, second.id);
      expect(controller.playback['state'], 'idle');
      expect(_countAction(harness.platform, 'audioPlay'), 1);
    },
  );

  test(
    'stale sentence selection reports unavailable without playing',
    () async {
      final harness = await _harness();

      await harness.controller.selectListenSentence('removed-id');

      expect(harness.controller.errorCode, 'listen_sentence_unavailable');
      expect(_countAction(harness.platform, 'audioPlay'), 0);
    },
  );

  test(
    'only a matching real ended status records listen completion once',
    () async {
      final harness = await _harness();
      final controller = harness.controller;
      final first = _sentence(_a);
      final second = _sentence(_b);
      controller.state.sentences.addAll([first, second]);

      await controller.moveListenSentence(first.id, 1);
      expect(controller.state.events, isEmpty);
      expect(controller.playingSentence?.id, second.id);
      expect(controller.playback['state'], 'playing');
      expect(controller.playback['key'], harness.platform.audio['key']);
      harness.platform.audio = {
        'state': 'ended',
        'key': controller.playback['key'],
        'positionMs': 3000,
        'durationMs': 3000,
      };
      final savesBeforePoll = _countAction(harness.platform, 'save');
      await controller.poll();
      expect(controller.playback['state'], 'ended');
      expect(controller.error, isNull);
      expect(controller.errorCode, isNull, reason: controller.error);
      expect(
        _countAction(harness.platform, 'save'),
        greaterThan(savesBeforePoll),
      );
      await controller.poll();

      final completed = controller.state.events
          .where((event) => event.type == 'listen_completed')
          .toList();
      expect(completed, hasLength(1));
      expect(completed.single.sentenceId, second.id);
    },
  );

  test('rapid navigation accepts one in-flight next request', () async {
    final harness = await _harness();
    final controller = harness.controller;
    final sentences = [_sentence(_a), _sentence(_b), _sentence(_c)];
    controller.state.sentences.addAll(sentences);
    controller.selectSentence(sentences.first);
    harness.platform
      ..audioPlayGate = Completer<void>()
      ..audioPlayStarted = Completer<void>();

    final firstMove = controller.moveListenSentence(_a, 1);
    await harness.platform.audioPlayStarted!.future;
    await controller.moveListenSentence(_b, 1);
    harness.platform.audioPlayGate!.complete();
    await firstMove;

    expect(_countAction(harness.platform, 'audioPlay'), 1);
    expect(controller.activeSentence?.id, _b);
  });

  test(
    'late audio completion after account switch cannot mutate the new account',
    () async {
      final gateway = _SwitchingGateway('account-a');
      addTearDown(gateway.dispose);
      final harness = await _harness(gateway: gateway);
      final controller = harness.controller;
      final first = _sentence(_a);
      final second = _sentence(_b);
      controller.state.sentences.addAll([first, second]);
      harness.platform
        ..audioPlayGate = Completer<void>()
        ..audioPlayStarted = Completer<void>();

      final moving = controller.moveListenSentence(first.id, 1);
      await harness.platform.audioPlayStarted!.future;
      gateway.switchTo('account-b');
      await pumpEventQueue();
      expect(controller.listenAccountScope, 'account-b');
      expect(controller.initialized, isTrue);
      harness.platform.audioPlayGate!.complete();
      await moving;

      expect(controller.activeSentence, isNull);
      expect(controller.state.events, isEmpty);
      expect(controller.listenNavigationBusy, isFalse);
    },
  );
}
