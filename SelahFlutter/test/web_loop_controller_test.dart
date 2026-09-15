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
        return null;
      case 'save':
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
  final requests = <({String function, bool get})>[];

  @override
  bool get configured => true;

  @override
  Future<Map<String, dynamic>> invoke(
    String function,
    Map<String, dynamic> body, {
    bool get = false,
  }) async {
    requests.add((function: function, get: get));
    throw StateError('guest must not call cloud');
  }
}

class _SignedInGateway extends _SignedOutGateway {
  _SignedInGateway() : super();

  @override
  String? get userId => 'user-1';

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

LearnSentence _sentence({String? seedId}) => LearnSentence(
  id: seedId == null ? 'personal-1' : 'sentence-$seedId',
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
    'guest personal sentences explain that login is needed without cloud calls',
    () async {
      final gateway = _SignedOutGateway();
      final controller = LearningController(
        gateway: gateway,
        platform: _LoopPlatform(),
        polling: false,
        seeds: const [],
      );
      addTearDown(controller.dispose);
      _setUpSentence(controller, _sentence());

      await controller.startLoop();

      expect(controller.loopReady, isFalse);
      expect(controller.error, '登录后即可为自己的句子补齐音频。');
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
      final key = 'loop:gentle-natural:target:en:${'a' * 64}';
      final sourceKey = 'loop:gentle-natural:source:zh-Hant:${'a' * 64}';
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
}
