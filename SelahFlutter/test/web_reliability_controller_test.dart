import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/web/data/learning_gateway.dart';
import 'package:selah/web/domain/learning_models.dart';
import 'package:selah/web/domain/web_status.dart';
import 'package:selah/web/learning_controller.dart';
import 'web_controller_test.dart'
    show MemoryPlatform, SwitchingGateway, flushOperations;

class ControlledPlatform extends MemoryPlatform {
  Completer<void>? saveGate;
  Completer<void>? audioGate;
  Object? backup;
  final calls = <String>[];
  bool protected = false;
  bool cached = true;
  @override
  Future<Object?> invoke(
    String action, [
    Map<String, Object?> payload = const {},
  ]) async {
    calls.add(action);
    if (action == 'save') {
      final gate = saveGate;
      saveGate = null;
      await gate?.future;
    }
    if (action == 'audioEnsure') await audioGate?.future;
    if (action == 'audioCached') return cached;
    if (action == 'setUnloadProtection') protected = payload['enabled'] == true;
    if (action == 'importBackup') return backup;
    if (action == 'recordStop') {
      return {'base64': 'YQ==', 'mimeType': 'audio/webm'};
    }
    return super.invoke(action, payload);
  }
}

class LoginGateway extends SwitchingGateway {
  bool confirmation = false;
  @override
  Future<void> signIn(String email, String password) async {
    if (confirmation) {
      throw const LearningFailure('请确认邮箱。', code: 'email_confirmation');
    }
    switchTo(newId());
  }
}

