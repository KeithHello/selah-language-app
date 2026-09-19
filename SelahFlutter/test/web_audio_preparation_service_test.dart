import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:selah/web/data/audio_preparation_service.dart';
import 'package:selah/web/domain/audio_preparation.dart';

AudioTrackRef _track(String key) => AudioTrackRef(
  sentenceId: 'sentence-1',
  role: AudioTrackRole.target,
  language: 'en',
  voice: 'gentle-natural',
  text: 'One step at a time.',
  key: key,
);

void main() {
  test(
    'concurrent requests for one key share one in-flight operation',
    () async {
      final service = AudioPreparationService();
      final gate = Completer<void>();
      var calls = 0;
      Future<void> operation(AudioTrackRef _) async {
        calls += 1;
        await gate.future;
      }

      final first = service.ensure(_track('same-key'), operation);
      final second = service.ensure(_track('same-key'), operation);
      gate.complete();
      await Future.wait([first, second]);

      expect(calls, 1);
      expect(service.inFlightKeys, isEmpty);
    },
  );

  test('preparation processes tracks in the supplied priority order', () async {
    final service = AudioPreparationService();
    final order = <String>[];

    await service.prepare([
      _track('target'),
      _track('source'),
    ], operation: (track) async => order.add(track.key));

    expect(order, ['target', 'source']);
  });

  test(
    'different keys wait for the previous audio operation to finish',
    () async {
      final service = AudioPreparationService();
      final firstGate = Completer<void>();
      final started = <String>[];

      final first = service.ensure(_track('first'), (track) async {
        started.add(track.key);
        await firstGate.future;
      });
      final second = service.ensure(_track('second'), (track) async {
        started.add(track.key);
      });

      await Future<void>.delayed(Duration.zero);
      expect(started, ['first']);
      firstGate.complete();
      await Future.wait([first, second]);
      expect(started, ['first', 'second']);
    },
  );

  test(
    'a failed operation is removed so a later retry can run again',
    () async {
      final service = AudioPreparationService();
      var calls = 0;

      Future<void> operation(AudioTrackRef _) async {
        calls += 1;
        if (calls == 1) throw StateError('temporary failure');
      }

      await expectLater(
        service.ensure(_track('retry-key'), operation),
        throwsStateError,
      );
      await service.ensure(_track('retry-key'), operation);

      expect(calls, 2);
    },
  );
}
