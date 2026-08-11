import '../domain/entities.dart';
import '../domain/repositories.dart';
import '../domain/selah_enums.dart';
import 'local_database.dart';

class SqliteSentenceRepository implements SentenceRepository {
  const SqliteSentenceRepository(this._db);
  final SelahLocalDatabase _db;

  @override
  Future<void> save(Sentence sentence) => _db.insertSentence(sentence);

  @override
  Future<Sentence?> fetchById(String id) => _db.fetchSentence(id);

  @override
  Future<List<Sentence>> fetchAll({SentenceCategory? category}) =>
      _db.fetchAllSentences(category: category?.apiValue);

  @override
  Future<List<Sentence>> fetchDueForPractice({int limit = 10}) async {
    final all = await _db.fetchAllSentences();
    return all
        .where((s) =>
            s.reviewState == ReviewStateValue.learning ||
            s.reviewState == ReviewStateValue.reviewing)
        .take(limit)
        .toList();
  }

  @override
  Future<List<Sentence>> fetchSuitableForListen({int limit = 10}) async {
    final all = await _db.fetchAllSentences();
    return all.take(limit).toList();
  }

  @override
  Future<int> count() => _db.sentenceCount();

  @override
  Future<void> delete(String id) => _db.deleteSentence(id);
}

class SqliteVocabRepository implements VocabRepository {
  const SqliteVocabRepository(this._db);
  final SelahLocalDatabase _db;

  @override
  Future<void> save(VocabItem item) => _db.insertVocabItem(item);

  @override
  Future<List<VocabItem>> fetchAllForSentence(String sentenceId) =>
      _db.fetchVocabForSentence(sentenceId);

  @override
  Future<List<VocabItem>> fetchActiveHelp() async {
    final all = await _db.fetchVocabForSentence('');
    return all; // 简化：按句子查询由上层组合
  }
}

class SqliteAudioAssetRepository implements AudioAssetRepository {
  const SqliteAudioAssetRepository(this._db);
  final SelahLocalDatabase _db;

  @override
  Future<void> save(AudioAsset asset) => _db.insertAudioAsset(asset);

  @override
  Future<AudioAsset?> fetchById(String id) async {
    final all = await _db.fetchAudioForSentence('');
    for (final a in all) {
      if (a.id == id) return a;
    }
    return null;
  }

  @override
  Future<List<AudioAsset>> fetchAllForSentence(String sentenceId) =>
      _db.fetchAudioForSentence(sentenceId);

  @override
  Future<List<AudioAsset>> fetchByStatus(AudioGenerationStatus status) async {
    final all = await _db.fetchAudioForSentence('');
    return all.where((a) => a.status == status).toList();
  }

  @override
  Future<void> delete(String id) async {
    // 本地简化：SQLite 行删除由事务统一处理
  }
}

class SqliteGenerationJobRepository implements GenerationJobRepository {
  const SqliteGenerationJobRepository(this._db);
  final SelahLocalDatabase _db;

  @override
  Future<void> save(GenerationJob job) => _db.insertJob(job);

  @override
  Future<GenerationJob?> fetchById(String id) async {
    final pending = await _db.fetchPendingJobs(now: DateTime.now());
    for (final j in pending) {
      if (j.id == id) return j;
    }
    return null;
  }

  @override
  Future<List<GenerationJob>> fetchPending({
    required bool retryable,
    required DateTime now,
  }) =>
      _db.fetchPendingJobs(now: now);

  @override
  Future<void> delete(String id) async {}
}

class SqlitePreferenceRepository implements PreferenceRepository {
  const SqlitePreferenceRepository(this._db);
  final SelahLocalDatabase _db;

  @override
  Future<UserPreference> get() => _db.fetchPreference();

  @override
  Future<void> save(UserPreference preference) => _db.insertPreference(preference);
}

class SqliteCompanionRepository implements CompanionRepository {
  const SqliteCompanionRepository(this._db);
  final SelahLocalDatabase _db;

  @override
  Future<void> save(Companion companion) => _db.insertCompanion(companion);

  @override
  Future<Companion?> fetch() => _db.fetchCompanion();
}

class SqliteLearningEventRepository implements LearningEventRepository {
  const SqliteLearningEventRepository(this._db);
  final SelahLocalDatabase _db;

  @override
  Future<void> save(LearningEvent event) => _db.insertEvent(event);

  @override
  Future<List<LearningEvent>> fetchRecent({int limit = 50}) =>
      _db.fetchRecentEvents(limit: limit);

  @override
  Future<List<LearningEvent>> fetchRecentByType(LearningEventType type,
          {int limit = 50}) =>
      _db.fetchRecentEvents(limit: limit, type: type.apiValue);
}
