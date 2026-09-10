import 'dart:convert';
import 'dart:math';

import 'loop_listening.dart';

/// The user's native language is also the product language choice.  Keeping
/// the script in the value lets one setting select both the interface copy
/// and the language used for new input, while the old `zh` value remains
/// readable for snapshots created before the settings were merged.
const supportedNativeLanguages = <String>['zh-Hant', 'zh-Hans', 'ja'];
const defaultNativeLanguage = 'zh-Hant';

/// Deprecated aliases kept for callers that still describe the UI locale.
/// Both lists intentionally point at the same three user-facing choices.
const supportedUiLocales = supportedNativeLanguages;
const defaultUiLocale = defaultNativeLanguage;
const generationTargetLanguage = 'en';

String normalizeNativeLanguage(Object? value) {
  switch (value) {
    case 'zh-Hant':
    case 'zh-Hans':
    case 'ja':
      return value as String;
    case 'zh':
      // Legacy snapshots used `zh` for the native language.  Traditional
      // Chinese is the only compatible source-language default.
      return 'zh-Hant';
    default:
      return defaultNativeLanguage;
  }
}

/// `uiLocale` is now a derived view of the unified native-language choice.
String normalizeUiLocale(Object? value) => normalizeNativeLanguage(value);

/// Converts the pre-merge pair of fields into the single native-language
/// choice.  An explicit Japanese native-language value wins.  An old Chinese
/// native-language value can retain a separately selected Simplified UI;
/// every other legacy combination falls back to Traditional Chinese.
String migrateNativeLanguage(Object? nativeLanguage, Object? uiLocale) {
  final native = nativeLanguage is String
      ? nativeLanguage.trim()
      : nativeLanguage;
  final ui = uiLocale is String ? uiLocale.trim() : uiLocale;
  if (native == 'ja') return 'ja';
  if (native == 'zh-Hant' || native == 'zh-Hans') {
    return native as String;
  }
  if (native == 'zh') {
    return ui == 'zh-Hans' ? 'zh-Hans' : 'zh-Hant';
  }
  if (native == null) {
    return ui == 'zh-Hans' ? 'zh-Hans' : 'zh-Hant';
  }
  return defaultNativeLanguage;
}

String generationSourceLanguage(String nativeLanguage) =>
    normalizeNativeLanguage(nativeLanguage) == 'ja'
    ? 'ja'
    : currentSourceLanguage;

String transcriptionLanguage(String nativeLanguage) =>
    normalizeNativeLanguage(nativeLanguage) == 'ja' ? 'ja' : 'zh';

const categories = <String, String>{
  'work': '工作的事',
  'friends': '朋友之间',
  'vent': '想吐槽的',
  'heartfelt': '心里话',
  'debate': '我的想法',
  'daily_life': '生活日常',
};
const voices = <String, String>{
  'gentle-natural': '温柔自然',
  'clear-slow': '清晰慢速',
  'daily-bright': '日常轻快',
  'elegant-british': '优雅英式',
};
const reviewStates = ['new', 'learning', 'familiar', 'quiet'];
const vocabularyStates = ['new', 'learning', 'familiar', 'owned'];
const currentGenerationModel = 'gpt-4o-mini';
const currentGenerationPromptVersion = 'v8.0';
const currentSourceLanguage = 'zh-Hant';
const currentTargetLanguage = 'en';
const maxVocabularyItems = 3;
final _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
);

String newId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

Map<String, dynamic> objectMap(Object? value) {
  if (value is! Map) throw const FormatException('数据格式需要是对象。');
  return Map<String, dynamic>.from(value);
}

String requiredText(Object? value, String field, {int max = 4000}) {
  if (value is! String || value.trim().isEmpty || value.length > max) {
    throw FormatException('$field 缺失或超出长度限制。');
  }
  return value.trim();
}

String optionalText(Object? value, {int max = 4000}) {
  if (value == null) return '';
  if (value is! String || value.length > max) {
    throw const FormatException('文本长度或格式无效。');
  }
  return value;
}

String? optionalKnownText(Object? value, {int max = 200}) {
  if (value == null) return null;
  if (value is! String) return null;
  final text = value.trim();
  if (text.isEmpty || text.length > max) return null;
  return text;
}

bool _knownProvenanceText(String? value) =>
    value != null && value.trim().isNotEmpty;

