/// Selah 领域枚举。
/// 与 Swift 侧 `SelahTypes.swift` 保持一致的字符串值，保证 JSON 契约兼容。
library;

enum SentenceCategory {
  work('work'),
  life('life'),
  travel('travel'),
  social('social'),
  study('study'),
  feelings('feelings');

  const SentenceCategory(this.apiValue);
  final String apiValue;

  static SentenceCategory? fromApi(String? value) {
    for (final c in SentenceCategory.values) {
      if (c.apiValue == value) return c;
    }
    return null;
  }

  String get labelZh => switch (this) {
        SentenceCategory.work => '工作',
        SentenceCategory.life => '生活',
        SentenceCategory.travel => '旅行',
        SentenceCategory.social => '社交',
        SentenceCategory.study => '學習',
        SentenceCategory.feelings => '心情',
      };
}

enum VocabHelpState {
  new_('new'),
  learning('learning'),
  mastered('mastered');

  const VocabHelpState(this.apiValue);
  final String apiValue;
}

enum ReviewStateValue {
  new_('new'),
  learning('learning'),
  reviewing('reviewing'),
  mastered('mastered'),
  archived('archived');

  const ReviewStateValue(this.apiValue);
  final String apiValue;
}

enum SentenceOrigin {
  userRecording('user_recording'),
  systemSeed('system_seed'),
  manual('manual');

  const SentenceOrigin(this.apiValue);
  final String apiValue;
}

enum AudioGenerationStatus {
  queued('queued'),
  generating('generating'),
  ready('ready'),
  failed('failed');

  const AudioGenerationStatus(this.apiValue);
  final String apiValue;
}

enum AudioGenerationReason {
  initial('initial'),
  voiceChange('voice_change'),
  fileMissing('file_missing'),
  retry('retry');

  const AudioGenerationReason(this.apiValue);
  final String apiValue;
}

enum GenerationJobType {
  audioGeneration('audio_generation'),
  sentenceGeneration('sentence_generation');

  const GenerationJobType(this.apiValue);
  final String apiValue;
}

enum GenerationJobStatus {
  queued('queued'),
  inProgress('in_progress'),
  succeeded('succeeded'),
  failed('failed');

  const GenerationJobStatus(this.apiValue);
  final String apiValue;
}

enum VoiceProfile {
  gentleNatural('gentle-natural'),
  clearSlow('clear-slow'),
  dailyBright('daily-bright'),
  elegantBritish('elegant-british');

  const VoiceProfile(this.apiValue);
  final String apiValue;

  String get labelZh => switch (this) {
        VoiceProfile.gentleNatural => '溫柔自然',
        VoiceProfile.clearSlow => '清晰慢速',
        VoiceProfile.dailyBright => '日常輕快',
        VoiceProfile.elegantBritish => '優雅英式',
      };
}

enum SourceLanguage {
  zhHant('zh-Hant');

  const SourceLanguage(this.apiValue);
  final String apiValue;
}

enum TargetLanguage {
  en('en'),
  ja('ja');

  const TargetLanguage(this.apiValue);
  final String apiValue;
}

enum PlaybackSpeed {
  x070(0.7),
  x085(0.85),
  x100(1.0),
  x120(1.2);

  const PlaybackSpeed(this.value);
  final double value;

  String get label => switch (this) {
        PlaybackSpeed.x070 => '0.7x',
        PlaybackSpeed.x085 => '0.85x',
        PlaybackSpeed.x100 => '1.0x',
        PlaybackSpeed.x120 => '1.2x',
      };
}

enum LearningEventType {
  sentenceCreated('sentence_created'),
  listenCompleted('listen_completed'),
  practiceCompleted('practice_completed'),
  memoryUnlocked('memory_unlocked'),
  nightPreviewSeen('night_preview_seen'),
  reviewCompleted('review_completed');

  const LearningEventType(this.apiValue);
  final String apiValue;
}

enum SpriteActionId {
  gentleFloat('gentle-float'),
  blink('blink'),
  leafSway('leaf-sway'),
  listenEnter('listen-enter'),
  listenPlaying('listen-playing'),
  listenComplete('listen-complete'),
  recRecording('rec-recording'),
  recDone('rec-done'),
  quizGood('quiz-good'),
  quizFail('quiz-fail');

  const SpriteActionId(this.apiValue);
  final String apiValue;
}

enum DecorationStage {
  none('none'),
  sprout('sprout'),
  leaf('leaf'),
  bud('bud'),
  bloom('bloom');

  const DecorationStage(this.apiValue);
  final String apiValue;
}
