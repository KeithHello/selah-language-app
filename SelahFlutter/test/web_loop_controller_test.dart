import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:selah/web/data/learning_gateway.dart';
import 'package:selah/web/domain/learning_models.dart';
import 'package:selah/web/learning_controller.dart';
import 'package:selah/web/platform/learning_platform.dart';

class _LoopPlatform implements LearningPlatform {
  _LoopPlatform({
    this.failAction,
    this.failMessage,
    this.loopStartState = 'playing',
    this.loopStartStopReason,
  });

  final String? failAction;
  final String? failMessage;
  final String loopStartState;
  final String? loopStartStopReason;
  final cached = <String>{};
  final hashes = <String, String>{};
  final actions = <String>[];
  final snapshots = <String, Object?>{};

  @override
  Future<Object?> invoke(
    String action, [
    Map<String, Object?> payload = const {},
  ]) async {
    actions.add(action);
    if (action == failAction) {
      throw StateError(failMessage ?? 'platform failure');
    }
    switch (action) {
      case 'load':
        return snapshots[payload['accountId']];
      case 'save':
        snapshots[payload['accountId'] as String] = payload['snapshot'];
        return null;
      case 'platformInfo':
        return {'online': true};
      case 'contentHash':
        return hashes[payload['text']] ?? 'a' * 64;
      case 'audioCached':
        return cached.contains(payload['key']);
      case 'audioEnsure':
        cached.add(payload['key'] as String);
        return {'cached': true};
      case 'audioCacheDelete':
        return cached.remove(payload['key']);
      case 'audioLoopStart':
        return {
          'sessionId': payload['sessionId'],
          'state': loopStartState,
          'phase': 'target',
          'sentenceIndex': 0,
          'sentenceCount': 1,
          'remainingMs': payload['durationMs'],
          'order': payload['order'],
          'stopReason': loopStartStopReason,
        };
      case 'audioLoopStatus':
        return {'state': 'playing'};
      case 'audioStop':
      case 'recordCancel':
        return null;
      default:
        return null;
    }
  }
}

class _SignedOutGateway extends UnconfiguredGateway {
  _SignedOutGateway({this.cloudConfigured = false});

  final bool cloudConfigured;
  final requests = <({String function, bool get})>[];

  @override
  bool get configured => cloudConfigured;

  @override
  String? get userId => user;

  String? user;

  @override
  bool get isAnonymous => false;

  @override
  Future<LearningSnapshot> synchronize(LearningSnapshot local) async => local;

  @override
  Future<Map<String, dynamic>> invoke(
    String function,
    Map<String, dynamic> body, {
    bool get = false,
  }) async {
    if (function == 'audio-generate' || function == 'audio-download-url') {
      requests.add((function: function, get: get));
    }
    if (function == 'membership-status' ||
        function == 'user-research-profile') {
      return const {};
    }
    throw StateError('guest must not call cloud');
  }
}

class _GeneratingGateway extends _SignedInGateway {
  _GeneratingGateway();

  final bodies = <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>> invoke(
    String function,
    Map<String, dynamic> body, {
    bool get = false,
  }) async {
    if (function == 'membership-status' ||
        function == 'user-research-profile') {
      return const {};
    }
    requests.add((function: function, get: get));
    bodies.add(Map<String, dynamic>.from(body));
    if (function == 'audio-generate') {
      return {
        'status': 'ready',
        'downloadUrl': 'http://127.0.0.1:5180/${body['voiceProfile']}.mp3',
      };
    }
    throw StateError('unexpected cloud function');
  }
}

class _SignedInGateway extends _SignedOutGateway {
  _SignedInGateway() : super(cloudConfigured: true) {
    user = '22222222-2222-4222-8222-222222222222';
  }

  @override
  String? get userId => '22222222-2222-4222-8222-222222222222';

  @override
  bool get isAnonymous => false;

  @override
  Future<Map<String, dynamic>> invoke(
    String function,
    Map<String, dynamic> body, {
    bool get = false,
  }) async {
    requests.add((function: function, get: get));
    if (function == 'audio-download-url') {
      return {'downloadUrl': 'http://127.0.0.1:5180/audio.mp3'};
    }
    throw StateError('unexpected cloud function');
  }

  @override
  Future<LearningSnapshot> synchronize(LearningSnapshot local) async => local;
}

class _UnregisteredGeneratingGateway extends _GeneratingGateway {
  _UnregisteredGeneratingGateway() {
    user = null;
  }

  @override
  String? get userId => user;