/// Normalization used only when looking for an exact reusable source. It does
/// not fold case, punctuation, or whitespace inside the sentence.
String normalizeSourceForReuse(String value) =>
    value.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();

String validId(Object? value) {
  if (value is! String || !_uuid.hasMatch(value)) {
    throw const FormatException('记录 ID 无效。');
  }
  return value.toLowerCase();
}

DateTime dateValue(Object? value, [DateTime? fallback]) {
  if (value == null && fallback != null) return fallback;
  final date = value is String ? DateTime.tryParse(value) : null;
  if (date == null) throw const FormatException('记录日期无效。');
  return date.toLocal();
}

int? optionalVersion(Object? value) {
  if (value == null) return null;
  if (value is! int || value < 0) {
    throw const FormatException('输入版本无效。');
  }
  return value;
}

List<Map<String, dynamic>> mapList(Object? value, {int max = 10000}) {
  if (value == null) return [];
  if (value is! List || value.length > max) {
    throw const FormatException('记录数量或格式无效。');
  }
  return value.map(objectMap).toList();
}

List<String> boundedTextList(Object? value, {int max = 20}) {
  if (value == null) return [];
  if (value is! List || value.length > max) {
    throw const FormatException('分段数量超过支持上限。');
  }
  return value.map((item) => optionalText(item, max: 4000)).toList();
}

String _choice(Object? value, Iterable<String> allowed, String fallback) {
  if (value == null) return fallback;
  if (value is! String || !allowed.contains(value)) {
    throw const FormatException('记录状态不受支持。');
  }
  return value;
}

