import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/web/data/learning_gateway.dart';
import 'package:selah/web/domain/learning_models.dart';
import 'package:selah/web/domain/web_status.dart';
import 'package:selah/web/learning_controller.dart';
import 'package:selah/web/platform/learning_platform.dart';

class MemoryPlatform implements LearningPlatform {
  final snapshots = <String, Object?>{};
  bool failSave = false;
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
    switch (action) {
      case 'load':
        return snapshots[payload['accountId']];
      case 'save':
        if (failSave) throw StateError('storage unavailable');
        snapshots[payload['accountId'] as String] = jsonDecode(
          jsonEncode(payload['snapshot']),
        );
        return null;
      case 'platformInfo':
        return {'online': true};
      case 'audioCached':
        return true;
      case 'contentHash':
        return 'a' * 64;
      case 'audioStatus':
        return audio;
      case 'audioPlay':
        audio = {
          'state': 'playing',
          'key': payload['key'],
          'durationMs': 3000,
          'positionMs': 0,
        };
        return null;
      case 'audioStop':
        audio = {'state': 'idle', 'durationMs': 0, 'positionMs': 0};
        return null;
      default:
        return null;
    }
  }
}

class FakeGateway extends UnconfiguredGateway {
  final user = newId();
  bool fail = true;
  final requests = <String>[];
  @override
  bool get configured => true;
  @override
  String? get userId => user;
  @override
  Future<Map<String, dynamic>> invoke(
    String function,
    Map<String, dynamic> body, {
    bool get = false,
  }) async {
    requests.add(body['clientRequestId'] as String);
    if (fail) throw const LearningFailure('暂时不可用');
    return {
      'targetText': 'Hello.',
      'category': 'friends',
      'model': 'gpt-4o-mini',
      'promptVersion': 'v8.0',
      'sourceLanguage': 'zh-Hant',
      'targetLanguage': 'en',
      'deconstruction': [],
      'vocabulary': [],
    };
  }

  @override
  Future<LearningSnapshot> synchronize(LearningSnapshot local) async =>
      local..lastSyncAt = DateTime.now();
}

class SwitchingGateway extends FakeGateway {
  String? current;
  final changes = StreamController<String?>.broadcast(sync: true);
  Completer<Map<String, dynamic>>? response;
  Completer<LearningSnapshot>? syncResponse;
  Completer<LearningSnapshot>? syncStarted;
  @override
  String? get userId => current;
  @override
  Stream<String?> get accountChanges => changes.stream;
  void switchTo(String? id) {
    current = id;
    changes.add(id);
  }

  @override
  Future<Map<String, dynamic>> invoke(
    String function,
    Map<String, dynamic> body, {
    bool get = false,
  }) async {
    return response!.future;
  }

  @override
  Future<LearningSnapshot> synchronize(LearningSnapshot local) async {
    syncStarted?.complete(local);
    return syncResponse?.future ?? local;
  }
}

class DelayedPlatform extends MemoryPlatform {
  final loads = <String, Completer<Object?>>{};
  Completer<Object?>? importResult;
  @override
  Future<Object?> invoke(
    String action, [
    Map<String, Object?> payload = const {},
  ]) async {
    if (action == 'load' && loads.containsKey(payload['accountId'])) {
      return loads[payload['accountId']]!.future;
    }
    if (action == 'importBackup') return importResult!.future;
    return super.invoke(action, payload);
  }
}

class CaptureGateway extends FakeGateway {
  int prepareCalls = 0;
  int batchCalls = 0;
  final batchSegmentCounts = <int>[];
  final batchSegmentIds = <List<String>>[];
  int failOnBatchCall = -1;
  Completer<Map<String, dynamic>>? prepareResponse;
  Completer<Map<String, dynamic>>? batchResponse;
  List<Map<String, dynamic>>? prepareResult;

