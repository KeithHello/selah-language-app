import 'entities.dart';
import 'selah_enums.dart';

/// 句子仓库。
abstract interface class SentenceRepository {
  Future<void> save(Sentence sentence);
  Future<Sentence?> fetchById(String id);
  Future<List<Sentence>> fetchAll({SentenceCategory? category});
  Future<List<Sentence>> fetchDueForPractice({int limit = 10});
  Future<List<Sentence>> fetchSuitableForListen({int limit = 10});
  Future<int> count();
  Future<void> delete(String id);
}

/// 词汇仓库。
abstract interface class VocabRepository {
  Future<void> save(VocabItem item);
  Future<List<VocabItem>> fetchAllForSentence(String sentenceId);
  Future<List<VocabItem>> fetchActiveHelp();
}

/// 音频资产仓库。
abstract interface class AudioAssetRepository {
  Future<void> save(AudioAsset asset);
  Future<AudioAsset?> fetchById(String id);
  Future<List<AudioAsset>> fetchAllForSentence(String sentenceId);
  Future<List<AudioAsset>> fetchByStatus(AudioGenerationStatus status);
  Future<void> delete(String id);
}

/// 生成任务仓库（离线重试）。
abstract interface class GenerationJobRepository {
  Future<void> save(GenerationJob job);
  Future<GenerationJob?> fetchById(String id);
  Future<List<GenerationJob>> fetchPending({required bool retryable, required DateTime now});
  Future<void> delete(String id);
}

/// 偏好仓库（单记录）。
abstract interface class PreferenceRepository {
  Future<UserPreference> get();
  Future<void> save(UserPreference preference);
}

/// 精灵伴侣仓库。
abstract interface class CompanionRepository {
  Future<void> save(Companion companion);
  Future<Companion?> fetch();
}

/// 学习事件仓库。
abstract interface class LearningEventRepository {
  Future<void> save(LearningEvent event);
  Future<List<LearningEvent>> fetchRecent({int limit = 50});
  Future<List<LearningEvent>> fetchRecentByType(LearningEventType type, {int limit = 50});
}

/// 远端 API 客户端抽象（只访问现有 Edge Functions）。
abstract interface class SelahApiClient {
  Future<BootstrapConfig> fetchBootstrap();

  Future<GeneratedSentenceResult> generateSentence({
    required String sourceText,
    required SourceLanguage sourceLanguage,
    required TargetLanguage targetLanguage,
    SentenceCategory? categoryHint,
  });

  Future<GeneratedAudioResult> generateAudio({
    required String sentenceId,
    required String targetText,
    required VoiceProfile voiceProfile,
    required AudioGenerationReason reason,
  });

  Future<String?> audioDownloadUrl({
    required String sentenceId,
    required VoiceProfile voiceProfile,
  });
}