class VocabularyEntry {
  VocabularyEntry({
    required this.id,
    required this.text,
    required this.meaning,
    this.state = 'new',
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();
  String id;
  final String text;
  final String meaning;
  String state;
  DateTime updatedAt;
  Map<String, Object?> toJson() => {
    'id': id,
    'text': text,
    'meaning': meaning,
    'state': state,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };
  factory VocabularyEntry.fromJson(Map<String, dynamic> j) => VocabularyEntry(
    id: validId(j['id']),
    text: requiredText(j['text'], '词汇', max: 200),
    meaning: requiredText(j['meaning'], '词义', max: 1000),
    state: _choice(j['state'], vocabularyStates, 'new'),
    updatedAt: dateValue(
      j['updatedAt'],
      DateTime.fromMillisecondsSinceEpoch(0),
    ),
  );
}

class LearnSentence {
  LearnSentence({
    required this.id,
    required this.source,
    required this.target,
    this.category = 'daily_life',
    this.origin = 'user_recording',
    this.seedId,
    String? generationModel,
    String? model,
    this.promptVersion,
    this.sourceLanguage,
    this.targetLanguage,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.reviewState = 'new',
    DateTime? nextReviewAt,
    this.intervalDays = 1,
    this.lapseCount = 0,
    this.lastRecallSignal,
    this.listenedAt,
    this.previewedAt,
    this.archived = false,
    List<Map<String, dynamic>>? breakdown,
    List<VocabularyEntry>? vocabulary,
  }) : generationModel = generationModel ?? model,
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now(),
       nextReviewAt = nextReviewAt ?? DateTime.now(),
       breakdown = breakdown ?? [],
       vocabulary = vocabulary ?? [];
  final String id;
  final String source;
  final String target;
  final String category;
  final String origin;
  final String? seedId;
  final String? generationModel;
  final String? promptVersion;
  final String? sourceLanguage;
  final String? targetLanguage;
  final DateTime createdAt;
  DateTime updatedAt;
  String reviewState;
  DateTime nextReviewAt;
  int intervalDays;
  int lapseCount;
  String? lastRecallSignal;
  DateTime? listenedAt;
  DateTime? previewedAt;
  bool archived;
  final List<Map<String, dynamic>> breakdown;
  final List<VocabularyEntry> vocabulary;
  String get audioSentenceId => seedId ?? id;

  /// Alias for consumers that use the provider response field name.
  String? get model => generationModel;
  bool get hasKnownGenerationProvenance =>
      _knownProvenanceText(generationModel) &&
      _knownProvenanceText(promptVersion) &&
      _knownProvenanceText(sourceLanguage) &&
      _knownProvenanceText(targetLanguage);

  factory LearnSentence.generated({
    required String source,
    required String requestId,
    required Map<String, dynamic> json,
  }) {
    final target = requiredText(json['targetText'], '英文翻译', max: 1000);
    return LearnSentence(
      id: validId(requestId),
      source: source,
      target: target,
      category: _choice(json['category'], categories.keys, 'daily_life'),
      generationModel: optionalKnownText(
        json['generationModel'] ?? json['model'],
        max: 100,
      ),
      promptVersion: optionalKnownText(json['promptVersion'], max: 100),
      sourceLanguage: optionalKnownText(json['sourceLanguage'], max: 20),
      targetLanguage: optionalKnownText(json['targetLanguage'], max: 20),
      breakdown: mapList(json['deconstruction'], max: 50),
      vocabulary: mapList(json['vocabulary'], max: maxVocabularyItems)
          .map(
            (v) => VocabularyEntry(
              id: newId(),
              text: requiredText(v['surfaceText'], '词汇', max: 200),
              meaning: requiredText(v['meaningInContext'], '词义', max: 1000),
              state: _choice(v['suggestedHelpState'], vocabularyStates, 'new'),
            ),
          )
          .toList(),
    );
  }
  factory LearnSentence.seed(Map<String, dynamic> j) {
    final seed = requiredText(j['id'], '种子 ID', max: 30);
    final index = int.tryParse(seed.replaceFirst('seed-', ''));
    if (index == null || index < 1 || index > 999) {
      throw const FormatException('种子 ID 无效。');
    }
    final id = newId();
    return LearnSentence(
      id: id,
      seedId: seed,
      origin: 'system_seed',
      source: requiredText(j['zh_text'], '中文'),
      target: requiredText(j['en_translation'], '英文'),
      category: _choice(j['category'], categories.keys, 'daily_life'),
      breakdown: mapList(j['deconstruction'], max: 50),
      vocabulary: mapList(j['vocab_candidates'], max: 50)
          .asMap()
          .entries
          .map(
            (entry) => VocabularyEntry(
              id: newId(),
              text: requiredText(entry.value['surfaceText'], '词汇', max: 200),
              meaning: requiredText(
                entry.value['meaningInContext'],
                '词义',
                max: 1000,
              ),
              state: _choice(
                entry.value['suggestedHelpState'],
                vocabularyStates,
                'new',
              ),
            ),
          )
          .toList(),
    );
  }
  Map<String, Object?> toJson() => {
    'id': id,
    'source': source,
    'target': target,
    'category': category,
    'origin': origin,
    'seedId': seedId,
    'generationModel': generationModel,
    'promptVersion': promptVersion,
    'sourceLanguage': sourceLanguage,
    'targetLanguage': targetLanguage,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'reviewState': reviewState,
    'nextReviewAt': nextReviewAt.toUtc().toIso8601String(),
    'intervalDays': intervalDays,
    'lapseCount': lapseCount,
    'lastRecallSignal': lastRecallSignal,
    'listenedAt': listenedAt?.toUtc().toIso8601String(),
    'previewedAt': previewedAt?.toUtc().toIso8601String(),
    'archived': archived,
    'breakdown': breakdown,
    'vocabulary': vocabulary.map((v) => v.toJson()).toList(),
  };
  factory LearnSentence.fromJson(Map<String, dynamic> j) {
    final created = dateValue(j['createdAt']);
    final interval = j['intervalDays'] ?? 1;
    final lapses = j['lapseCount'] ?? 0;
    if (interval is! int ||
        interval < 1 ||
        interval > 365 ||
        lapses is! int ||
        lapses < 0) {
      throw const FormatException('复习间隔或次数无效。');
    }
    final seedId = j['seedId'];
    if (seedId != null &&
        (seedId is! String || !RegExp(r'^seed-\d{3}$').hasMatch(seedId))) {
      throw const FormatException('种子来源无效。');
    }
    return LearnSentence(
      id: validId(j['id']),
      source: requiredText(j['source'], '中文'),
      target: requiredText(j['target'], '英文', max: 1000),
      category: _choice(j['category'], categories.keys, 'daily_life'),
      origin: _choice(j['origin'], [
        'system_seed',
        'user_recording',
      ], 'user_recording'),
      seedId: seedId,
      generationModel: optionalKnownText(
        j['generationModel'] ?? j['model'],
        max: 100,
      ),
      promptVersion: optionalKnownText(j['promptVersion'], max: 100),
      sourceLanguage: optionalKnownText(j['sourceLanguage'], max: 20),
      targetLanguage: optionalKnownText(j['targetLanguage'], max: 20),
      createdAt: created,
      updatedAt: dateValue(j['updatedAt'], created),
      reviewState: _choice(j['reviewState'], reviewStates, 'new'),
      nextReviewAt: dateValue(j['nextReviewAt'], created),
      intervalDays: interval,
      lapseCount: lapses,
      lastRecallSignal: j['lastRecallSignal'] == null
          ? null
          : _choice(j['lastRecallSignal'], [
              'clear',
              'almost',
              'failed',
            ], 'failed'),
      listenedAt: j['listenedAt'] == null ? null : dateValue(j['listenedAt']),
      previewedAt: j['previewedAt'] == null
          ? null
          : dateValue(j['previewedAt']),
      archived: j['archived'] == true,
      breakdown: mapList(j['breakdown'], max: 50),
      vocabulary: mapList(
        j['vocabulary'],
        max: 100,
      ).map(VocabularyEntry.fromJson).toList(),
    );
  }
}

class LearnPreferences {
  LearnPreferences({
    this.name = '小豆',
    this.voice = 'gentle-natural',
    this.speed = .85,
    this.onboarded = false,
    this.reminderEnabled = false,
    this.reminderTime = '20:00',
    String? nativeLanguage,
    String? uiLocale,
    LoopOptions? loopOptions,
    DateTime? updatedAt,
  }) : _nativeLanguage = migrateNativeLanguage(nativeLanguage, uiLocale),
       loopOptions = loopOptions ?? const LoopOptions(),
       updatedAt = updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  String name;
  String voice;
  double speed;
  bool onboarded;
  bool reminderEnabled;
  String reminderTime;
  String _nativeLanguage;

  String get nativeLanguage => _nativeLanguage;

  set nativeLanguage(String value) {
    _nativeLanguage = normalizeNativeLanguage(value);
  }

  /// Compatibility view for snapshots and callers from the split-language
  /// implementation.  It is not persisted as a second preference anymore.
  @Deprecated('Use nativeLanguage; the interface follows it automatically.')
  String get uiLocale => nativeLanguage;

  @Deprecated('Use nativeLanguage; the interface follows it automatically.')
  set uiLocale(String value) {
    nativeLanguage = value;
  }

  LoopOptions loopOptions;
  DateTime updatedAt;
  Map<String, Object?> toJson() => {
    'name': name,
    'voice': voice,
    'speed': speed,
    'onboarded': onboarded,
    'reminderEnabled': reminderEnabled,
    'reminderTime': reminderTime,
    'nativeLanguage': normalizeNativeLanguage(nativeLanguage),
    'loopOptions': loopOptions.toJson(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };
  factory LearnPreferences.fromJson(Map<String, dynamic> j) {
    final speed = j['speed'] ?? .85;
    final reminder = j['reminderTime'] ?? '20:00';
    if (speed is! num ||
        ![.7, .85, 1.0, 1.2].contains(speed) ||
        reminder is! String ||
        !RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(reminder)) {
      throw const FormatException('学习偏好无效。');
    }
    return LearnPreferences(
      name: requiredText(j['name'] ?? '小豆', '精灵名字', max: 24),
      voice: _choice(j['voice'], voices.keys, 'gentle-natural'),
      speed: speed.toDouble(),
      onboarded: j['onboarded'] == true,
      reminderEnabled: j['reminderEnabled'] == true,
      reminderTime: reminder,
      nativeLanguage: j['nativeLanguage'] is String
          ? j['nativeLanguage'] as String
          : j.containsKey('nativeLanguage')
          ? ''
          : null,
      uiLocale: j['uiLocale'] is String ? j['uiLocale'] as String : null,
      loopOptions: LoopOptions.fromJson(objectMap(j['loopOptions'] ?? {})),
      updatedAt: dateValue(
        j['updatedAt'],
        DateTime.fromMillisecondsSinceEpoch(0),
      ),
    );
  }
}

class LearnEvent {
  LearnEvent({
    required this.id,
    required this.type,
    this.sentenceId,
    DateTime? at,
    Map<String, dynamic>? metadata,
  }) : at = at ?? DateTime.now(),
       metadata = metadata ?? {};
  final String id;
  final String type;
  final String? sentenceId;
  final DateTime at;
  final Map<String, dynamic> metadata;
  Map<String, Object?> toJson() => {
    'id': id,
    'type': type,
    'sentenceId': sentenceId,
    'at': at.toUtc().toIso8601String(),
    'metadata': metadata,
  };
  factory LearnEvent.fromJson(Map<String, dynamic> j) {
    final type = _choice(j['type'], [
      'sentence_created',
      'listen_completed',
      'practice_rated',
      'preview_completed',
      'memory_unlocked',
      'activity_heartbeat',
    ], 'sentence_created');
    final allowed = <String, List<String>>{
      'sentence_created': ['category', 'origin'],
      'listen_completed': ['duration_ms'],
      'practice_rated': ['signal'],
      'preview_completed': [],
      'activity_heartbeat': [
        'session_id',
        'slot_start',
        'duration_ms',
        'visible',
        'audio_playing',
      ],
      'memory_unlocked': ['memory_key'],
    };
    final metadata = objectMap(j['metadata'] ?? {});
    metadata.removeWhere(
      (key, value) =>
          !allowed[type]!.contains(key) ||
          !(value is String && value.length <= 200 ||
              value is num && value.isFinite ||
              value is bool),
    );
    return LearnEvent(
      id: validId(j['id']),
      type: type,
      sentenceId: j['sentenceId'] == null ? null : validId(j['sentenceId']),
      at: dateValue(j['at']),
      metadata: metadata,
    );
  }
}

class GenerationDraft {
  GenerationDraft({
    required this.id,
    required this.text,
    this.inputVersion,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
  final String id;
  final String text;
  final int? inputVersion;
  final DateTime createdAt;
  int get maxLength => 4000;
  Map<String, Object?> toJson() => {
    'id': id,
    'text': text,
    'inputVersion': inputVersion,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };
  factory GenerationDraft.fromJson(Map<String, dynamic> j) => GenerationDraft(
    id: validId(j['id']),
    text: requiredText(j['text'], '草稿', max: 4000),
    inputVersion: optionalVersion(j['inputVersion']),
    createdAt: dateValue(j['createdAt']),
  );
}

class PreparationSegment {
  PreparationSegment({
    required this.id,
    required this.sourceText,
    this.status = 'pending',
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  String id;
  String sourceText;
  String status;
  DateTime updatedAt;

  bool get isComplete => status == 'succeeded';

  Map<String, Object?> toJson() => {
    'id': id,
    'sourceText': sourceText,
    'status': status,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  factory PreparationSegment.fromJson(Map<String, dynamic> j) =>
      PreparationSegment(
        id: validId(j['id']),
        sourceText: requiredText(j['sourceText'], '分句原文', max: 500),
        status: _choice(j['status'], [
          'pending',
          'succeeded',
          'failed',
        ], 'pending'),
        updatedAt: dateValue(j['updatedAt']),
      );
}

class PreparationDraft {
  PreparationDraft({
    required this.id,
    required this.sourceText,
    this.inputVersion,
    List<PreparationSegment>? segments,
    this.sourceLanguage = 'zh-Hant',
    this.targetLanguage = 'en',
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : segments = segments ?? <PreparationSegment>[],
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now() {
    if (this.segments.length > maxSegments) {
      throw const FormatException('整理分句超过支持上限。');
    }
  }

  static const int maxSegments = 20;
  final String id;
  String sourceText;
  int? inputVersion;
  final List<PreparationSegment> segments;
  final String sourceLanguage;
  final String targetLanguage;
  final DateTime createdAt;
  DateTime updatedAt;

  List<PreparationSegment> get pendingSegments =>
      segments.where((segment) => !segment.isComplete).toList();

  Map<String, Object?> toJson() => {
    'id': id,
    'sourceText': sourceText,
    'inputVersion': inputVersion,
    'sourceLanguage': sourceLanguage,
    'targetLanguage': targetLanguage,
    'segments': segments.map((segment) => segment.toJson()).toList(),
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  factory PreparationDraft.fromJson(Map<String, dynamic> j) {
    final segments = mapList(
      j['segments'],
      max: maxSegments,
    ).map(PreparationSegment.fromJson).toList();
    final ids = segments.map((segment) => segment.id).toSet();
    if (ids.length != segments.length) {
      throw const FormatException('整理分句无效。');
    }
    return PreparationDraft(
      id: validId(j['id']),
      sourceText: requiredText(j['sourceText'], '整理原文', max: 4000),
      inputVersion: optionalVersion(j['inputVersion']),
      segments: segments,
      sourceLanguage: optionalText(j['sourceLanguage']) == ''
          ? 'zh-Hant'
          : requiredText(j['sourceLanguage'], '源语言', max: 20),
      targetLanguage: optionalText(j['targetLanguage']) == ''
          ? 'en'
          : requiredText(j['targetLanguage'], '目标语言', max: 20),
      createdAt: dateValue(j['createdAt']),
      updatedAt: dateValue(j['updatedAt'], dateValue(j['createdAt'])),
    );
  }
}

PreparationSegment _copyPreparationSegment(PreparationSegment segment) =>
    PreparationSegment(
      id: segment.id,
      sourceText: segment.sourceText,
      status: segment.status,
      updatedAt: segment.updatedAt,
    );

PreparationDraft _copyPreparationDraft(PreparationDraft draft) =>
    PreparationDraft(
      id: draft.id,
      sourceText: draft.sourceText,
      inputVersion: draft.inputVersion,
      segments: draft.segments.map(_copyPreparationSegment).toList(),
      sourceLanguage: draft.sourceLanguage,
      targetLanguage: draft.targetLanguage,
      createdAt: draft.createdAt,
      updatedAt: draft.updatedAt,
    );

PreparationDraft _mergePreparationDrafts(
  PreparationDraft current,
  PreparationDraft incoming,
) {
  if (current.id != incoming.id || current.sourceText != incoming.sourceText) {
    return incoming.updatedAt.isAfter(current.updatedAt)
        ? _copyPreparationDraft(incoming)
        : _copyPreparationDraft(current);
  }
  final incomingById = {
    for (final segment in incoming.segments) segment.id: segment,
  };
  final used = <String>{};
  final segments = <PreparationSegment>[];
  for (final local in current.segments) {
    final remote = incomingById[local.id];
    if (remote == null) {
      segments.add(_copyPreparationSegment(local));
      continue;
    }
    used.add(remote.id);
    final winner = local.isComplete && !remote.isComplete
        ? local
        : remote.isComplete && !local.isComplete
        ? remote
        : remote.updatedAt.isAfter(local.updatedAt)
        ? remote
        : local;
    segments.add(_copyPreparationSegment(winner));
  }
  for (final remote in incoming.segments) {
    if (!used.contains(remote.id) &&
        !current.segments.any((segment) => segment.id == remote.id)) {
      segments.add(_copyPreparationSegment(remote));
    }
  }
  return PreparationDraft(
    id: current.id,
    sourceText: current.sourceText,
    inputVersion: incoming.inputVersion ?? current.inputVersion,
    segments: segments,
    sourceLanguage: incoming.sourceLanguage,
    targetLanguage: incoming.targetLanguage,
    createdAt: current.createdAt,
    updatedAt: incoming.updatedAt.isAfter(current.updatedAt)
        ? incoming.updatedAt
        : current.updatedAt,
  );
}

class LearningSnapshot {
  LearningSnapshot({
    required this.preferences,
    required this.sentences,
    required this.events,
    required this.drafts,
    required this.audio,
    required this.memories,
    this.todayInput = '',
    List<String>? segmentInputs,
    this.preparationDraft,
    this.lastSyncAt,
    this.accountScope = 'guest',
  }) : segmentInputs = segmentInputs ?? <String>[];
  String accountScope;
  LearnPreferences preferences;
  final List<LearnSentence> sentences;
  final List<LearnEvent> events;
  final List<GenerationDraft> drafts;
  final Map<String, Map<String, dynamic>> audio;
  final Map<String, DateTime> memories;
  String todayInput;
  final List<String> segmentInputs;
  PreparationDraft? preparationDraft;
  DateTime? lastSyncAt;
  factory LearningSnapshot.empty() => LearningSnapshot(
    preferences: LearnPreferences(),
    sentences: [],
    events: [],
    drafts: [],
    audio: {},
    memories: {},
  );
  Map<String, Object?> toBackup() => {
    'format': 'selah-web',
    'version': 1,
    'accountScope': accountScope,
    'preferences': preferences.toJson(),
    'sentences': sentences.map((s) => s.toJson()).toList(),
    'events': events.map((e) => e.toJson()).toList(),
    'drafts': drafts.map((d) => d.toJson()).toList(),
    'audio': audio,
    'memories': memories.map(
      (k, v) => MapEntry(k, v.toUtc().toIso8601String()),
    ),
    'todayInput': todayInput,
    'segmentInputs': segmentInputs,
    'preparationDraft': preparationDraft?.toJson(),
    'lastSyncAt': lastSyncAt?.toUtc().toIso8601String(),
  };
  factory LearningSnapshot.importBackup(String raw) {
    if (utf8.encode(raw).length > 10 * 1024 * 1024) {
      throw const FormatException('备份不能超过 10 MB。');
    }
    final j = objectMap(jsonDecode(raw));
    if (j['format'] != 'selah-web' || j['version'] != 1) {
      throw const FormatException('不支持此备份格式或版本。');
    }
    final sentences = mapList(
      j['sentences'],
    ).map(LearnSentence.fromJson).toList();
    final ids = sentences.map((s) => s.id).toSet();
    if (ids.length != sentences.length) {
      throw const FormatException('备份含重复句子 ID。');
    }
    final vocabularyIds = <String>{};
    for (final sentence in sentences) {
      for (final word in sentence.vocabulary) {
        if (!vocabularyIds.add(word.id)) {
          throw const FormatException('备份含重复词汇 ID。');
        }
      }
    }
    final events = mapList(
      j['events'],
      max: 50000,
    ).map(LearnEvent.fromJson).toList();
    if (events.map((event) => event.id).toSet().length != events.length) {
      throw const FormatException('备份含重复事件 ID。');
    }
    if (events.any(
      (e) => e.sentenceId != null && !ids.contains(e.sentenceId),
    )) {
      throw const FormatException('学习事件引用了缺失的句子。');
    }
    final audio = objectMap(
      j['audio'] ?? {},
    ).map((k, v) => MapEntry(k, objectMap(v)));
    final scope = j['accountScope'] ?? 'guest';
    if (scope != 'guest') validId(scope);
    return LearningSnapshot(
      accountScope: scope,
      preferences: LearnPreferences.fromJson(objectMap(j['preferences'] ?? {})),
      sentences: sentences,
      events: events,
      drafts: mapList(
        j['drafts'],
        max: 500,
      ).map(GenerationDraft.fromJson).toList(),
      audio: audio,
      memories: objectMap(
        j['memories'] ?? {},
      ).map((k, v) => MapEntry(k, dateValue(v))),
      todayInput: optionalText(j['todayInput'], max: 4000),
      segmentInputs: boundedTextList(
        j['segmentInputs'],
        max: PreparationDraft.maxSegments,
      ),
      preparationDraft: j['preparationDraft'] == null
          ? null
          : PreparationDraft.fromJson(objectMap(j['preparationDraft'])),
      lastSyncAt: j['lastSyncAt'] == null ? null : dateValue(j['lastSyncAt']),
    );
  }
  LearningSnapshot copy() =>
      LearningSnapshot.importBackup(jsonEncode(toBackup()));
  LearningSnapshot forAccount(String account) {
    if (account == accountScope) return copy();
    // This is an ID namespace transform, not encryption or an authentication boundary.
    // It keeps repeated imports stable while avoiding global primary-key collisions between users.
    String rebase(String id) {
      List<int> bytes(String value) {
        final hex = value == 'guest'
            ? '0' * 32
            : validId(value).replaceAll('-', '');
        return List.generate(
          16,
          (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16),
        );
      }

      final value = bytes(id),
          oldScope = bytes(accountScope),
          newScope = bytes(account);
      for (var i = 0; i < 16; i++) {
        value[i] ^= oldScope[i] ^ newScope[i];
      }
      value[6] = (value[6] & 15) | 64;
      value[8] = (value[8] & 63) | 128;
      final h = value.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
    }

    final json = toBackup();
    json['accountScope'] = account;
    json['audio'] = {};
    json['lastSyncAt'] = null;
    json['sentences'] = sentences
        .map(
          (s) => {
            ...s.toJson(),
            'id': rebase(s.id),
            'vocabulary': s.vocabulary
                .map((v) => {...v.toJson(), 'id': rebase(v.id)})
                .toList(),
          },
        )
        .toList();
    json['events'] = events
        .map(
          (e) => {
            ...e.toJson(),
            'id': rebase(e.id),
            'sentenceId': e.sentenceId == null ? null : rebase(e.sentenceId!),
          },
        )
        .toList();
    json['drafts'] = drafts
        .map((d) => {...d.toJson(), 'id': rebase(d.id)})
        .toList();
    if (preparationDraft != null) {
      final preparation = PreparationDraft(
        id: rebase(preparationDraft!.id),
        sourceText: preparationDraft!.sourceText,
        inputVersion: preparationDraft!.inputVersion,
        segments: preparationDraft!.segments
            .map(
              (segment) => PreparationSegment(
                id: rebase(segment.id),
                sourceText: segment.sourceText,
                status: segment.status,
                updatedAt: segment.updatedAt,
              ),
            )
            .toList(),
        sourceLanguage: preparationDraft!.sourceLanguage,
        targetLanguage: preparationDraft!.targetLanguage,
        createdAt: preparationDraft!.createdAt,
        updatedAt: preparationDraft!.updatedAt,
      );
      json['preparationDraft'] = {...preparation.toJson()};
    }
    return LearningSnapshot.importBackup(jsonEncode(json));
  }

  LearningSnapshot merge(LearningSnapshot other) {
    final result = copy();
    // The unified native-language choice is device-local in this phase.  A
    // cloud or imported snapshot may carry an older schema or a newer general
    // preference timestamp, but it must never erase the local choice.
    final localNativeLanguage = normalizeNativeLanguage(
      preferences.nativeLanguage,
    );
    final byId = {for (final s in result.sentences) s.id: s};
    for (final incoming in other.sentences) {
      final current = byId[incoming.id];
      if (current == null || incoming.updatedAt.isAfter(current.updatedAt)) {
        byId[incoming.id] = LearnSentence.fromJson(incoming.toJson());
      }
      final winner = byId[incoming.id]!;
      final vocab = {for (final v in winner.vocabulary) v.id: v};
      for (final v in [...?current?.vocabulary, ...incoming.vocabulary]) {
        if (vocab[v.id] == null ||
            v.updatedAt.isAfter(vocab[v.id]!.updatedAt)) {
          vocab[v.id] = VocabularyEntry.fromJson(v.toJson());
        }
      }
      winner.vocabulary
        ..clear()
        ..addAll(vocab.values);
    }
    result.sentences
      ..clear()
      ..addAll(byId.values);
    final events = {
      for (final e in [...result.events, ...other.events]) e.id: e,
    };
    result.events
      ..clear()
      ..addAll(events.values);
    final drafts = {for (final d in result.drafts) d.id: d};
    for (final draft in other.drafts) {
      drafts.putIfAbsent(draft.id, () => draft);
    }
    result.drafts
      ..clear()
      ..addAll(drafts.values.where((d) => !byId.containsKey(d.id)));
    final currentPreparation = result.preparationDraft;
    final incomingPreparation = other.preparationDraft;
    if (currentPreparation == null && incomingPreparation != null) {
      result.preparationDraft = _copyPreparationDraft(incomingPreparation);
    } else if (currentPreparation != null && incomingPreparation != null) {
      result.preparationDraft = _mergePreparationDrafts(
        currentPreparation,
        incomingPreparation,
      );
    }
    if (result.todayInput.isEmpty && other.todayInput.isNotEmpty) {
      result.todayInput = other.todayInput;
    }
    if (result.segmentInputs.isEmpty && other.segmentInputs.isNotEmpty) {
      result.segmentInputs.addAll(other.segmentInputs);
    }
    if (other.preferences.updatedAt.isAfter(result.preferences.updatedAt)) {
      result.preferences = LearnPreferences.fromJson(
        other.preferences.toJson(),
      );
    }
    result.preferences.nativeLanguage = localNativeLanguage;
    for (final entry in other.memories.entries) {
      result.memories.update(
        entry.key,
        (date) => date.isBefore(entry.value) ? date : entry.value,
        ifAbsent: () => entry.value,
      );
    }
    // Cache presence is always checked in the current browser; URLs are not trusted as files.
    for (final entry in other.audio.entries) {
      result.audio.putIfAbsent(entry.key, () => Map.of(entry.value));
    }
    return result;
  }
}
