import 'dart:async';

import 'entities.dart';
import 'repositories.dart';
import 'selah_enums.dart';

/// 统一 API 错误（用户可见文案安全）。
class SelahApiException implements Exception {
  const SelahApiException({
    required this.code,
    required this.userMessage,
    this.statusCode,
  });

  final String code;
  final String userMessage;
  final int? statusCode;

  @override
  String toString() => 'SelahApiException($code, $statusCode)';
}

/// 生成并保存句子的用例（核心闭环第一步）。
class GenerateSentenceUseCase {
  const GenerateSentenceUseCase({
    required this.api,
    required this.sentences,
    required this.vocab,
    required this.events,
  });

  final SelahApiClient api;
  final SentenceRepository sentences;
  final VocabRepository vocab;
  final LearningEventRepository events;

  Future<Sentence> execute({
    required String sourceText,
    SentenceCategory? categoryHint,
  }) async {
    final result = await api.generateSentence(
      sourceText: sourceText,
      sourceLanguage: SourceLanguage.zhHant,
      targetLanguage: TargetLanguage.en,
      categoryHint: categoryHint,
    );

    final now = DateTime.now();
    final sentence = Sentence(
      id: result.sentenceId,
      zhText: result.zhText,
      enText: result.enText,
      category: result.category,
      difficulty: 'intermediate',
      origin: SentenceOrigin.manual,
      deconstruction: result.deconstruction,
      vocabCandidates: result.vocabCandidates,
      createdAt: now,
      updatedAt: now,
    );
    await sentences.save(sentence);

    for (final v in result.vocabCandidates) {
      await vocab.save(
        VocabItem(
          id: '${result.sentenceId}-${v.surfaceText.hashCode.abs()}',
          sentenceId: result.sentenceId,
          surfaceText: v.surfaceText,
          meaning: v.meaningInContext,
          helpState: v.helpState,
        ),
      );
    }

    await events.save(
      LearningEvent(
        id: 'evt-${now.microsecondsSinceEpoch}',
        type: LearningEventType.sentenceCreated,
        sentenceId: result.sentenceId,
        metadata: const {'origin': 'manual'},
        createdAt: now,
      ),
    );

    return sentence;
  }
}

/// 生成或复用音频的用例。
class GenerateAudioUseCase {
  const GenerateAudioUseCase({
    required this.api,
    required this.assets,
    required this.jobs,
  });

  final SelahApiClient api;
  final AudioAssetRepository assets;
  final GenerationJobRepository jobs;

  Future<AudioAsset> execute({
    required Sentence sentence,
    required VoiceProfile voiceProfile,
    AudioGenerationReason reason = AudioGenerationReason.initial,
  }) async {
    final result = await api.generateAudio(
      sentenceId: sentence.id,
      targetText: sentence.enText,
      voiceProfile: voiceProfile,
      reason: reason,
    );

    final now = DateTime.now();
    final asset = AudioAsset(
      id: 'audio-${sentence.id}-${voiceProfile.apiValue}',
      sentenceId: sentence.id,
      voiceProfile: voiceProfile,
      status: result.status,
      remotePath: result.storagePath,
      sha256: result.sha256,
      byteSize: result.byteSize,
      durationMs: result.durationMs,
      speed: 0.85,
      createdAt: now,
      downloadedAt: result.isReady ? now : null,
    );
    await assets.save(asset);

    if (result.status == AudioGenerationStatus.failed) {
      await jobs.save(
        GenerationJob(
          id: 'job-${sentence.id}-${now.microsecondsSinceEpoch}',
          sentenceId: sentence.id,
          type: GenerationJobType.audioGeneration,
          status: GenerationJobStatus.queued,
          targetText: sentence.enText,
          voiceProfile: voiceProfile,
          reason: reason,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    return asset;
  }
}

/// 生成并下载音频，随后播放（Listen 用例）。
class ListenUseCase {
  const ListenUseCase({
    required this.api,
    required this.assets,
    required this.events,
    required this.downloader,
  });

  final SelahApiClient api;
  final AudioAssetRepository assets;
  final LearningEventRepository events;
  final Future<void> Function(String id, String url, String? expectedSha256) downloader;

  Future<AudioAsset> execute({
    required Sentence sentence,
    required VoiceProfile voiceProfile,
  }) async {
    // 1. 先查本地是否已有 ready 资产。
    final existing = await assets.fetchAllForSentence(sentence.id);
    final ready = existing.where((a) => a.status == AudioGenerationStatus.ready).toList();
    if (ready.isNotEmpty) {
      await events.save(
        LearningEvent(
          id: 'evt-${DateTime.now().microsecondsSinceEpoch}',
          type: LearningEventType.listenCompleted,
          sentenceId: sentence.id,
          createdAt: DateTime.now(),
        ),
      );
      return ready.first;
    }

    // 2. 未就绪则请求生成。
    final result = await api.generateAudio(
      sentenceId: sentence.id,
      targetText: sentence.enText,
      voiceProfile: voiceProfile,
      reason: AudioGenerationReason.initial,
    );
    if (!result.isReady || result.downloadUrl == null) {
      throw SelahApiException(
        code: 'audio_not_ready',
        userMessage: '語音還沒準備好，稍後再試。',
      );
    }

    // 3. 下载并校验。
    final now = DateTime.now();
    final asset = AudioAsset(
      id: 'audio-${sentence.id}-${voiceProfile.apiValue}',
      sentenceId: sentence.id,
      voiceProfile: voiceProfile,
      status: AudioGenerationStatus.generating,
      remotePath: result.storagePath,
      sha256: result.sha256,
      byteSize: result.byteSize,
      durationMs: result.durationMs,
      createdAt: now,
    );
    await assets.save(asset);
    await downloader(asset.id, result.downloadUrl!, result.sha256);
    final readyAsset = asset.copyWith(
      status: AudioGenerationStatus.ready,
      downloadedAt: now,
    );
    await assets.save(readyAsset);

    await events.save(
      LearningEvent(
        id: 'evt-${now.microsecondsSinceEpoch}',
        type: LearningEventType.listenCompleted,
        sentenceId: sentence.id,
        createdAt: now,
      ),
    );
    return readyAsset;
  }
}
