import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:selah/web/data/learning_gateway.dart';
import 'package:selah/web/domain/learning_models.dart';
import 'package:selah/web/learning_controller.dart';
import 'package:selah/web/platform/learning_platform.dart';

class _LoopPlatform implements LearningPlatform {
  _LoopPlatform({this.failAction, this.failMessage});

  final String? failAction;
  final String? failMessage;
  final cached = <String>{};
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
        return 'a' * 64;
      case 'audioCached':
        return cached.contains(payload['key']);
      case 'audioEnsure':
        cached.add(payload['key'] as String);
        return {'cached': true};
      case 'audioLoopStart':
        return {
          'sessionId': payload['sessionId'],
          'state': 'playing',
          'phase': 'target',
          'sentenceIndex': 0,
          'sentenceCount': 1,
          'remainingMs': payload['durationMs'],
          'order': payload['order'],
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
  bool get isAnonymous => user != null;

  @override
  Future<void> signInAnonymously() async {
    user = '33333333-3333-4333-8333-333333333333';
  }

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

class _AnonymousGeneratingGateway extends _GeneratingGateway {
  _AnonymousGeneratingGateway() {
    user = null;
  }

  @override
  String? get userId => user;

  @override
  bool get isAnonymous => user != null;
}

LearnSentence _sentence({String? seedId}) => LearnSentence(
  id: seedId == null
      ? '11111111-1111-4111-8111-111111111111'
      : 'sentence-$seedId',
  seedId: seedId,
  source: '一步一步来。',
  target: 'One step at a time.',
);

void _setUpSentence(LearningController controller, LearnSentence sentence) {
  controller.state.sentences.add(sentence);
  controller.state.preferences.onboarded = true;
  controller.initialized = true;
}

void main() {
  test(
    'guest can prepare and then start bundled seed loop without cloud calls',
    () async {
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
      expect(controller.loopSessionId, isNull);
      expect(gateway.requests, isEmpty);

      await controller.startLoop();

      expect(controller.loopSessionId, isNotNull);
      expect(platform.actions, contains('audioLoopStart'));
      expect(gateway.requests, isEmpty);
    },
  );

  test(
    'guest personal sentences open an anonymous cloud session and generate audio',
    () async {
      final gateway = _AnonymousGeneratingGateway();
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

      // ignore: avoid_print
      expect(controller.hasSession, isTrue);
      expect(
        gateway.requests.map((request) => request.function),
        contains('audio-generate'),
      );
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
      final key = 'loop:gentle-natural:target:en:${'a' * 64}';
      final sourceKey = 'loop:native-gentle:source:zh-Hant:${'a' * 64}';
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
    },
  );
}
