import 'package:flutter_test/flutter_test.dart';
import 'package:selah/web/data/learning_gateway.dart';
import 'package:selah/web/domain/learning_models.dart';
import 'package:selah/web/learning_controller.dart';
import 'package:selah/web/platform/learning_platform.dart';

class _Platform implements LearningPlatform {
  _Platform({required this.bundled});

  final Map<String, dynamic> bundled;
  final List<String> ensured = [];
  final List<String> ensuredUrls = [];
  final List<String> loopStarted = [];

  @override
  Future<Object?> invoke(
    String action, [
    Map<String, Object?> payload = const {},
  ]) async {
    switch (action) {
      case 'platformInfo':
        return {'online': true};
      case 'contentHash':
        return 'a' * 64;
      case 'audioEnsure':
        ensured.add(payload['key'] as String);
        ensuredUrls.add(payload['url'] as String);
        return {'cached': true};
      case 'audioCached':
        return ensured.contains(payload['key']);
      case 'audioLoopStart':
        loopStarted.add(payload['sessionId'] as String);
        return {
          'state': 'playing',
          'phase': 'target',
          'sentenceIndex': 0,
          'sentenceCount': 1,
        };
      case 'audioLoopStatus':
        return {'state': 'playing'};
      default:
        return null;
    }
  }
}

class _Gateway extends UnconfiguredGateway {
  bool called = false;

  @override
  Future<Map<String, dynamic>> invoke(
    String function,
    Map<String, dynamic> body, {
    bool get = false,
  }) async {
    called = true;
    throw StateError('local seed loop must not call cloud');
  }
}

void main() {
  test(
    'seed loop prepares offline with bundled target and native audio',
    () async {
      final platform = _Platform(
        bundled: {
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
      final gateway = _Gateway();
      final controller = LearningController(
        gateway: gateway,
        platform: platform,
        polling: false,
        seeds: const [],
        bundledAudio: platform.bundled,
      );
      controller.state.sentences.add(
        LearnSentence(
          id: 'sentence-1',
          seedId: 'seed-001',
          source: '你好',
          target: 'Hello',
        ),
      );
      controller.initialized = true;

      await controller.startLoop();

      expect(controller.loopReady, isTrue);
      expect(platform.loopStarted, hasLength(1));
      expect(gateway.called, isFalse);
      expect(platform.ensured, hasLength(2));
      expect(
        platform.ensuredUrls,
        everyElement(contains('/assets/assets/audio/seed-001-')),
      );
    },
  );

  test('bundled Japanese seed uses the Japanese native audio source', () async {
    final platform = _Platform(
      bundled: {
        'seed-006:gentle-natural': {
          'path': 'assets/audio/seed-006-gentle-natural.mp3',
          'sha256': 'b' * 64,
        },
        'seed-006:source:ja': {
          'path': 'assets/audio/seed-006-source-ja.mp3',
          'sha256': 'c' * 64,
        },
      },
    );
    final controller = LearningController(
      gateway: _Gateway(),
      platform: platform,
      polling: false,
      seeds: const [],
      bundledAudio: platform.bundled,
    );
    controller.state.preferences.nativeLanguage = 'ja';
    controller.state.sentences.add(
      LearnSentence(
        id: 'sentence-jp',
        seedId: 'seed-006',
        source: 'その服めっちゃいいね、リンク教えて。',
        target: 'Your outfit is fire. Drop the link please.',
        sourceLanguage: 'ja',
      ),
    );
    controller.initialized = true;

    await controller.startLoop();
    expect(controller.loopReady, isTrue);

    expect(platform.loopStarted, hasLength(1));
    expect(platform.ensured.any((key) => key.contains(':source:ja:')), isTrue);
  });

  test(
    'Japanese preference exposes bundled seeds with Japanese source text',
    () {
      final controller = LearningController(
        gateway: _Gateway(),
        platform: _Platform(bundled: const {}),
        polling: false,
        seeds: [
          LearnSentence.seed({
            'id': 'seed-006',
            'zh_text': '你這個穿搭絕了，求連結',
            'ja_text': 'その服めっちゃいいね、リンク教えて。',
            'en_translation': 'Your outfit is fire. Drop the link please.',
            'category': 'friends',
            'deconstruction': const [],
            'vocab_candidates': const [],
          }),
        ],
        bundledAudio: const {},
      );

      controller.state.preferences.nativeLanguage = 'ja';

      expect(controller.seeds.single.sourceLanguage, 'ja');
      expect(controller.seeds.single.source, contains('リンク'));
    },
  );
}