  @override
  bool get isAnonymous => false;
}

LearnSentence _sentence({String? seedId}) => LearnSentence(
  id: seedId == null
      ? '11111111-1111-4111-8111-111111111111'
      : 'sentence-$seedId',
  seedId: seedId,
  source: '一步一步来。',
  target: 'One step at a time.',
);

Map<String, Map<String, String>> _bundledSeedAudio() => {
  'seed-001:gentle-natural': {
    'path': 'assets/audio/seed-001-gentle-natural.mp3',
    'sha256': 'b' * 64,
  },
  'seed-001:source': {
    'path': 'assets/audio/seed-001-source.mp3',
    'sha256': 'c' * 64,
  },
};

void _setUpSentence(LearningController controller, LearnSentence sentence) {
  controller.state.sentences.add(sentence);
  controller.state.preferences.onboarded = true;
  controller.initialized = true;
}

void main() {
  test(
    'preparing a loop never starts playback, and a ready start skips preparation',
    () async {
      final platform = _LoopPlatform();
      final controller = LearningController(
        gateway: _SignedOutGateway(),
        platform: platform,
        polling: false,
        seeds: const [],
        bundledAudio: _bundledSeedAudio(),
      );
      addTearDown(controller.dispose);
      _setUpSentence(controller, _sentence(seedId: 'seed-001'));

      await controller.prepareLoop();
      expect(platform.actions, isNot(contains('audioLoopStart')));
      expect(controller.loopReady, isTrue);

      platform.actions.clear();
      await controller.startLoop();

      expect(platform.actions, contains('audioLoopStart'));
      expect(platform.actions, isNot(contains('audioCached')));
      expect(controller.notice, isNull);
    },
  );

  test(
    'autoplay blocking keeps the loop session visible for one-tap resume',
    () async {
      final platform = _LoopPlatform(
        loopStartState: 'ready',
        loopStartStopReason: 'autoplay_blocked',
      );
      final controller = LearningController(
        gateway: _SignedOutGateway(),
        platform: platform,
        polling: false,
        seeds: const [],
        bundledAudio: _bundledSeedAudio(),
      );
      addTearDown(controller.dispose);
      _setUpSentence(controller, _sentence(seedId: 'seed-001'));

      await controller.prepareLoop();
      await controller.startLoop();

      expect(controller.loopSessionId, isNotNull);
      expect(controller.loopSessionVisible, isTrue);
      expect(controller.loopActive, isFalse);

      await controller.resumeLoop();
      expect(platform.actions, contains('audioLoopResume'));
      expect(controller.loopSessionId, isNotNull);
    },
  );

  test('guest can start a bundled seed loop without cloud calls', () async {
    final platform = _LoopPlatform();
    final gateway = _SignedOutGateway();
    final controller = LearningController(
      gateway: gateway,
      platform: platform,
      polling: false,
      seeds: const [],
      bundledAudio: {
        'seed-001:gentle-natural': {
          'path': 'assets/audio/seed-001-gentle-natural.mp3',
          'sha256': 'b' * 64,
        },
        'seed-001:source': {
          'path': 'assets/audio/seed-001-source.mp3',
          'sha256': 'c' * 64,
        },
      },
    );
    addTearDown(controller.dispose);
    _setUpSentence(controller, _sentence(seedId: 'seed-001'));

    await controller.startLoop();

    expect(controller.loopReady, isTrue);
    expect(controller.loopSessionId, isNotNull);
    expect(platform.actions, contains('audioLoopStart'));
    expect(platform.actions, contains('audioUnlock'));
    expect(gateway.requests, isEmpty);
  });

  test('unchanged loop reuses verified tracks on the next session', () async {
    final platform = _LoopPlatform();
    final gateway = _GeneratingGateway();
    final controller = LearningController(
      gateway: gateway,
      platform: platform,
      polling: false,
      seeds: const [],
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    _setUpSentence(controller, _sentence());

    await controller.startLoop();
    await controller.stopLoop();
    platform.actions.clear();
    gateway.requests.clear();

    await controller.startLoop();

    expect(platform.actions, isNot(contains('audioCached')));
    expect(platform.actions, isNot(contains('audioEnsure')));
    expect(gateway.requests, isEmpty);
    expect(controller.loopSessionId, isNotNull);
  });

  test(
    'archived sentences leave the next loop and their orphan cache is deleted',
    () async {
      final platform = _LoopPlatform();
      final gateway = _GeneratingGateway();
      final controller = LearningController(
        gateway: gateway,
        platform: platform,
        polling: false,
        seeds: const [],
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      final first = _sentence();
      final second = LearnSentence(
        id: '22222222-2222-4222-8222-222222222222',
        source: '换一个表达。',
        target: 'Try another expression.',
      );
      platform.hashes[second.target] = 'b' * 64;
      platform.hashes[second.source] = 'c' * 64;
      controller.state.sentences.addAll([first, second]);
      controller.state.preferences.onboarded = true;
      controller.initialized = true;

      await controller.startLoop();
      await controller.stopLoop();
      platform.actions.clear();
      gateway.requests.clear();
      controller.state.sentences
              .firstWhere((sentence) => sentence.id == first.id)
              .archived =
          true;

      await controller.startLoop();

      expect(platform.actions, contains('audioCacheDelete'));
      expect(gateway.requests, isEmpty);
      expect(controller.loopSessionId, isNotNull);
    },
  );

  test(
    'guest personal sentences require a registered account before cloud audio',
    () async {
      final gateway = _UnregisteredGeneratingGateway();
      final controller = LearningController(
        gateway: gateway,
        platform: _LoopPlatform(),
        polling: false,
        seeds: const [],
      );
      addTearDown(controller.dispose);
      _setUpSentence(controller, _sentence());
      await controller.mergeBackup(
        LearningSnapshot.importBackup(jsonEncode(controller.state.toBackup())),
      );
      await controller.flushLocalWrites();

      await controller.prepareLoop();
      await controller.startLoop();

      expect(controller.hasSession, isFalse);
      expect(controller.errorCode, 'login_required');
      expect(gateway.requests, isEmpty);
    },
  );

  test(
    'known browser audio failures stay visible instead of becoming a generic error',
    () async {
      final controller = LearningController(
        gateway: _SignedOutGateway(),
        platform: _LoopPlatform(
          failAction: 'audioCached',
          failMessage: '音频缓存失败。',
        ),
        polling: false,
        seeds: const [],
      );
      addTearDown(controller.dispose);
      _setUpSentence(controller, _sentence());

      await controller.startLoop();

      expect(controller.error, '音频缓存失败');
    },
  );

  test(
    'signed-in manifest audio uses POST and accepts localhost download URLs',
    () async {
      final gateway = _SignedInGateway();
      final platform = _LoopPlatform();
      final controller = LearningController(
        gateway: gateway,
        platform: platform,
        polling: false,
        seeds: const [],
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      gateway.requests.clear();
      _setUpSentence(controller, _sentence());
      final key =
          'audio:v2:loop:openai:gentle-natural:1:gentle-natural:target:en:${'a' * 64}';
      final sourceKey =
          'audio:v2:loop:azure:zh-TW-HsiaoChenNeural@native-gentle:1:native-gentle:source:zh-Hant:${'a' * 64}';
      controller.state.audio[key] = {'manifestId': 'manifest-1'};
      controller.state.audio[sourceKey] = {'manifestId': 'manifest-2'};

      await controller.startLoop();

      expect(controller.loopReady, isTrue);
      expect(gateway.requests, hasLength(2));
      expect(
        gateway.requests,
        everyElement((function: 'audio-download-url', get: false)),
      );
      expect(platform.cached, contains(key));
    },
  );

  test(
    'signed-in personal loop generates source audio with the native voice',
    () async {
      final gateway = _GeneratingGateway();
      final platform = _LoopPlatform();
      final controller = LearningController(
        gateway: gateway,
        platform: platform,
        polling: false,
        seeds: const [],
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      gateway.requests.clear();
      _setUpSentence(controller, _sentence());
      controller.state.preferences.nativeVoice = 'native-calm';

      await controller.prepareLoop();

      expect(controller.loopReady, isTrue);
      expect(
        gateway.bodies.map((body) => body['voiceProfile']),
        containsAll(['gentle-natural', 'native-calm']),
      );
      expect(
        gateway.bodies.where((body) => body['voiceProfile'] == 'native-calm'),
        isNotEmpty,
      );
      final sourceBody = gateway.bodies.firstWhere(
        (body) => body['voiceProfile'] == 'native-calm',
      );
      expect(sourceBody['contractVersion'], 2);
      expect(sourceBody['text'], '一步一步来。');
      expect(sourceBody['audioRole'], 'source');
      expect(sourceBody['sourceLanguage'], 'zh-Hant');
      expect(sourceBody['targetLanguage'], 'en');
      expect(sourceBody['accent'], 'zh-TW');
    },
  );
}
