import 'package:equatable/equatable.dart';

import 'selah_enums.dart';

/// 句子实体（学习核心）。
class Sentence extends Equatable {
  const Sentence({
    required this.id,
    required this.zhText,
    required this.enText,
    required this.category,
    required this.difficulty,
    required this.origin,
    this.deconstruction = const [],
    this.vocabCandidates = const [],
    this.reviewState = ReviewStateValue.new_,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String zhText;
  final String enText;
  final SentenceCategory category;
  final String difficulty;
  final SentenceOrigin origin;
  final List<DeconstructionItem> deconstruction;
  final List<VocabCandidate> vocabCandidates;
  final ReviewStateValue reviewState;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Sentence copyWith({
    ReviewStateValue? reviewState,
    DateTime? updatedAt,
  }) {
    return Sentence(
      id: id,
      zhText: zhText,
      enText: enText,
      category: category,
      difficulty: difficulty,
      origin: origin,
      deconstruction: deconstruction,
      vocabCandidates: vocabCandidates,
      reviewState: reviewState ?? this.reviewState,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, zhText, enText, category, reviewState];
}

class DeconstructionItem extends Equatable {
  const DeconstructionItem({
    required this.surfaceText,
    required this.meaning,
    required this.type,
  });

  final String surfaceText;
  final String meaning;
  final String type;

  @override
  List<Object?> get props => [surfaceText, meaning, type];
}

class VocabCandidate extends Equatable {
  const VocabCandidate({
    required this.surfaceText,
    required this.meaningInContext,
    this.helpState = VocabHelpState.new_,
  });

  final String surfaceText;
  final String meaningInContext;
  final VocabHelpState helpState;

  @override
  List<Object?> get props => [surfaceText, meaningInContext, helpState];
}

/// 词汇条目（句子保存时派生）。
class VocabItem extends Equatable {
  const VocabItem({
    required this.id,
    required this.sentenceId,
    required this.surfaceText,
    required this.meaning,
    this.helpState = VocabHelpState.new_,
  });

  final String id;
  final String sentenceId;
  final String surfaceText;
  final String meaning;
  final VocabHelpState helpState;

  @override
  List<Object?> get props => [id, sentenceId, surfaceText, helpState];
}

/// 音频资产（TTS 结果本地引用）。
class AudioAsset extends Equatable {
  const AudioAsset({
    required this.id,
    required this.sentenceId,
    required this.voiceProfile,
    required this.status,
    this.localPath,
    this.remotePath,
    this.sha256,
    this.byteSize = 0,
    this.durationMs = 0,
    this.speed = 0.85,
    this.errorCode,
    this.createdAt,
    this.downloadedAt,
    this.lastPlayedAt,
  });

  final String id;
  final String sentenceId;
  final VoiceProfile voiceProfile;
  final AudioGenerationStatus status;
  final String? localPath;
  final String? remotePath;
  final String? sha256;
  final int byteSize;
  final int durationMs;
  final double speed;
  final String? errorCode;
  final DateTime? createdAt;
  final DateTime? downloadedAt;
  final DateTime? lastPlayedAt;

  AudioAsset copyWith({
    AudioGenerationStatus? status,
    String? localPath,
    String? sha256,
    int? byteSize,
    int? durationMs,
    String? errorCode,
    DateTime? downloadedAt,
    DateTime? lastPlayedAt,
  }) {
    return AudioAsset(
      id: id,
      sentenceId: sentenceId,
      voiceProfile: voiceProfile,
      status: status ?? this.status,
      localPath: localPath ?? this.localPath,
      remotePath: remotePath,
      sha256: sha256 ?? this.sha256,
      byteSize: byteSize ?? this.byteSize,
      durationMs: durationMs ?? this.durationMs,
      speed: speed,
      errorCode: errorCode ?? this.errorCode,
      createdAt: createdAt,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
    );
  }

  @override
  List<Object?> get props => [id, sentenceId, voiceProfile, status, localPath];
}

/// 音频生成重试任务。
class GenerationJob extends Equatable {
  const GenerationJob({
    required this.id,
    required this.sentenceId,
    required this.type,
    required this.status,
    this.targetText,
    this.voiceProfile,
    this.reason,
    this.retryCount = 0,
    this.maxRetries = 3,
    this.nextRetryAt,
    this.lastErrorCode,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String sentenceId;
  final GenerationJobType type;
  final GenerationJobStatus status;
  final String? targetText;
  final VoiceProfile? voiceProfile;
  final AudioGenerationReason? reason;
  final int retryCount;
  final int maxRetries;
  final DateTime? nextRetryAt;
  final String? lastErrorCode;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  GenerationJob copyWith({
    GenerationJobStatus? status,
    int? retryCount,
    DateTime? nextRetryAt,
    String? lastErrorCode,
    DateTime? updatedAt,
  }) {
    return GenerationJob(
      id: id,
      sentenceId: sentenceId,
      type: type,
      status: status ?? this.status,
      targetText: targetText,
      voiceProfile: voiceProfile,
      reason: reason,
      retryCount: retryCount ?? this.retryCount,
      maxRetries: maxRetries,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      lastErrorCode: lastErrorCode ?? this.lastErrorCode,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, sentenceId, status];
}

/// 用户偏好（单记录）。
class UserPreference extends Equatable {
  const UserPreference({
    this.voiceProfile = VoiceProfile.gentleNatural,
    this.playbackSpeed = PlaybackSpeed.x085,
    this.notificationsEnabled = true,
    this.dailyReminderTime,
    this.updatedAt,
  });

  final VoiceProfile voiceProfile;
  final PlaybackSpeed playbackSpeed;
  final bool notificationsEnabled;
  final DateTime? dailyReminderTime;
  final DateTime? updatedAt;

  UserPreference copyWith({
    VoiceProfile? voiceProfile,
    PlaybackSpeed? playbackSpeed,
    bool? notificationsEnabled,
    DateTime? dailyReminderTime,
    DateTime? updatedAt,
  }) {
    return UserPreference(
      voiceProfile: voiceProfile ?? this.voiceProfile,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      dailyReminderTime: dailyReminderTime ?? this.dailyReminderTime,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [voiceProfile, playbackSpeed, notificationsEnabled];
}

/// 精灵伴侣。
class Companion extends Equatable {
  const Companion({
    required this.id,
    required this.name,
    this.decorationStage = DecorationStage.none,
    this.totalSessions = 0,
    this.createdAt,
  });

  final String id;
  final String name;
  final DecorationStage decorationStage;
  final int totalSessions;
  final DateTime? createdAt;

  @override
  List<Object?> get props => [id, name, decorationStage];
}

/// 学习事件（追加式日志）。
class LearningEvent extends Equatable {
  const LearningEvent({
    required this.id,
    required this.type,
    this.sentenceId,
    this.metadata = const {},
    this.createdAt,
  });

  final String id;
  final LearningEventType type;
  final String? sentenceId;
  final Map<String, Object?> metadata;
  final DateTime? createdAt;

  @override
  List<Object?> get props => [id, type, sentenceId];
}

/// 后端 bootstrap 配置。
class BootstrapConfig extends Equatable {
  const BootstrapConfig({
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

  @override
  List<Object?> get props => [sourceLanguages, targetLanguages, defaultVoiceProfile];
}

class VoiceProfileConfig extends Equatable {
  const VoiceProfileConfig({
    required this.id,
    required this.label,
    required this.description,
  });

  final String id;
  final String label;
  final String description;

  @override
  List<Object?> get props => [id, label];
}

/// 翻译生成结果。
class GeneratedSentenceResult extends Equatable {
  const GeneratedSentenceResult({
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
  final SentenceCategory category;
  final List<DeconstructionItem> deconstruction;
  final List<VocabCandidate> vocabCandidates;

  @override
  List<Object?> get props => [sentenceId, zhText, enText];
}

/// 音频生成结果。
class GeneratedAudioResult extends Equatable {
  const GeneratedAudioResult({
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

  final AudioGenerationStatus status;
  final VoiceProfile voiceProfile;
  final String? manifestId;
  final String? downloadUrl;
  final String? storagePath;
  final String? sha256;
  final int byteSize;
  final int durationMs;
  final bool cacheHit;
  final String? errorCode;

  bool get isReady => status == AudioGenerationStatus.ready && downloadUrl != null;

  @override
  List<Object?> get props => [status, voiceProfile, manifestId];
}