  @override
  Future<Map<String, dynamic>> invoke(
    String function,
    Map<String, dynamic> body, {
    bool get = false,
  }) async {
    if (function == 'sentences-prepare') {
      prepareCalls++;
      final response = prepareResponse;
      if (response != null) return response.future;
      return {
        'segments':
            prepareResult ??
            List.generate(
              PreparationDraft.maxSegments,
              (i) => {
                'segmentId': newId(),
                'orderIndex': i,
                'sourceText': '这是长文整理出的第 ${i + 1} 段内容。',
              },
            ),
      };
    }
    if (function == 'sentences-batch-generate') {
      batchCalls++;
      final segments = (body['segments'] as List).cast<Map>();
      batchSegmentCounts.add(segments.length);
      batchSegmentIds.add(
        segments.map((segment) => segment['segmentId'] as String).toList(),
      );
      if (batchCalls == failOnBatchCall) {
        throw const LearningFailure('batch failed');
      }
      final response = batchResponse;
      if (response != null) return response.future;
      return {
        'items': segments
            .map(
              (segment) => {
                'segmentId': segment['segmentId'],
                'targetText': 'English for ${segment['segmentId']}',
                'category': 'daily_life',
                'deconstruction': <dynamic>[],
                'vocabulary': <dynamic>[],
              },
            )
            .toList(),
      };
    }
    return super.invoke(function, body, get: get);
  }
}

class BackupPlatform extends MemoryPlatform {
  Object? backup;
  @override
  Future<Object?> invoke(
    String action, [
    Map<String, Object?> payload = const {},
  ]) async {
    if (action == 'importBackup') return backup;
    return super.invoke(action, payload);
  }
}

class SaveGatePlatform extends MemoryPlatform {
  Completer<void>? saveGate;
  @override
  Future<Object?> invoke(
    String action, [
    Map<String, Object?> payload = const {},
  ]) async {
    if (action == 'save') {
      final gate = saveGate;
      saveGate = null;
      await gate?.future;
    }
    return super.invoke(action, payload);
  }
}

class DelayedGenerateGateway extends FakeGateway {
  Completer<Map<String, dynamic>>? response;

  @override
  Future<Map<String, dynamic>> invoke(
    String function,
    Map<String, dynamic> body, {
    bool get = false,
  }) async => response!.future;
}

class LanguageCaptureGateway extends FakeGateway {
  final bodies = <String, Map<String, dynamic>>{};
  Map<String, dynamic>? lastRecording;

  @override
  Future<Map<String, dynamic>> invoke(
    String function,
    Map<String, dynamic> body, {
    bool get = false,
  }) async {
    bodies[function] = Map<String, dynamic>.from(body);
    if (function == 'sentences-prepare') {
      return {
        'segments': [
          {'segmentId': newId(), 'orderIndex': 0, 'sourceText': '今日はいい天気です。'},
        ],
      };
    }
    return {
      'targetText': 'It is nice out today.',
      'category': 'daily_life',
      'model': currentGenerationModel,
      'promptVersion': currentGenerationPromptVersion,
      'sourceLanguage': body['sourceLanguage'],
      'targetLanguage': body['targetLanguage'],
      'deconstruction': <dynamic>[],
      'vocabulary': <dynamic>[],
    };
  }

  @override
  Future<String> transcribe(
    Map<String, dynamic> recording,
    String requestId,
  ) async {
    lastRecording = Map<String, dynamic>.from(recording);
    return '今日はいい天気です。';
  }
}

class RecordingPlatform extends MemoryPlatform {
  @override
  Future<Object?> invoke(
    String action, [
    Map<String, Object?> payload = const {},
  ]) async {
    if (action == 'recordStop') {
      return {'base64': 'YQ==', 'mimeType': 'audio/webm', 'durationMs': 1000};
    }
    return super.invoke(action, payload);
  }
}

