import 'package:flutter_test/flutter_test.dart';
import 'package:selah/web/domain/audio_preparation.dart';

void main() {
  test(
    'audio track keys stay stable for the same voice, role, language and text hash',
    () {
      expect(
        audioTrackKey(
          voice: 'gentle-natural',
          role: AudioTrackRole.target,
          language: 'en',
          contentHash: 'a' * 64,
        ),
        'loop:gentle-natural:target:en:${'a' * 64}',
      );
    },
  );

  test('diff marks only missing tracks for incremental preparation', () {
    final target = AudioTrackRef(
      sentenceId: 'sentence-1',
      role: AudioTrackRole.target,
      language: 'en',
      voice: 'gentle-natural',
      text: 'One step at a time.',
      key: 'target-key',
    );
    final source = AudioTrackRef(
      sentenceId: 'sentence-1',
      role: AudioTrackRole.source,
      language: 'zh-Hant',
      voice: 'native-gentle',
      text: '一步一步來。',
      key: 'source-key',
    );

    final diff = diffAudioTracks(
      desired: [target, source],
      preparedKeys: {'target-key'},
    );

    expect(diff.unchanged.map((track) => track.key), ['target-key']);
    expect(diff.missing.map((track) => track.key), ['source-key']);
    expect(diff.removedKeys, isEmpty);
  });

  test('diff removes deleted keys but preserves shared audio identities', () {
    final desired = AudioTrackRef(
      sentenceId: 'sentence-2',
      role: AudioTrackRole.target,
      language: 'en',
      voice: 'gentle-natural',
      text: 'One step at a time.',
      key: 'shared-key',
    );

    final diff = diffAudioTracks(
      desired: [desired],
      preparedKeys: {'shared-key', 'deleted-key'},
    );

    expect(diff.unchanged.single.key, 'shared-key');
    expect(diff.removedKeys, ['deleted-key']);
  });

  test(
    'voice or text changes create a new identity instead of reusing the old one',
    () {
      final replacement = AudioTrackRef(
        sentenceId: 'sentence-1',
        role: AudioTrackRole.source,
        language: 'zh-Hant',
        voice: 'native-calm',
        text: '新的內容。',
        key: 'new-key',
      );

      final diff = diffAudioTracks(
        desired: [replacement],
        preparedKeys: {'old-key'},
      );

      expect(diff.missing.single.key, 'new-key');
      expect(diff.removedKeys, ['old-key']);
    },
  );

  test('shared audio identities are prepared only once', () {
    final first = _track('shared-key');
    final second = AudioTrackRef(
      sentenceId: 'sentence-2',
      role: AudioTrackRole.target,
      language: 'en',
      voice: 'gentle-natural',
      text: first.text,
      key: first.key,
    );

    final diff = diffAudioTracks(
      desired: [first, second],
      preparedKeys: const {},
    );

    expect(diff.missing, [first]);
  });
}

AudioTrackRef _track(String key) => AudioTrackRef(
  sentenceId: 'sentence-1',
  role: AudioTrackRole.target,
  language: 'en',
  voice: 'gentle-natural',
  text: 'One step at a time.',
  key: key,
);
