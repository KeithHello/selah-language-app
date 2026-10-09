enum AudioTrackRole { target, source }

const audioCacheKeyVersion = 'audio:v3';
const audioLevelRevision = 'azure-vol-v2';
const seedAudioRevision = 'azure-vol-v2';
const audioCacheKeyPrefix = '$audioCacheKeyVersion:loop:';

bool isNormalizedAudioEntry(Object? entry) =>
    entry is Map && entry['normalizerRevision'] == seedAudioRevision;

String audioProviderForLanguage(String language) => 'azure';

String audioProviderVoice({required String voice, required String language}) {
  final azureVoice = language.startsWith('zh')
      ? 'zh-TW-HsiaoChenNeural'
      : language.startsWith('ja')
      ? 'ja-JP-NanamiNeural'
      : switch (voice) {
          'elegant-british' => 'en-GB-SoniaNeural',
          'daily-bright' => 'en-US-GuyNeural',
          _ => 'en-US-JennyNeural',
        };
  return '$azureVoice@$voice';
}

String audioProviderModel({required String voice, required String language}) {
  final providerVoice = audioProviderVoice(voice: voice, language: language);
  return 'azure-speech/${providerVoice.split('@').first}';
}

double audioSpeedForProfile(String voice) => switch (voice) {
  'clear-slow' => 0.9,
  'native-clear' => 0.95,
  'daily-bright' || 'native-bright' => 1.05,
  'native-calm' => 0.92,
  _ => 1,
};

String _audioSpeedText(double speed) => speed == speed.roundToDouble()
    ? speed.toInt().toString()
    : speed.toString();

String audioManifestCachePattern({
  required String voice,
  required String language,
}) {
  final providerVoice = audioProviderVoice(voice: voice, language: language);
  final speed = audioSpeedForProfile(voice);
  return 'azure:$providerVoice:${_audioSpeedText(speed)}:$audioLevelRevision:%';
}

String audioAccentFor({required String voice, required String language}) {
  if (language.startsWith('zh')) return 'zh-TW';
  if (language.startsWith('ja')) return 'ja-JP';
  return voice == 'elegant-british' ? 'en-GB' : 'en-US';
}

String audioTrackKey({
  required String voice,
  required AudioTrackRole role,
  required String language,
  required String contentHash,
}) {
  final provider = audioProviderForLanguage(language);
  final providerVoice = audioProviderVoice(voice: voice, language: language);
  final speed = audioSpeedForProfile(voice);
  return '$audioCacheKeyPrefix$provider:$providerVoice:${_audioSpeedText(speed)}:$audioLevelRevision:$voice:${role.name}:$language:$contentHash';
}

String singleAudioTrackKey({
  required String sentenceId,
  required String voice,
  required String language,
  required String contentHash,
}) {
  final provider = audioProviderForLanguage(language);
  final providerVoice = audioProviderVoice(voice: voice, language: language);
  final speed = audioSpeedForProfile(voice);
  return '$audioCacheKeyVersion:sentence:$sentenceId:$provider:$providerVoice:${_audioSpeedText(speed)}:$audioLevelRevision:$voice:target:$language:$contentHash';
}

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

  String get provider => audioProviderForLanguage(language);

  String get accent => audioAccentFor(voice: voice, language: language);

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
