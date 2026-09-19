enum AudioTrackRole { target, source }

String audioTrackKey({
  required String voice,
  required AudioTrackRole role,
  required String language,
  required String contentHash,
}) => 'loop:$voice:${role.name}:$language:$contentHash';

class AudioTrackRef {
  const AudioTrackRef({
    required this.sentenceId,
    required this.role,
    required this.language,
    required this.voice,
    required this.text,
    required this.key,
  });

  final String sentenceId;
  final AudioTrackRole role;
  final String language;
  final String voice;
  final String text;
  final String key;

  Map<String, Object?> toLoopTrack() => {
    'sentenceId': sentenceId,
    'role': role.name,
    'language': language,
    'key': key,
    'text': text,
  };
}

class AudioPreparationDiff {
  const AudioPreparationDiff({
    required this.missing,
    required this.unchanged,
    required this.removedKeys,
  });

  final List<AudioTrackRef> missing;
  final List<AudioTrackRef> unchanged;
  final List<String> removedKeys;
}

AudioPreparationDiff diffAudioTracks({
  required Iterable<AudioTrackRef> desired,
  required Set<String> preparedKeys,
}) {
  final desiredList = desired.toList(growable: false);
  final desiredKeys = desiredList.map((track) => track.key).toSet();
  final missing = <AudioTrackRef>[];
  final unchanged = <AudioTrackRef>[];
  final seenKeys = <String>{};
  for (final track in desiredList) {
    if (!seenKeys.add(track.key)) continue;
    if (preparedKeys.contains(track.key)) {
      unchanged.add(track);
    } else {
      missing.add(track);
    }
  }
  return AudioPreparationDiff(
    missing: missing,
    unchanged: unchanged,
    removedKeys: preparedKeys
        .where((key) => !desiredKeys.contains(key))
        .toList(growable: false),
  );
}
