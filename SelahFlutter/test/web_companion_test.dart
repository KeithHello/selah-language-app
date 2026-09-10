import 'package:flutter_test/flutter_test.dart';
import 'package:selah/domain/selah_enums.dart';
import 'package:selah/web/data/learning_gateway.dart';
import 'package:selah/web/domain/learning_models.dart';
import 'package:selah/web/learning_controller.dart';
import 'web_controller_test.dart' show MemoryPlatform, FakeGateway;

class _RecordingGateway extends FakeGateway {
  bool failTranscribe = false;
  @override
  Future<String> transcribe(
    Map<String, dynamic> audio,
    String requestId,
  ) async {
    if (failTranscribe) throw const LearningFailure('转写失败');
    return '今天想早点休息。';
  }
}

class _RecordingPlatform extends MemoryPlatform {
  bool denyMicrophone = false;
  @override
  Future<Object?> invoke(
    String action, [
    Map<String, Object?> payload = const {},
  ]) {
    if (action == 'recordStart' && denyMicrophone) {
      throw const LearningFailure('麦克风未允许');
    }
    if (action == 'recordStop') return Future.value({'base64': 'test'});
    return super.invoke(action, payload);
  }
}

void main() {
  late _RecordingPlatform platform;
  late _RecordingGateway gateway;
  late LearningController controller;
  late LearnSentence sentence;
  setUp(() async {
    platform = _RecordingPlatform();
    gateway = _RecordingGateway();
    controller = LearningController(
      gateway: gateway,
      platform: platform,
      seeds: const [],
      polling: false,
    );
    await controller.initialize();
    sentence = LearnSentence(
      id: newId(),
      source: '你好',
      target: 'Hello.',
      origin: 'system_seed',
    );
    controller.state.sentences.add(sentence);
  });
  tearDown(() => controller.dispose());

  testWidgets('only a persisted natural audio end gives one completion cue', (
    tester,
  ) async {
    await tester.runAsync(() => controller.play(sentence));
    expect(controller.companionAction, SpriteActionId.listenPlaying);
    final revision = controller.companionRevision;
    platform.audio['state'] = 'paused';
    await tester.runAsync(controller.poll);
    expect(controller.companionAction, SpriteActionId.gentleFloat);
    expect(controller.companionRevision, revision);
    platform.audio['state'] = 'ended';
    await tester.runAsync(controller.poll);
    expect(controller.companionAction, SpriteActionId.listenComplete);
    final completedRevision = controller.companionRevision;
    await tester.runAsync(controller.poll);
    expect(controller.companionRevision, completedRevision);
    expect(
      controller.state.events.where(
        (event) => event.type == 'listen_completed',
      ),
      hasLength(1),
    );
  });

  test('storage failure and playback error do not celebrate', () async {
    await controller.play(sentence);
    platform.failSave = true;
    platform.audio['state'] = 'ended';
    await controller.poll();
    expect(controller.companionAction, SpriteActionId.gentleFloat);
    expect(controller.state.events, isEmpty);
    platform.audio['state'] = 'error';
    await controller.poll();
    expect(controller.companionAction, SpriteActionId.gentleFloat);
  });

  test('a successful rating selects a calm cue, failures do not', () async {
    await controller.rate(sentence, 'clear');
    expect(controller.companionAction, SpriteActionId.quizGood);
    await controller.rate(sentence, 'failed');
    expect(controller.companionAction, SpriteActionId.quizFail);
    final revision = controller.companionRevision;
    platform.failSave = true;
    await controller.rate(sentence, 'clear');
    expect(controller.companionRevision, revision);
  });

  test(
    'recording preempts playback, cancellation clears it without success',
    () async {
      await controller.play(sentence);
      await controller.startRecording();
      expect(controller.companionAction, SpriteActionId.recRecording);
      expect(controller.playback['state'], 'idle');
      await controller.cancelRecording();
      expect(controller.companionAction, SpriteActionId.gentleFloat);
      expect(controller.state.events, isEmpty);
    },
  );

  test('recording completion requires transcription success', () async {
    await controller.startRecording();
    gateway.failTranscribe = true;
    await controller.stopRecording();
    expect(controller.companionAction, SpriteActionId.gentleFloat);
    gateway.failTranscribe = false;
    expect(await controller.stopRecording(), '今天想早点休息。');
    expect(controller.companionAction, SpriteActionId.recDone);
    await controller.startRecording();
    await controller.cancelRecording();
    expect(controller.companionAction, SpriteActionId.gentleFloat);
  });

  test('microphone denial never shows recording or completion', () async {
    platform.denyMicrophone = true;
    await controller.startRecording();
    expect(controller.companionAction, SpriteActionId.gentleFloat);
    expect(controller.error, isNotNull);
  });

  testWidgets('cue expires once without replaying persisted history', (
    tester,
  ) async {
    // Use a synchronous change listener to inspect expiry after real asynchronous writes.
    await tester.runAsync(() => controller.rate(sentence, 'clear'));
    expect(controller.companionAction, SpriteActionId.quizGood);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1500)),
    );
    expect(controller.companionAction, SpriteActionId.gentleFloat);
    controller.notifyListeners();
    expect(controller.companionAction, SpriteActionId.gentleFloat);
  });
}