Future<void> flushOperations() async {
  for (var i = 0; i < 12; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  List<LearnSentence> seeds({int count = 5}) => List.generate(
    count,
    (i) => LearnSentence(
      id: newId(),
      source: '你好 $i',
      target: 'Hello $i.',
      origin: 'system_seed',
      seedId: 'seed-00${i + 1}',
    ),
  );
  test('failed storage never advances onboarding or claims success', () async {
    final platform = MemoryPlatform()..failSave = true;
    final c = LearningController(
      gateway: UnconfiguredGateway(),
      platform: platform,
      seeds: seeds(),
      polling: false,
    );
    addTearDown(c.dispose);
    await c.initialize();
    await c.onboard('小豆', c.seeds.map((s) => s.id).toList());
    expect(c.state.preferences.onboarded, false);
    expect(c.state.sentences, isEmpty);
    expect(c.error, isNotNull);
  });

  test(
    'unsent today input autosaves to the current local account only',
    () async {
      final platform = MemoryPlatform();
      final c = LearningController(
        gateway: UnconfiguredGateway(),
        platform: platform,
        seeds: seeds(),
        polling: false,
      );
      addTearDown(c.dispose);
      await c.initialize();
      c.updateTodayInput('还没生成的中文表达');
      await c.flushPendingLocalWritesForTest();
      final saved = platform.snapshots['guest'] as Map<String, dynamic>;
      expect(saved['todayInput'], '还没生成的中文表达');
      expect(c.state.lastSyncAt, isNull);
      expect(c.syncPresentation.state, WebSyncState.localOnly);
    },
  );

  test('practice rating is only saved after explicit commit', () async {
    final c = LearningController(
      gateway: UnconfiguredGateway(),
      platform: MemoryPlatform(),
      seeds: seeds(),
      polling: false,
    );
    addTearDown(c.dispose);
    await c.initialize();
    await c.onboard('小豆', c.seeds.map((s) => s.id).toList());
    final sentence = c.state.sentences.first;
    c.stagePracticeRating(sentence, 'clear');
    expect(
      c.state.events.where((event) => event.type == 'practice_rated'),
      isEmpty,
    );
    expect(c.pendingPracticeSignal, 'clear');
    c.clearPendingPracticeRating();
    expect(c.pendingPracticeSignal, isNull);
    c.stagePracticeRating(sentence, 'almost');
    await c.commitPracticeRating();
    expect(
      c.state.events.where((event) => event.type == 'practice_rated'),
      hasLength(1),
    );
    expect(c.pendingPracticeSignal, isNull);
  });

  test(
    'failed input autosave is reported as a local failure, not sync success',
    () async {
      final platform = MemoryPlatform()..failSave = true;
      final c = LearningController(
        gateway: UnconfiguredGateway(),
        platform: platform,
        seeds: seeds(),
        polling: false,
      );
      addTearDown(c.dispose);
      await c.initialize();
      c.updateTodayInput('需要保留的输入');
      await c.flushPendingLocalWritesForTest();
      expect(c.syncPresentation.state, WebSyncState.localSaveFailed);
      expect(c.state.lastSyncAt, isNull);
    },
  );
  test(
    'generation failure keeps draft and reuses idempotency ID on retry',
    () async {
      final gateway = FakeGateway();
      final c = LearningController(
        gateway: gateway,
        platform: MemoryPlatform(),
        seeds: seeds(),
        polling: false,
      );
      addTearDown(c.dispose);
      await c.initialize();
      await c.generate('你好');
      expect(c.state.drafts, hasLength(1));
      gateway.fail = false;
      await c.retryDraft(c.state.drafts.single);
      expect(gateway.requests[0], gateway.requests[1]);
      expect(c.state.sentences.single.target, 'Hello.');
      expect(c.state.drafts, isEmpty);
    },
  );

  test(
    'Japanese native language routes new generation, preparation and transcription',
    () async {
      final gateway = LanguageCaptureGateway();
      final c = LearningController(
        gateway: gateway,
        platform: RecordingPlatform(),
        seeds: seeds(),
        polling: false,
      );
      addTearDown(c.dispose);
      await c.initialize();
      await c.updatePreferences(nativeLanguage: 'ja');

      await c.generate('今日はいい天気です。');
      expect(gateway.bodies['sentences-generate']?['sourceLanguage'], 'ja');
      expect(gateway.bodies['sentences-generate']?['targetLanguage'], 'en');

      await c.prepare('今日はいい天気です。明日は散歩します。');
      expect(gateway.bodies['sentences-prepare']?['sourceLanguage'], 'ja');
      expect(gateway.bodies['sentences-prepare']?['targetLanguage'], 'en');

      await c.startRecording();
      await c.stopRecording();
      expect(gateway.lastRecording?['language'], 'ja');
    },
  );

  test(
    'Simplified Chinese native language keeps the Chinese generation contract',
    () async {
      final gateway = LanguageCaptureGateway();
      final c = LearningController(
        gateway: gateway,
        platform: RecordingPlatform(),
        seeds: seeds(),
        polling: false,
      );
      addTearDown(c.dispose);
      await c.initialize();
      await c.updatePreferences(nativeLanguage: 'zh-Hans');

      await c.generate('今天想早点休息。');
      expect(c.uiLocale, 'zh-Hans');
      expect(
        gateway.bodies['sentences-generate']?['sourceLanguage'],
        'zh-Hant',
      );
      expect(gateway.bodies['sentences-generate']?['targetLanguage'], 'en');

      await c.startRecording();
      await c.stopRecording();
      expect(gateway.lastRecording?['language'], 'zh');
    },
  );

  test(
    'same source reuses the existing sentence without a new request',
    () async {
      final gateway = FakeGateway()..fail = false;
      final c = LearningController(
        gateway: gateway,
        platform: MemoryPlatform(),
        seeds: seeds(),
        polling: false,
      );
      addTearDown(c.dispose);
      await c.initialize();
      await c.generate('我今天想早点休息。');
      expect(c.state.sentences, hasLength(1));
      await c.generate('我今天想早点休息。');
      expect(c.state.sentences, hasLength(1));
      expect(gateway.requests, hasLength(1));
      expect(c.notice, contains('已经生成过'));
    },
  );

  test(
    'legacy same source only suggests opening and does not reuse automatically',
    () async {
      final gateway = FakeGateway()..fail = false;
      final c = LearningController(
        gateway: gateway,
        platform: MemoryPlatform(),
        seeds: seeds(),
        polling: false,
      );
      addTearDown(c.dispose);
      await c.initialize();
      c.state.sentences.add(
        LearnSentence(
          id: newId(),
          source: '旧版本内容',
          target: 'Legacy content.',
          origin: 'user_recording',
        ),
      );
      await c.generate('旧版本内容');
      expect(gateway.requests, hasLength(1));
      expect(c.legacySentence?.target, 'Legacy content.');
      expect(c.activeSentence?.target, 'Hello.');
    },
  );

  test('known provenance mismatch does not reuse a sentence', () async {
    final gateway = FakeGateway()..fail = false;
    final c = LearningController(
      gateway: gateway,
      platform: MemoryPlatform(),
      seeds: seeds(),
      polling: false,
    );
    addTearDown(c.dispose);
    await c.initialize();
    final old = LearnSentence(
      id: newId(),
      source: '版本变化',
      target: 'Old version.',
      origin: 'user_recording',
      generationModel: 'gpt-4o-mini',
      promptVersion: 'v7.0',
      sourceLanguage: 'zh-Hant',
      targetLanguage: 'en',
    );
    c.state.sentences.add(old);
    await c.generate('版本变化');
    expect(gateway.requests, hasLength(1));
    expect(c.state.sentences, hasLength(2));
  });

  test(
    'explicit regenerate creates a fresh request and preserves existing progress',
    () async {
      final gateway = FakeGateway()..fail = false;
      final c = LearningController(
        gateway: gateway,
        platform: MemoryPlatform(),
        seeds: seeds(),
        polling: false,
      );
      addTearDown(c.dispose);
      await c.initialize();
      await c.generate('主动重生成');
      final original = c.state.sentences.single;
      original.reviewState = 'familiar';
      original.intervalDays = 14;
      c.state.audio['${original.id}:gentle-natural:${'a' * 64}'] = {
        'status': 'ready',
      };
      await c.regenerate('主动重生成');
      expect(gateway.requests, hasLength(2));
      expect(gateway.requests.first, isNot(gateway.requests.last));
      expect(c.state.sentences, hasLength(2));
      expect(c.state.sentences.first.id, original.id);
      expect(c.state.sentences.first.reviewState, 'familiar');
      expect(c.state.sentences.first.intervalDays, 14);
    },
  );

  test(
    'a generation result does not clear input edited while the request was in flight',
    () async {
      final gateway = DelayedGenerateGateway()..response = Completer();
      final c = LearningController(
        gateway: gateway,
        platform: MemoryPlatform(),
        seeds: seeds(),
        polling: false,
      );
      addTearDown(c.dispose);
      await c.initialize();
      final generating = c.generate('先提交的内容');
      await flushOperations();
      c.updateTodayInput('等待时改成了新内容');
      await c.flushPendingLocalWritesForTest();
      gateway.response!.complete({
        'targetText': 'Earlier content.',
        'category': 'friends',
        'deconstruction': <dynamic>[],
        'vocabulary': <dynamic>[],
      });
      await generating;
      expect(c.todayInput, '等待时改成了新内容');
      expect(c.state.sentences, hasLength(1));
    },
  );

  test(
    'a generation result does not clear input reverted after an in-flight edit',
    () async {
      final gateway = DelayedGenerateGateway()..response = Completer();
      final c = LearningController(
        gateway: gateway,
        platform: MemoryPlatform(),
        seeds: seeds(),
        polling: false,
      );
      addTearDown(c.dispose);
      await c.initialize();
      c.updateTodayInput('先提交的内容');
      await c.flushPendingLocalWritesForTest();
      final generating = c.generate('先提交的内容');
      await flushOperations();
      c.updateTodayInput('等待时改成了新内容');
      c.updateTodayInput('先提交的内容');
      gateway.response!.complete({
        'targetText': 'Earlier content.',
        'category': 'friends',
        'deconstruction': <dynamic>[],
        'vocabulary': <dynamic>[],
      });
      await generating;
      expect(c.todayInput, '先提交的内容');
      expect(c.state.sentences, hasLength(1));
    },
  );

  test(
    'preparation keeps 20 segments and generates in four batches of five',
    () async {
      final gateway = CaptureGateway();
      final c = LearningController(
        gateway: gateway,
        platform: MemoryPlatform(),
        seeds: seeds(),
        polling: false,
      );
      addTearDown(c.dispose);
      await c.initialize();
      final prepared = await c.prepare('x' * 600);
      expect(prepared, hasLength(20));
      expect(c.preparationDraft?.segments, hasLength(20));
      expect(gateway.prepareCalls, 1);
      await c.generatePreparedSegments();
      expect(gateway.batchSegmentCounts, [5, 5, 5, 5]);
      expect(c.state.sentences, hasLength(20));
      expect(c.preparationDraft, isNull);
    },
  );

  test(
    'a failed mid-way batch keeps completed work and retries only pending segments',
    () async {
      final gateway = CaptureGateway()..failOnBatchCall = 2;
      final c = LearningController(
        gateway: gateway,
        platform: MemoryPlatform(),
        seeds: seeds(),
        polling: false,
      );
      addTearDown(c.dispose);
      await c.initialize();
      await c.prepare('x' * 600);
      await c.generatePreparedSegments();
      expect(c.error, isNotNull);
      expect(c.state.sentences, hasLength(5));
      expect(c.preparationDraft?.pendingSegments, hasLength(15));
      gateway.failOnBatchCall = -1;
      c.clearMessage();
      await c.generatePreparedSegments();
      expect(c.state.sentences, hasLength(20));
      expect(gateway.batchSegmentCounts, [5, 5, 5, 5, 5]);
      expect(c.preparationDraft, isNull);
      expect(gateway.batchSegmentIds[1], gateway.batchSegmentIds[2]);
    },
  );

  test(
    'a stale preparation response keeps the newer input and does not install old segments',
    () async {
      final gateway = CaptureGateway()..prepareResponse = Completer();
      final c = LearningController(
        gateway: gateway,
        platform: MemoryPlatform(),
        seeds: seeds(),
        polling: false,
      );
      addTearDown(c.dispose);
      await c.initialize();
      c.updateTodayInput('原始长文 A');
      final preparing = c.prepare('原始长文 A');
      await flushOperations();
      c.updateTodayInput('后来改成的长文 B');
      gateway.prepareResponse!.complete({
        'segments': [
          {'segmentId': newId(), 'orderIndex': 0, 'sourceText': 'A 的旧分句'},
        ],
      });
      final prepared = await preparing;
      expect(prepared, isEmpty);
      expect(c.todayInput, '后来改成的长文 B');
      expect(c.preparationDraft?.segments, isEmpty);
    },
  );

  test(
    'repeating preparation for the same input retains completed segment status',
    () async {
      final gateway = CaptureGateway()
        ..prepareResult = [
          {'segmentId': newId(), 'orderIndex': 0, 'sourceText': '第一段'},
          {'segmentId': newId(), 'orderIndex': 1, 'sourceText': '第二段'},
        ];
      final c = LearningController(
        gateway: gateway,
        platform: MemoryPlatform(),
        seeds: seeds(),
        polling: false,
      );
      addTearDown(c.dispose);
      await c.initialize();
      await c.prepare('同一篇长文');
      final preparation = c.state.preparationDraft!;
      final completedId = preparation.segments.first.id;
      preparation.segments.first.status = 'succeeded';
      await c.prepare('同一篇长文');
      expect(c.preparationDraft!.segments.first.id, completedId);
      expect(c.preparationDraft!.segments.first.status, 'succeeded');
      expect(c.preparationDraft!.segments.last.status, 'pending');
    },
  );

  test(
    'editing input while a batch save waits preserves the saved batch result',
    () async {
      final gateway = CaptureGateway()
        ..prepareResult = [
          {'segmentId': newId(), 'orderIndex': 0, 'sourceText': '唯一分句'},
        ];
      final platform = SaveGatePlatform();
      final c = LearningController(
        gateway: gateway,
        platform: platform,
        seeds: seeds(),
        polling: false,
      );
      addTearDown(c.dispose);
      await c.initialize();
      await c.prepare('等待保存的长文');
      final gate = Completer<void>();
      platform.saveGate = gate;
      final generating = c.generatePreparedSegments();
      await flushOperations();
      c.updateTodayInput('保存期间的新输入');
      gate.complete();
      await generating;
      expect(gateway.batchCalls, 1);
      expect(c.state.sentences, hasLength(1));
      expect(c.preparationDraft, isNull);
      expect(c.todayInput, '保存期间的新输入');
    },
  );

  test(
    'a batch result does not clear input reverted after an in-flight edit',
    () async {
      final gateway = CaptureGateway()
        ..prepareResult = [
          {'segmentId': newId(), 'orderIndex': 0, 'sourceText': '批量原文'},
        ]
        ..batchResponse = Completer();
      final c = LearningController(
        gateway: gateway,
        platform: MemoryPlatform(),
        seeds: seeds(),
        polling: false,
      );
      addTearDown(c.dispose);
      await c.initialize();
      c.updateTodayInput('批量原文');
      await c.flushPendingLocalWritesForTest();
      await c.prepare('批量原文');
      final generating = c.generatePreparedSegments();
      await flushOperations();
      c.updateTodayInput('中途改过的输入');
      c.updateTodayInput('批量原文');
      final segmentId = c.preparationDraft!.segments.single.id;
      gateway.batchResponse!.complete({
        'items': [
          {
            'segmentId': segmentId,
            'targetText': 'Batch result.',
            'category': 'daily_life',
            'deconstruction': <dynamic>[],
            'vocabulary': <dynamic>[],
          },
        ],
      });
      await generating;
      expect(c.todayInput, '批量原文');
    },
  );

  test(
    'editing a segment while batch generation is in flight is rejected explicitly',
    () async {
      final gateway = CaptureGateway()
        ..prepareResult = [
          {'segmentId': newId(), 'orderIndex': 0, 'sourceText': '生成中的分句'},
        ]
        ..batchResponse = Completer();
      final c = LearningController(
        gateway: gateway,
        platform: MemoryPlatform(),
        seeds: seeds(),
        polling: false,
      );
      addTearDown(c.dispose);
      await c.initialize();
      await c.prepare('生成中的长文');
      final original = c.preparationDraft!.segments.single;
      final generating = c.generatePreparedSegments();
      await flushOperations();
      c.updatePreparationSegment(0, '不应覆盖的修改');
      expect(c.preparationDraft!.segments.single.id, original.id);
      expect(
        c.preparationDraft!.segments.single.sourceText,
        original.sourceText,
      );
      expect(c.notice, contains('生成中'));
      gateway.batchResponse!.complete({
        'items': [
          {
            'segmentId': original.id,
            'targetText': 'Generated.',
            'category': 'daily_life',
            'deconstruction': <dynamic>[],
            'vocabulary': <dynamic>[],
          },
        ],
      });
      await generating;
      expect(c.state.sentences.single.source, original.sourceText);
    },
  );

  test(
    'backup import restores a preparation draft and keeps a newer local draft',
    () async {
      final platform = BackupPlatform();
      final c = LearningController(
        gateway: UnconfiguredGateway(),
        platform: platform,
        seeds: seeds(),
        polling: false,
      );
      addTearDown(c.dispose);
      await c.initialize();
      final local = PreparationDraft(
        id: newId(),
        sourceText: '本机草稿',
        segments: [PreparationSegment(id: newId(), sourceText: '本机分句')],
        updatedAt: DateTime(2026, 9, 8, 12),
      );
      c.state.preparationDraft = local;
      final imported = LearningSnapshot.empty()
        ..todayInput = '备份输入'
        ..segmentInputs.add('备份分段')
        ..preparationDraft = PreparationDraft(
          id: newId(),
          sourceText: '更旧的备份草稿',
          segments: [PreparationSegment(id: newId(), sourceText: '备份分句')],
          updatedAt: DateTime(2026, 9, 8, 11),
        );
      platform.backup = jsonEncode(imported.toBackup());
      await c.importBackup();
      expect(c.preparationDraft!.sourceText, '本机草稿');
      expect(c.todayInput, '备份输入');
      expect(c.state.segmentInputs, ['备份分段']);

      final newer = LearningSnapshot.empty()
        ..preparationDraft = PreparationDraft(
          id: newId(),
          sourceText: '更新后的备份草稿',
          segments: [PreparationSegment(id: newId(), sourceText: '更新后的分句')],
          updatedAt: DateTime(2026, 9, 8, 13),
        );
      platform.backup = jsonEncode(newer.toBackup());
      await c.importBackup();
      expect(c.preparationDraft!.sourceText, '更新后的备份草稿');
    },
  );

  test(
    'segment input updates reject more than twenty values without slicing',
    () async {
      final c = LearningController(
        gateway: UnconfiguredGateway(),
        platform: MemoryPlatform(),
        seeds: seeds(),
        polling: false,
      );
      addTearDown(c.dispose);
      await c.initialize();
      c.updateSegmentInputs(['保留的值']);
      expect(
        () => c.updateSegmentInputs(List.filled(21, '超出上限')),
        throwsA(isA<LearningFailure>()),
      );
      expect(c.state.segmentInputs, ['保留的值']);
    },
  );

  test('editing a prepared segment gives it a new pending identity', () async {
    final gateway = CaptureGateway();
    final c = LearningController(
      gateway: gateway,
      platform: MemoryPlatform(),
      seeds: seeds(),
      polling: false,
    );
    addTearDown(c.dispose);
    await c.initialize();
    await c.prepare('x' * 600);
    final originalId = c.preparationDraft!.segments.first.id;
    c.updatePreparationSegment(0, '我手动改过的第一段。');
    expect(c.preparationDraft!.segments.first.sourceText, '我手动改过的第一段。');
    expect(c.preparationDraft!.segments.first.id, isNot(originalId));
    expect(c.preparationDraft!.segments.first.status, 'pending');
    await c.flushPendingLocalWritesForTest();
    expect(c.state.preparationDraft?.segments.first.sourceText, '我手动改过的第一段。');
  });
  test(
    'only real ended event records listening and does not duplicate on polling',
    () async {
      final platform = MemoryPlatform();
      final c = LearningController(
        gateway: UnconfiguredGateway(),
        platform: platform,
        seeds: seeds(),
        polling: false,
      );
      addTearDown(c.dispose);
      await c.initialize();
      await c.onboard('小豆', c.seeds.map((s) => s.id).toList());
      await c.play(c.state.sentences.first);
      await c.poll();
      expect(
        c.state.events.where((e) => e.type == 'listen_completed'),
        isEmpty,
      );
      platform.audio['state'] = 'paused';
      await c.poll();
      expect(
        c.state.events.where((e) => e.type == 'listen_completed'),
        isEmpty,
      );
      platform.audio['state'] = 'ended';
      platform.failSave = true;
      await c.poll();
      expect(
        c.state.events.where((e) => e.type == 'listen_completed'),
        isEmpty,
      );
      platform.failSave = false;
      await c.poll();
      await c.poll();
      expect(
        c.state.events.where((e) => e.type == 'listen_completed'),
        hasLength(1),
      );
      expect(c.state.sentences.first.reviewState, 'learning');
    },
  );
  test('onboard generates user-owned ids and is seed-idempotent', () async {
    final c = LearningController(
      gateway: UnconfiguredGateway(),
      platform: MemoryPlatform(),
      seeds: seeds(),
      polling: false,
    );
    addTearDown(c.dispose);
    await c.initialize();
    final ids = c.seeds.map((s) => s.id).toList();
    await c.onboard('小豆', ids);
    await c.onboard('小豆', ids);
    expect(c.state.sentences, hasLength(5));
    expect(c.state.sentences.first.id, isNot(c.seeds.first.id));
  });

  test('onboard rejects fewer than three unique seeds', () async {
    final c = LearningController(
      gateway: UnconfiguredGateway(),
      platform: MemoryPlatform(),
      seeds: seeds(),
      polling: false,
    );
    addTearDown(c.dispose);
    await c.initialize();

    await c.onboard('小豆', c.seeds.take(2).map((s) => s.id).toList());

    expect(c.state.preferences.onboarded, false);
    expect(c.state.sentences, isEmpty);
    expect(c.error, '请选择至少三句想学的表达。');
  });

  test('onboard accepts three or more seeds without an upper limit', () async {
    final c = LearningController(
      gateway: UnconfiguredGateway(),
      platform: MemoryPlatform(),
      seeds: seeds(count: 6),
      polling: false,
    );
    addTearDown(c.dispose);
    await c.initialize();

    await c.onboard('小豆', c.seeds.take(3).map((s) => s.id).toList());

    expect(c.state.preferences.onboarded, true);
    expect(c.state.sentences, hasLength(3));
  });
  test(
    'adding a seed saves a user-owned learning record and is idempotent',
    () async {
      final c = LearningController(
        gateway: UnconfiguredGateway(),
        platform: MemoryPlatform(),
        seeds: seeds(),
        polling: false,
      );
      addTearDown(c.dispose);
      await c.initialize();
      await c.addSeed(c.seeds.first);
      await c.addSeed(c.seeds.first);
      expect(c.state.sentences, hasLength(1));
      expect(c.activeSentence!.id, c.state.sentences.single.id);
      expect(c.activeSentence!.id, isNot(c.seeds.first.id));
      expect(c.tab, 1);
    },
  );
  test('slow account load cannot overwrite a newer account', () async {
    final gateway = SwitchingGateway();
    final platform = DelayedPlatform();
    final c = LearningController(
      gateway: gateway,
      platform: platform,
      seeds: seeds(),
      polling: false,
    );
    addTearDown(c.dispose);
    addTearDown(gateway.changes.close);
    await c.initialize();
    final first = newId(), second = newId();
    platform.loads[first] = Completer<Object?>();
    final secondState = LearningSnapshot.empty()..accountScope = second;
    secondState.preferences.name = '第二个账户';
    platform.snapshots[second] = secondState.toBackup();
    gateway.switchTo(first);
    await flushOperations();
    gateway.switchTo(second);
    await flushOperations();
    expect(c.accountId, second);
    expect(c.state.preferences.name, '第二个账户');
    final oldState = LearningSnapshot.empty()..accountScope = first;
    oldState.preferences.name = '过期账户';
    platform.loads[first]!.complete(oldState.toBackup());
    await flushOperations();
    expect(c.accountId, second);
    expect(c.state.accountScope, second);
    expect(c.state.preferences.name, '第二个账户');
  });
  test(
    'backup selected before account change is never imported into the new account',
    () async {
      final gateway = SwitchingGateway();
      final platform = DelayedPlatform()..importResult = Completer<Object?>();
      final c = LearningController(
        gateway: gateway,
        platform: platform,
        seeds: seeds(),
        polling: false,
      );
      addTearDown(c.dispose);
      addTearDown(gateway.changes.close);
      await c.initialize();
      final backup = LearningSnapshot.empty()..sentences.add(seeds().first);
      final importing = c.importBackup();
      final account = newId();
      gateway.switchTo(account);
      await flushOperations();
      platform.importResult!.complete(jsonEncode(backup.toBackup()));
      await importing;
      expect(c.state.sentences, isEmpty);
      expect(platform.snapshots[account], isNull);
    },
  );
  test(
    'generation result from before leaving and returning to an account is ignored',
    () async {
      final account = newId();
      final gateway = SwitchingGateway()
        ..current = account
        ..response = Completer<Map<String, dynamic>>();
      final c = LearningController(
        gateway: gateway,
        platform: MemoryPlatform(),
        seeds: seeds(),
        polling: false,
      );
      addTearDown(c.dispose);
      addTearDown(gateway.changes.close);
      await c.initialize();
      final generating = c.generate('旧请求');
      await flushOperations();
      gateway.switchTo(null);
      await flushOperations();
      gateway.switchTo(account);
      await flushOperations();
      gateway.response!.complete({
        'targetText': 'Old result.',
        'category': 'friends',
        'deconstruction': [],
        'vocabulary': [],
      });
      await generating;
      expect(c.state.sentences, isEmpty);
      expect(c.state.drafts, hasLength(1));
    },
  );
  test(
    'sync accepts server acknowledgement time while preserving edits made in flight',
    () async {
      final gateway = SwitchingGateway()
        ..current = newId()
        ..syncStarted = Completer<LearningSnapshot>()
        ..syncResponse = Completer<LearningSnapshot>();
      final c = LearningController(
        gateway: gateway,
        platform: MemoryPlatform(),
        seeds: seeds(),
        polling: false,
      );
      addTearDown(c.dispose);
      addTearDown(gateway.changes.close);
      await c.initialize();
      await c.onboard('小豆', c.seeds.map((s) => s.id).toList());
      c.state.sentences.first.updatedAt = DateTime(2099);
      final syncing = c.sync();
      final submitted = await gateway.syncStarted!.future;
      await c.updatePreferences(name: '同步期间的新名字');
      final serverTime = DateTime(2026, 9, 5);
      submitted.sentences.first.updatedAt = serverTime;
      submitted.lastSyncAt = serverTime;
      gateway.syncResponse!.complete(submitted);
      await syncing;
      expect(c.state.sentences.first.updatedAt, serverTime);
      expect(c.state.preferences.name, '同步期间的新名字');
      expect(c.state.lastSyncAt, serverTime);
    },
  );
}
