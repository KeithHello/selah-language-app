import '../domain/entities.dart';
import '../domain/selah_enums.dart';

/// 与后端 Edge Functions JSON 契约对应的 DTO 解析。
/// 未知字段忽略；缺少必填字段抛出 [FormatException]。
class BootstrapConfigDto {
  const BootstrapConfigDto({
    required this.sourceLanguages,
    required this.targetLanguages,
    required this.defaultVoiceProfile,
    required this.voiceProfiles,
    required this.seedSentencePackVersion,
    required this.promptVersion,
    required this.featureFlags,
  });

  final List<String> sourceLanguages;
  final List<String> targetLanguages;
  final String defaultVoiceProfile;
  final List<VoiceProfileConfig> voiceProfiles;
  final String seedSentencePackVersion;
  final String promptVersion;
  final Map<String, bool> featureFlags;

  factory BootstrapConfigDto.fromJson(Map<String, Object?> json) {
    return BootstrapConfigDto(
      sourceLanguages: _stringList(json['sourceLanguages']),
      targetLanguages: _stringList(json['targetLanguages']),
      defaultVoiceProfile: json['defaultVoiceProfile'] as String? ?? 'gentle-natural',
      voiceProfiles: _voiceProfiles(json['voiceProfiles']),
      seedSentencePackVersion: json['seedSentencePackVersion'] as String? ?? '',
      promptVersion: json['promptVersion'] as String? ?? '',
      featureFlags: (json['featureFlags'] as Map<String, Object?>? ?? const {})
          .map((k, v) => MapEntry(k, v == true)),
    );
  }

  BootstrapConfig toEntity() => BootstrapConfig(
        sourceLanguages: sourceLanguages,
        targetLanguages: targetLanguages,
        defaultVoiceProfile: defaultVoiceProfile,
        voiceProfiles: voiceProfiles,
        seedSentencePackVersion: seedSentencePackVersion,
        promptVersion: promptVersion,
        featureFlags: featureFlags,
      );
}

class GeneratedSentenceDto {
  const GeneratedSentenceDto({
    required this.sentenceId,
    required this.zhText,
    required this.enText,
    required this.category,
    required this.deconstruction,
    required this.vocabCandidates,
  });

  final String sentenceId;
  final String zhText;
  final String enText;
  final String category;
  final List<Map<String, Object?>> deconstruction;
  final List<Map<String, Object?>> vocabCandidates;

  factory GeneratedSentenceDto.fromJson(Map<String, Object?> json) {
    return GeneratedSentenceDto(
      sentenceId: json['sentenceId'] as String? ?? '',
      zhText: json['zhText'] as String? ?? json['sourceText'] as String? ?? '',
      enText: json['enText'] as String? ?? json['translation'] as String? ?? '',
      category: json['category'] as String? ?? 'life',
      deconstruction: (json['deconstruction'] as List<Object?>? ?? const [])
          .whereType<Map<String, Object?>>()
          .toList(),
      vocabCandidates: (json['vocabCandidates'] as List<Object?>? ?? const [])
          .whereType<Map<String, Object?>>()
          .toList(),
    );
  }

  GeneratedSentenceResult toEntity() {
    final categoryEnum = SentenceCategory.fromApi(category) ?? SentenceCategory.life;
    return GeneratedSentenceResult(
      sentenceId: sentenceId.isEmpty ? 'seed-${DateTime.now().microsecondsSinceEpoch}' : sentenceId,
      zhText: zhText,
      enText: enText,
      category: categoryEnum,
      deconstruction: deconstruction
          .map((d) => DeconstructionItem(
                surfaceText: d['surfaceText'] as String? ?? '',
                meaning: d['meaning'] as String? ?? '',
                type: d['type'] as String? ?? 'phrase',
              ))
          .toList(),
      vocabCandidates: vocabCandidates
          .map((v) => VocabCandidate(
                surfaceText: v['surfaceText'] as String? ?? '',
                meaningInContext: v['meaningInContext'] as String? ?? '',
                helpState: _vocabHelp(v['suggestedHelpState'] as String?),
              ))
          .toList(),
    );
  }
}

class GeneratedAudioDto {
  const GeneratedAudioDto({
    required this.status,
    required this.voiceProfile,
    this.manifestId,
    this.downloadUrl,
    this.storagePath,
    this.sha256,
    this.byteSize = 0,
    this.durationMs = 0,
    this.cacheHit = false,
    this.errorCode,
  });

  final String status;
  final String voiceProfile;
  final String? manifestId;
  final String? downloadUrl;
  final String? storagePath;
  final String? sha256;
  final int byteSize;
  final int durationMs;
  final bool cacheHit;
  final String? errorCode;

  factory GeneratedAudioDto.fromJson(Map<String, Object?> json) {
    return GeneratedAudioDto(
      status: json['status'] as String? ?? 'failed',
      voiceProfile: json['voiceProfile'] as String? ?? 'gentle-natural',
      manifestId: json['manifestId'] as String?,
      downloadUrl: json['downloadUrl'] as String?,
      storagePath: json['storagePath'] as String?,
      sha256: json['sha256'] as String?,
      byteSize: (json['byteSize'] as num?)?.toInt() ?? 0,
      durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
      cacheHit: json['cacheHit'] == true,
      errorCode: json['errorCode'] as String?,
    );
  }

  GeneratedAudioResult toEntity() {
    return GeneratedAudioResult(
      status: _audioStatus(status),
      voiceProfile: VoiceProfile.values.firstWhere(
        (v) => v.apiValue == voiceProfile,
        orElse: () => VoiceProfile.gentleNatural,
      ),
      manifestId: manifestId,
      downloadUrl: downloadUrl,
      storagePath: storagePath,
      sha256: sha256,
      byteSize: byteSize,
      durationMs: durationMs,
      cacheHit: cacheHit,
      errorCode: errorCode,
    );
  }
}

List<String> _stringList(Object? value) {
  if (value is List<Object?>) {
    return value.whereType<String>().toList();
  }
  return const [];
}

List<VoiceProfileConfig> _voiceProfiles(Object? value) {
  if (value is! List<Object?>) return const [];
  return value.whereType<Map<String, Object?>>().map((v) {
    return VoiceProfileConfig(
      id: v['id'] as String? ?? '',
      label: v['label'] as String? ?? '',
      description: v['description'] as String? ?? '',
    );
  }).toList();
}

VocabHelpState _vocabHelp(String? value) {
  for (final s in VocabHelpState.values) {
    if (s.apiValue == value) return s;
  }
  return VocabHelpState.new_;
}

AudioGenerationStatus _audioStatus(String value) {
  for (final s in AudioGenerationStatus.values) {
    if (s.apiValue == value) return s;
  }
  return AudioGenerationStatus.failed;
}
