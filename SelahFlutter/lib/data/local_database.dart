import 'dart:io';
import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../domain/entities.dart';
import '../domain/selah_enums.dart';

/// Selah 本地 SQLite（SwiftData V3 等价映射）。
/// Schema V1 → V2（加 PersistenceMetadata）→ V3（加 CaptureDraft 相关，本轮以核心表为准）。
class SelahLocalDatabase {
  SelahLocalDatabase._(this._db);

  final Database _db;

  static const int schemaVersion = 3;

  /// 打开本地数据库。`inMemory` 用于测试；桌面环境使用 FFI。
  static Future<SelahLocalDatabase> open({
    String? overridePath,
    bool inMemory = false,
  }) async {
    if (kIsDesktopTest) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = inMemory
        ? ':memory:'
        : overridePath ??
            p.join(
              (await getDatabasesPath()),
              'selah.db',
            );

    final db = await openDatabase(
      dbPath,
      version: schemaVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _createV3,
      onUpgrade: _upgrade,
    );
    return SelahLocalDatabase._(db);
  }

  static Future<void> _createV3(Database db, int version) async {
    await _createV1(db);
    await db.execute('''
      CREATE TABLE persistence_metadata (
        id TEXT PRIMARY KEY,
        schema_version INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE capture_drafts (
        id TEXT PRIMARY KEY,
        raw_transcript TEXT NOT NULL,
        status TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    await _seedDefaults(db);
  }

  static Future<void> _createV1(Database db) async {
    await db.execute('''
      CREATE TABLE sentences (
        id TEXT PRIMARY KEY,
        zh_text TEXT NOT NULL,
        en_text TEXT NOT NULL,
        category TEXT NOT NULL,
        difficulty TEXT NOT NULL,
        origin TEXT NOT NULL,
        deconstruction TEXT NOT NULL DEFAULT '[]',
        vocab_candidates TEXT NOT NULL DEFAULT '[]',
        review_state TEXT NOT NULL DEFAULT 'new',
        created_at INTEGER,
        updated_at INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE vocab_items (
        id TEXT PRIMARY KEY,
        sentence_id TEXT NOT NULL,
        surface_text TEXT NOT NULL,
        meaning TEXT NOT NULL,
        help_state TEXT NOT NULL DEFAULT 'new'
      )
    ''');
    await db.execute('''
      CREATE TABLE audio_assets (
        id TEXT PRIMARY KEY,
        sentence_id TEXT NOT NULL,
        voice_profile TEXT NOT NULL,
        status TEXT NOT NULL,
        local_path TEXT,
        remote_path TEXT,
        sha256 TEXT,
        byte_size INTEGER NOT NULL DEFAULT 0,
        duration_ms INTEGER NOT NULL DEFAULT 0,
        speed REAL NOT NULL DEFAULT 0.85,
        error_code TEXT,
        created_at INTEGER,
        downloaded_at INTEGER,
        last_played_at INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE generation_jobs (
        id TEXT PRIMARY KEY,
        sentence_id TEXT NOT NULL,
        type TEXT NOT NULL,
        status TEXT NOT NULL,
        target_text TEXT,
        voice_profile TEXT,
        reason TEXT,
        retry_count INTEGER NOT NULL DEFAULT 0,
        max_retries INTEGER NOT NULL DEFAULT 3,
        next_retry_at INTEGER,
        last_error_code TEXT,
        created_at INTEGER,
        updated_at INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE companions (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        decoration_stage TEXT NOT NULL DEFAULT 'none',
        total_sessions INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE learning_events (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        sentence_id TEXT,
        metadata TEXT NOT NULL DEFAULT '{}',
        created_at INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE preferences (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        voice_profile TEXT NOT NULL DEFAULT 'gentle-natural',
        playback_speed REAL NOT NULL DEFAULT 0.85,
        notifications_enabled INTEGER NOT NULL DEFAULT 1,
        daily_reminder_time INTEGER,
        updated_at INTEGER
      )
    ''');
  }

  static Future<void> _upgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE persistence_metadata (
          id TEXT PRIMARY KEY,
          schema_version INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE capture_drafts (
          id TEXT PRIMARY KEY,
          raw_transcript TEXT NOT NULL,
          status TEXT NOT NULL,
          created_at INTEGER NOT NULL
        )
      ''');
    }
    await _seedDefaults(db);
  }

  static Future<void> _seedDefaults(Database db) async {
    await db.insert('preferences', {
      'id': 1,
      'voice_profile': 'gentle-natural',
      'playback_speed': 0.85,
      'notifications_enabled': 1,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  // ------- Sentence -------

  Future<void> insertSentence(Sentence s) async {
    await _db.insert('sentences', _sentenceRow(s),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Sentence?> fetchSentence(String id) async {
    final rows = await _db.query('sentences', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return _sentenceFromRow(rows.first);
  }

  Future<List<Sentence>> fetchAllSentences({String? category}) async {
    final rows = category == null
        ? await _db.query('sentences', orderBy: 'created_at DESC')
        : await _db.query('sentences',
            where: 'category = ?', whereArgs: [category], orderBy: 'created_at DESC');
    return rows.map(_sentenceFromRow).toList();
  }

  Future<int> sentenceCount() async {
    final rows = await _db.rawQuery('SELECT COUNT(*) AS c FROM sentences');
    return (rows.first['c'] as int?) ?? 0;
  }

  Future<void> deleteSentence(String id) async {
    await _db.transaction((txn) async {
      await txn.delete('sentences', where: 'id = ?', whereArgs: [id]);
      await txn.delete('vocab_items', where: 'sentence_id = ?', whereArgs: [id]);
      await txn.delete('audio_assets', where: 'sentence_id = ?', whereArgs: [id]);
      await txn.delete('generation_jobs', where: 'sentence_id = ?', whereArgs: [id]);
    });
  }

  // ------- Vocab -------

  Future<void> insertVocabItem(VocabItem v) async {
    await _db.insert('vocab_items', {
      'id': v.id,
      'sentence_id': v.sentenceId,
      'surface_text': v.surfaceText,
      'meaning': v.meaning,
      'help_state': v.helpState.apiValue,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<VocabItem>> fetchVocabForSentence(String sentenceId) async {
    final rows = await _db.query('vocab_items',
        where: 'sentence_id = ?', whereArgs: [sentenceId], orderBy: 'surface_text');
    return rows.map(_vocabFromRow).toList();
  }

  // ------- Audio -------

  Future<void> insertAudioAsset(AudioAsset a) async {
    await _db.insert('audio_assets', {
      'id': a.id,
      'sentence_id': a.sentenceId,
      'voice_profile': a.voiceProfile.apiValue,
      'status': a.status.apiValue,
      'local_path': a.localPath,
      'remote_path': a.remotePath,
      'sha256': a.sha256,
      'byte_size': a.byteSize,
      'duration_ms': a.durationMs,
      'speed': a.speed,
      'error_code': a.errorCode,
      'created_at': a.createdAt?.millisecondsSinceEpoch,
      'downloaded_at': a.downloadedAt?.millisecondsSinceEpoch,
      'last_played_at': a.lastPlayedAt?.millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<AudioAsset>> fetchAudioForSentence(String sentenceId) async {
    final rows = await _db.query('audio_assets',
        where: 'sentence_id = ?', whereArgs: [sentenceId], orderBy: 'created_at DESC');
    return rows.map(_audioFromRow).toList();
  }

  // ------- Jobs -------

  Future<void> insertJob(GenerationJob j) async {
    await _db.insert('generation_jobs', {
      'id': j.id,
      'sentence_id': j.sentenceId,
      'type': j.type.apiValue,
      'status': j.status.apiValue,
      'target_text': j.targetText,
      'voice_profile': j.voiceProfile?.apiValue,
      'reason': j.reason?.apiValue,
      'retry_count': j.retryCount,
      'max_retries': j.maxRetries,
      'next_retry_at': j.nextRetryAt?.millisecondsSinceEpoch,
      'last_error_code': j.lastErrorCode,
      'created_at': j.createdAt?.millisecondsSinceEpoch,
      'updated_at': j.updatedAt?.millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<GenerationJob>> fetchPendingJobs({required DateTime now}) async {
    final rows = await _db.query(
      'generation_jobs',
      where: 'status IN (?, ?) AND (next_retry_at IS NULL OR next_retry_at <= ?)',
      whereArgs: [
        GenerationJobStatus.queued.apiValue,
        GenerationJobStatus.inProgress.apiValue,
        now.millisecondsSinceEpoch,
      ],
      orderBy: 'created_at ASC',
    );
    return rows.map(_jobFromRow).toList();
  }

  // ------- Companion / Preference / Events -------

  Future<void> insertCompanion(Companion c) async {
    await _db.insert('companions', {
      'id': c.id,
      'name': c.name,
      'decoration_stage': c.decorationStage.apiValue,
      'total_sessions': c.totalSessions,
      'created_at': c.createdAt?.millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Companion?> fetchCompanion() async {
    final rows = await _db.query('companions', limit: 1);
    if (rows.isEmpty) return null;
    return _companionFromRow(rows.first);
  }

  Future<UserPreference> fetchPreference() async {
    final rows = await _db.query('preferences', where: 'id = 1', limit: 1);
    if (rows.isEmpty) return const UserPreference();
    return _preferenceFromRow(rows.first);
  }

  Future<void> insertPreference(UserPreference p) async {
    await _db.insert('preferences', {
      'id': 1,
      'voice_profile': p.voiceProfile.apiValue,
      'playback_speed': p.playbackSpeed.value,
      'notifications_enabled': p.notificationsEnabled ? 1 : 0,
      'daily_reminder_time': p.dailyReminderTime?.millisecondsSinceEpoch,
      'updated_at': p.updatedAt?.millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertEvent(LearningEvent e) async {
    await _db.insert('learning_events', {
      'id': e.id,
      'type': e.type.apiValue,
      'sentence_id': e.sentenceId,
      'metadata': _jsonEncode(e.metadata),
      'created_at': e.createdAt?.millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<LearningEvent>> fetchRecentEvents({int limit = 50, String? type}) async {
    final rows = type == null
        ? await _db.query('learning_events', orderBy: 'created_at DESC', limit: limit)
        : await _db.query('learning_events',
            where: 'type = ?', whereArgs: [type], orderBy: 'created_at DESC', limit: limit);
    return rows.map(_eventFromRow).toList();
  }

  Future<void> close() async => _db.close();

  // ------- Row mappers -------

  Map<String, Object?> _sentenceRow(Sentence s) => {
        'id': s.id,
        'zh_text': s.zhText,
        'en_text': s.enText,
        'category': s.category.apiValue,
        'difficulty': s.difficulty,
        'origin': s.origin.apiValue,
        'deconstruction': _jsonEncode(
          s.deconstruction.map((d) => {
            'surfaceText': d.surfaceText,
            'meaning': d.meaning,
            'type': d.type,
          }).toList(),
        ),
        'vocab_candidates': _jsonEncode(
          s.vocabCandidates.map((v) => {
            'surfaceText': v.surfaceText,
            'meaningInContext': v.meaningInContext,
            'suggestedHelpState': v.helpState.apiValue,
          }).toList(),
        ),
        'review_state': s.reviewState.apiValue,
        'created_at': s.createdAt?.millisecondsSinceEpoch,
        'updated_at': s.updatedAt?.millisecondsSinceEpoch,
      };

  Sentence _sentenceFromRow(Map<String, Object?> row) {
    final category = SentenceCategory.fromApi(row['category'] as String?);
    return Sentence(
      id: row['id'] as String,
      zhText: row['zh_text'] as String? ?? '',
      enText: row['en_text'] as String? ?? '',
      category: category ?? SentenceCategory.life,
      difficulty: row['difficulty'] as String? ?? 'intermediate',
      origin: _enumByName(SentenceOrigin.values, row['origin'] as String?) ??
          SentenceOrigin.manual,
      deconstruction: _jsonDecodeList(row['deconstruction'] as String? ?? '[]')
          .map((d) => DeconstructionItem(
                surfaceText: d['surfaceText'] as String? ?? '',
                meaning: d['meaning'] as String? ?? '',
                type: d['type'] as String? ?? 'phrase',
              ))
          .toList(),
      vocabCandidates: _jsonDecodeList(row['vocab_candidates'] as String? ?? '[]')
          .map((v) => VocabCandidate(
                surfaceText: v['surfaceText'] as String? ?? '',
                meaningInContext: v['meaningInContext'] as String? ?? '',
                helpState: _enumByName(VocabHelpState.values, v['suggestedHelpState'] as String?) ??
                    VocabHelpState.new_,
              ))
          .toList(),
      reviewState: _enumByName(ReviewStateValue.values, row['review_state'] as String?) ??
          ReviewStateValue.new_,
      createdAt: _date(row['created_at']),
      updatedAt: _date(row['updated_at']),
    );
  }

  VocabItem _vocabFromRow(Map<String, Object?> row) => VocabItem(
        id: row['id'] as String,
        sentenceId: row['sentence_id'] as String? ?? '',
        surfaceText: row['surface_text'] as String? ?? '',
        meaning: row['meaning'] as String? ?? '',
        helpState: _enumByName(VocabHelpState.values, row['help_state'] as String?) ??
            VocabHelpState.new_,
      );

  AudioAsset _audioFromRow(Map<String, Object?> row) {
    return AudioAsset(
      id: row['id'] as String,
      sentenceId: row['sentence_id'] as String? ?? '',
      voiceProfile: _enumByName(VoiceProfile.values, row['voice_profile'] as String?) ??
          VoiceProfile.gentleNatural,
      status: _enumByName(AudioGenerationStatus.values, row['status'] as String?) ??
          AudioGenerationStatus.failed,
      localPath: row['local_path'] as String?,
      remotePath: row['remote_path'] as String?,
      sha256: row['sha256'] as String?,
      byteSize: (row['byte_size'] as num?)?.toInt() ?? 0,
      durationMs: (row['duration_ms'] as num?)?.toInt() ?? 0,
      speed: (row['speed'] as num?)?.toDouble() ?? 0.85,
      errorCode: row['error_code'] as String?,
      createdAt: _date(row['created_at']),
      downloadedAt: _date(row['downloaded_at']),
      lastPlayedAt: _date(row['last_played_at']),
    );
  }

  GenerationJob _jobFromRow(Map<String, Object?> row) {
    return GenerationJob(
      id: row['id'] as String,
      sentenceId: row['sentence_id'] as String? ?? '',
      type: _enumByName(GenerationJobType.values, row['type'] as String?) ??
          GenerationJobType.audioGeneration,
      status: _enumByName(GenerationJobStatus.values, row['status'] as String?) ??
          GenerationJobStatus.failed,
      targetText: row['target_text'] as String?,
      voiceProfile: _enumByName(VoiceProfile.values, row['voice_profile'] as String?),
      reason: _enumByName(AudioGenerationReason.values, row['reason'] as String?),
      retryCount: (row['retry_count'] as num?)?.toInt() ?? 0,
      maxRetries: (row['max_retries'] as num?)?.toInt() ?? 3,
      nextRetryAt: _date(row['next_retry_at']),
      lastErrorCode: row['last_error_code'] as String?,
      createdAt: _date(row['created_at']),
      updatedAt: _date(row['updated_at']),
    );
  }

  Companion _companionFromRow(Map<String, Object?> row) => Companion(
        id: row['id'] as String,
        name: row['name'] as String? ?? 'Selah',
        decorationStage: _enumByName(DecorationStage.values, row['decoration_stage'] as String?) ??
            DecorationStage.none,
        totalSessions: (row['total_sessions'] as num?)?.toInt() ?? 0,
        createdAt: _date(row['created_at']),
      );

  UserPreference _preferenceFromRow(Map<String, Object?> row) {
    return UserPreference(
      voiceProfile: _enumByName(VoiceProfile.values, row['voice_profile'] as String?) ??
          VoiceProfile.gentleNatural,
      playbackSpeed: _playbackSpeed((row['playback_speed'] as num?)?.toDouble() ?? 0.85),
      notificationsEnabled: (row['notifications_enabled'] as int?) != 0,
      dailyReminderTime: _date(row['daily_reminder_time']),
      updatedAt: _date(row['updated_at']),
    );
  }

  LearningEvent _eventFromRow(Map<String, Object?> row) => LearningEvent(
        id: row['id'] as String,
        type: _enumByName(LearningEventType.values, row['type'] as String?) ??
            LearningEventType.sentenceCreated,
        sentenceId: row['sentence_id'] as String?,
        metadata: _jsonDecodeMap(row['metadata'] as String? ?? '{}'),
        createdAt: _date(row['created_at']),
      );

  PlaybackSpeed _playbackSpeed(double value) {
    for (final s in PlaybackSpeed.values) {
      if (s.value == value) return s;
    }
    return PlaybackSpeed.x085;
  }

  static String _jsonEncode(Object value) => jsonEncode(value);
}

List<Map<String, Object?>> _jsonDecodeList(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is List) {
    return decoded
        .whereType<Map>()
        .map((e) => Map<String, Object?>.from(e))
        .toList();
  }
  return const [];
}

Map<String, Object?> _jsonDecodeMap(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is Map) return Map<String, Object?>.from(decoded);
  return const {};
}

T? _enumByName<T>(List<T> values, String? name) {
  if (name == null) return null;
  for (final v in values) {
    final dynamic d = v;
    final apiValue = d.apiValue;
    if (apiValue == name) return v;
  }
  return null;
}

DateTime? _date(Object? value) {
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  return null;
}

bool get kIsDesktopTest => !Platform.isAndroid && !Platform.isIOS;