void main() {
  late ControlledPlatform p;
  late SwitchingGateway g;
  late LearningController c;
  setUp(() async {
    p = ControlledPlatform();
    g = SwitchingGateway();
    final seed = LearnSentence(
      id: newId(),
      seedId: 'seed-001',
      source: '你好',
      target: 'Hello.',
      origin: 'system_seed',
    );
    c = LearningController(
      gateway: g,
      platform: p,
      seeds: [seed],
      polling: false,
      bundledAudio: {
        'seed-001:gentle-natural': {
          'path': 'assets/audio/sample.mp3',
          'sha256': 'a' * 64,
        },
      },
    );
    await c.initialize();
  });
  tearDown(() async {
    c.dispose();
    await g.changes.close();
  });

  test('slow snapshot save cannot overwrite newer input', () async {
    final gate = Completer<void>();
    p.saveGate = gate;
    final saving = c.updatePreferences(name: '豆豆');
    await flushOperations();
    c.updateTodayInput('刚输入的新草稿');
    gate.complete();
    await saving;
    expect(c.todayInput, '刚输入的新草稿');
    await c.flushPendingLocalWritesForTest();
    expect((p.snapshots['guest'] as Map)['todayInput'], '刚输入的新草稿');
  });

  test(
    'switching accounts before debounce saves the departing draft',
    () async {
      c.updateTodayInput('访客未满三百毫秒的草稿');
      g.switchTo(newId());
      await flushOperations();
      expect((p.snapshots['guest'] as Map?)?['todayInput'], '访客未满三百毫秒的草稿');
      expect(c.todayInput, isEmpty);
    },
  );

  test(
    'segment edits preserve whitespace and empty positions through reload',
    () async {
      c.updateSegmentInputs([' 第一段 ', '', '  ']);
      await c.flushPendingLocalWritesForTest();
      final stored = LearningSnapshot.importBackup(
        jsonEncode(p.snapshots['guest']),
      );
      expect(stored.segmentInputs, [' 第一段 ', '', '  ']);
      await c.clearSegmentInputs();
      expect(c.state.segmentInputs, isEmpty);
    },
  );

  test(
    'saving a newer practice choice does not clear it with an older completion',
    () async {
      await c.addSeed(c.seeds.first);
      final sentence = c.state.sentences.single;
      c.stagePracticeRating(sentence, 'clear');
      p.saveGate = Completer<void>();
      final gate = p.saveGate!;
      final saving = c.commitPracticeRating();
      await flushOperations();
      c.stagePracticeRating(sentence, 'almost');
      gate.complete();
      await saving;
      expect(c.pendingPracticeSignal, 'almost');
    },
  );

  test(
    'practice save failure preserves choice and does not commit an event',
    () async {
      await c.addSeed(c.seeds.first);
      c.stagePracticeRating(c.state.sentences.single, 'clear');
      p.failSave = true;
      await c.commitPracticeRating();
      expect(c.pendingPracticeSignal, 'clear');
      expect(c.state.events.where((e) => e.type == 'practice_rated'), isEmpty);
      p.failSave = false;
      await c.commitPracticeRating();
      expect(c.pendingPracticeSignal, isNull);
    },
  );

  test(
    'draft protection covers debounce and failure, then clears after retry',
    () async {
      c.updateTodayInput('  草稿  ');
      expect(c.hasUnsavedChanges, isTrue);
      expect(p.protected, isTrue);
      p.failSave = true;
      await c.flushLocalWrites();
      expect(c.localSaveFailed, isTrue);
      expect(c.hasUnsavedChanges, isTrue);
      p.failSave = false;
      await c.retryLocalSave();
      expect(c.localSaveFailed, isFalse);
      expect(c.hasUnsavedChanges, isFalse);
      expect(p.protected, isFalse);
    },
  );

  test(
    'input written while sync is pending does not become a cloud change',
    () async {
      g.switchTo(newId());
      await flushOperations();
      g.syncStarted = Completer<LearningSnapshot>();
      g.syncResponse = Completer<LearningSnapshot>();
      final syncing = c.sync();
      final submitted = await g.syncStarted!.future;
      c.updateTodayInput('同步时继续输入');
      await c.flushLocalWrites();
      g.syncResponse!.complete(submitted..lastSyncAt = DateTime.now());
      await syncing;
      expect(c.todayInput, '同步时继续输入');
      expect(c.syncPresentation.state, WebSyncState.synced);
    },
  );

  test('detail navigation is distinct from playing selection', () async {
    await c.addSeed(c.seeds.first);
    final first = c.state.sentences.single;
    final second = LearnSentence(id: newId(), source: '再见', target: 'Bye.');
    c.state.sentences.add(second);
    await c.play(first);
    c.openDetail(3, second);
    expect(c.detailSentenceId, second.id);
    expect(c.playingSentence!.id, first.id);
    c.navigate(3);
    expect(c.detailTab, 3);
    c.navigate(1);
    expect(c.detailTab, isNull);
    expect(c.activeSentence!.id, second.id);
    expect(() => c.openDetail(0, first), throwsArgumentError);
    expect(
      () => c.openDetail(1, c.seeds.first),
      throwsA(isA<LearningFailure>()),
    );
  });

  test(
    'seed preview uses bundled audio without recording learning or preferences',
    () async {
      final before = jsonEncode(c.state.toBackup());
      await c.previewSeed(c.seeds.first);
      expect(p.calls, contains('audioPlay'));
      p.audio['state'] = 'ended';
      await c.poll();
      expect(c.playingSentence, isNull);
      expect(jsonEncode(c.state.toBackup()), before);
      expect(c.state.events, isEmpty);
    },
  );

  test(
    'preview rejects unavailable voice without using an online fallback',
    () async {
      await c.previewSeed(c.seeds.first, voice: 'clear-slow');
      expect(c.error, isNotNull);
      expect(p.calls, isNot(contains('audioPlay')));
    },
  );

  test('stop cancels a preview still preparing audio', () async {
    p.cached = false;
    p.audioGate = Completer<void>();
    final preview = c.previewSeed(c.seeds.first);
    await flushOperations();
    await c.stopPlayback();
    p.audioGate!.complete();
    await preview;
    expect(p.calls, isNot(contains('audioPlay')));
    expect(c.playback['state'], 'idle');
  });

  test(
    'guest input is appended only for a session and never deleted',
    () async {
      c.updateTodayInput('访客输入');
      await c.flushLocalWrites();
      expect(await c.loadGuestData(), isNull);
      g.switchTo(newId());
      await flushOperations();
      c.updateTodayInput('账户输入');
      expect((await c.loadGuestData())!.todayInput, '访客输入');
      await c.bringGuestInput();
      expect(c.todayInput, '账户输入\n访客输入');
      expect((p.snapshots['guest'] as Map)['todayInput'], '访客输入');
    },
  );

  test('backup preflight is read only and confirmation merges once', () async {
    final incoming = LearningSnapshot.empty()..sentences.add(c.seeds.first);
    p.backup = jsonEncode(incoming.toBackup());
    final picked = (await c.pickBackup())!;
    expect(c.state.sentences, isEmpty);
    expect(p.snapshots, isEmpty);
    await c.mergeBackup(picked);
    expect(c.state.sentences, hasLength(1));
  });

  test(
    'backup confirmation from an older account generation is rejected',
    () async {
      p.backup = jsonEncode(
        (LearningSnapshot.empty()..sentences.add(c.seeds.first)).toBackup(),
      );
      final picked = (await c.pickBackup())!;
      g.switchTo(newId());
      await flushOperations();
      await c.mergeBackup(picked);
      expect(c.state.sentences, isEmpty);
      expect(c.error, isNotNull);
    },
  );

  test('vocabulary undo requires the state it originally changed', () async {
    await c.addSeed(c.seeds.first);
    final sentence = c.state.sentences.single;
    final entry = VocabularyEntry(id: newId(), text: 'hello', meaning: '你好');
    sentence.vocabulary.add(entry);
    expect(
      await c.setVocabularyState(
        sentence,
        entry,
        'learning',
        expectedState: 'new',
      ),
      isTrue,
    );
    expect(await c.setVocabularyState(sentence, entry, 'owned'), isTrue);
    expect(
      await c.setVocabularyState(
        sentence,
        entry,
        'new',
        expectedState: 'learning',
      ),
      isFalse,
    );
    expect(c.state.sentences.single.vocabulary.single.state, 'owned');
    expect(c.localSaveFailed, isFalse);
  });

  test(
    'pending transcription blocks replacing the original recording',
    () async {
      g.switchTo(newId());
      await flushOperations();
      await c.startRecording();
      await c.stopRecording();
      expect(c.hasPendingRecording, isTrue);
      final started = p.calls.where((a) => a == 'recordStart').length;
      await c.startRecording();
      expect(c.hasPendingRecording, isTrue);
      expect(p.calls.where((a) => a == 'recordStart').length, started);
      expect(c.hasUnsavedChanges, isTrue);
    },
  );

  test('update flushes input before invoking the browser update', () async {
    c.updateTodayInput('更新前的最后一笔');
    await c.applyUpdate();
    expect((p.snapshots['guest'] as Map?)?['todayInput'], '更新前的最后一笔');
    expect(p.calls.indexOf('save'), lessThan(p.calls.indexOf('applyUpdate')));
  });

  test('update refuses unsaved input and practice choice', () async {
    c.updateTodayInput('不能丢');
    p.failSave = true;
    await c.applyUpdate();
    expect(p.calls, isNot(contains('applyUpdate')));
    p.failSave = false;
    await c.retryLocalSave();
    await c.addSeed(c.seeds.first);
    c.stagePracticeRating(c.state.sentences.single, 'almost');
    await c.applyUpdate();
    expect(p.calls, isNot(contains('applyUpdate')));
    expect(c.pendingPracticeSignal, 'almost');
  });

  test('old practice save cannot clear the next account choice', () async {
    await c.addSeed(c.seeds.first);
    final old = c.state.sentences.single;
    c.stagePracticeRating(old, 'clear');
    final gate = Completer<void>();
    p.saveGate = gate;
    final saving = c.commitPracticeRating();
    await flushOperations();
    g.switchTo(newId());
    gate.complete();
    await saving;
    await flushOperations();
    await c.addSeed(c.seeds.first);
    c.stagePracticeRating(c.state.sentences.single, 'almost');
    expect(c.state.events, isEmpty);
    expect(c.pendingPracticeSignal, 'almost');
  });

  test(
    'failed departing draft stays protected and retries to its own account',
    () async {
      c.updateTodayInput('退出时存储失败的草稿');
      p.failSave = true;
      g.switchTo(newId());
      await flushOperations();
      expect(c.hasUnsavedChanges, isTrue);
      expect(c.localSaveFailed, isTrue);
      expect(c.todayInput, isEmpty);
      p.failSave = false;
      await c.retryLocalSave();
      expect((p.snapshots['guest'] as Map)['todayInput'], '退出时存储失败的草稿');
      expect(c.todayInput, isEmpty);
      expect(c.hasUnsavedChanges, isFalse);
    },
  );

  test(
    'stop cancels formal audio preparation before it can start playing',
    () async {
      await c.addSeed(c.seeds.first);
      p.cached = false;
      p.audioGate = Completer<void>();
      final playing = c.play(c.state.sentences.single);
      await flushOperations();
      await c.stopPlayback();
      p.audioGate!.complete();
      await playing;
      expect(p.calls, isNot(contains('audioPlay')));
      expect(c.playback['state'], 'idle');
    },
  );

  test(
    'login waits for the cloud snapshot before exposing onboarding',
    () async {
      c.dispose();
      await g.changes.close();
      final gateway = LoginGateway()
        ..syncStarted = Completer<LearningSnapshot>()
        ..syncResponse = Completer<LearningSnapshot>();
      g = gateway;
      c = LearningController(
        gateway: g,
        platform: p,
        seeds: [],
        polling: false,
      );
      await c.initialize();
      var finished = false;
      final login = c.login('user@example.com', '123456').then((_) {
        finished = true;
      });
      await flushOperations();
      expect(finished, isFalse);
      expect(g.syncStarted!.isCompleted, isTrue);
      final server = LearningSnapshot.empty()..accountScope = g.userId!;
      server.preferences.onboarded = true;
      server.preferences.updatedAt = DateTime.now().add(
        const Duration(days: 1),
      );
      server.lastSyncAt = DateTime.now();
      g.syncResponse!.complete(server);
      await login;
      expect(c.state.preferences.onboarded, isTrue);
    },
  );

  test('unconfirmed email is a waiting notice, not a login error', () async {
    c.dispose();
    await g.changes.close();
    g = LoginGateway()..confirmation = true;
    c = LearningController(gateway: g, platform: p, seeds: [], polling: false);
    await c.initialize();
    await c.login('user@example.com', '123456');
    expect(c.error, isNull);
    expect(c.notice, contains('确认'));
  });
}
