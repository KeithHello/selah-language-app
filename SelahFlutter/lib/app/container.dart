import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/fixture_gateway.dart';
import '../data/local_database.dart';
import '../data/repository_impl.dart';
import '../domain/repositories.dart';
import '../domain/use_cases.dart';

/// 应用运行配置。
class SelahRuntimeConfig {
  const SelahRuntimeConfig({
    this.supabaseUrl,
    this.supabaseAnonKey,
    this.useFixture = true,
    this.petName = 'Selah',
  });

  final String? supabaseUrl;
  final String? supabaseAnonKey;
  final bool useFixture;
  final String petName;
}

/// 提供数据库实例（默认内存模式，便于测试与首版预览）。
final localDatabaseProvider = Provider<SelahLocalDatabase>((ref) {
  throw UnimplementedError('必须在 ProviderScope overrides 中注入');
});

final apiClientProvider = Provider<SelahApiClient>((ref) {
  return FixtureSelahApiClient();
});

final sentenceRepositoryProvider = Provider<SentenceRepository>((ref) {
  return SqliteSentenceRepository(ref.watch(localDatabaseProvider));
});

final vocabRepositoryProvider = Provider<VocabRepository>((ref) {
  return SqliteVocabRepository(ref.watch(localDatabaseProvider));
});

final audioAssetRepositoryProvider = Provider<AudioAssetRepository>((ref) {
  return SqliteAudioAssetRepository(ref.watch(localDatabaseProvider));
});

final generationJobRepositoryProvider = Provider<GenerationJobRepository>((ref) {
  return SqliteGenerationJobRepository(ref.watch(localDatabaseProvider));
});

final preferenceRepositoryProvider = Provider<PreferenceRepository>((ref) {
  return SqlitePreferenceRepository(ref.watch(localDatabaseProvider));
});

final companionRepositoryProvider = Provider<CompanionRepository>((ref) {
  return SqliteCompanionRepository(ref.watch(localDatabaseProvider));
});

final learningEventRepositoryProvider = Provider<LearningEventRepository>((ref) {
  return SqliteLearningEventRepository(ref.watch(localDatabaseProvider));
});

final generateSentenceUseCaseProvider = Provider<GenerateSentenceUseCase>((ref) {
  return GenerateSentenceUseCase(
    api: ref.watch(apiClientProvider),
    sentences: ref.watch(sentenceRepositoryProvider),
    vocab: ref.watch(vocabRepositoryProvider),
    events: ref.watch(learningEventRepositoryProvider),
  );
});

final generateAudioUseCaseProvider = Provider<GenerateAudioUseCase>((ref) {
  return GenerateAudioUseCase(
    api: ref.watch(apiClientProvider),
    assets: ref.watch(audioAssetRepositoryProvider),
    jobs: ref.watch(generationJobRepositoryProvider),
  );
});

final listenUseCaseProvider = Provider<ListenUseCase>((ref) {
  return ListenUseCase(
    api: ref.watch(apiClientProvider),
    assets: ref.watch(audioAssetRepositoryProvider),
    events: ref.watch(learningEventRepositoryProvider),
    downloader: (id, url, sha) async {
      // 首版 Fixture：URL 即内容指纹，模拟成功下载。
    },
  );
});

final runtimeConfigProvider = Provider<SelahRuntimeConfig>((ref) {
  return const SelahRuntimeConfig();
});
