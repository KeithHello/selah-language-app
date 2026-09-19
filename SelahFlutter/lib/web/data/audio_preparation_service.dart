import '../domain/audio_preparation.dart';

typedef AudioTrackOperation = Future<void> Function(AudioTrackRef track);

/// Coordinates audio work that can be requested by both Today and Loop.
///
/// The service deliberately owns only queue identity and de-duplication. The
/// controller supplies the operation so account, cache and gateway state stay
/// in the current controller scope.
class AudioPreparationService {
  final Map<String, Future<void>> _inFlight = {};
  Future<void> _tail = Future<void>.value();

  Iterable<String> get inFlightKeys => _inFlight.keys;

  Future<void> ensure(AudioTrackRef track, AudioTrackOperation operation) {
    final existing = _inFlight[track.key];
    if (existing != null) return existing;

    final scheduled = _tail.then<void>((_) => operation(track));
    late final Future<void> future;
    future = scheduled.whenComplete(() {
      if (identical(_inFlight[track.key], future)) {
        _inFlight.remove(track.key);
      }
    });
    _inFlight[track.key] = future;
    _tail = scheduled.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return future;
  }

  Future<void> prepare(
    Iterable<AudioTrackRef> tracks, {
    required AudioTrackOperation operation,
    void Function(int completed, int total)? onProgress,
  }) async {
    final ordered = tracks.toList(growable: false);
    for (var index = 0; index < ordered.length; index += 1) {
      await ensure(ordered[index], operation);
      onProgress?.call(index + 1, ordered.length);
    }
  }

  void clear() {
    _inFlight.clear();
    _tail = Future<void>.value();
  }
}
