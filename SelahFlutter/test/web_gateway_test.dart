// The app receives `http` through Supabase; this test uses its existing
// client seam without adding a runtime dependency.
// ignore_for_file: depend_on_referenced_packages

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:selah/web/data/learning_gateway.dart';
import 'package:selah/web/data/supabase_learning_gateway.dart';
import 'package:selah/web/domain/learning_models.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class _CapturedRequest {
  _CapturedRequest(this.method, this.url, this.body);
  final String method;
  final Uri url;
  final Map<String, dynamic>? body;
}

class _SyncHttpClient extends http.BaseClient {
  _SyncHttpClient({
    required this.userId,
    required this.companionId,
    this.conflict = false,
    this.profileCompanionId,
    this.lockedMemory = false,
  }) : profile = {
         'id': userId,
         'active_companion_id': profileCompanionId ?? companionId,
         'voice_profile': 'gentle-natural',
         'playback_speed': .85,
         'onboarding_completed': false,
         'notification_enabled': false,
         'notification_time': '20:00',
         'updated_at': '2026-09-01T00:00:00+00:00',
       },
       companion = {
         'id': companionId,
         'user_id': userId,
         'display_name': '云端名字',
         'decoration_stage': 'none',
         'active': true,
         'updated_at': '2026-09-01T00:00:00+00:00',
       } {
    companionRows[companionId] = companion;
    if (lockedMemory) {
      memoryRows['first_name'] = {
        'id': newId(),
        'companion_id': companionId,
        'memory_key': 'first_name',
        'title': '第一次见面',
        'description_text': '你为一颗小种子取了名字。',
        'unlocked': false,
        'unlocked_at': null,
      };
    }
  }

  final String userId;
  final String companionId;
  final bool conflict;
  final String? profileCompanionId;
  final bool lockedMemory;
  final Map<String, dynamic> profile;
  final Map<String, dynamic> companion;
  final companionRows = <String, Map<String, dynamic>>{};
  final memoryRows = <String, Map<String, dynamic>>{};
  final requests = <_CapturedRequest>[];
  final events = [
    {
      'id': newId(),
      'event_type': 'preview_completed',
      'sentence_id': null,
      'metadata': <String, dynamic>{},
      'happened_at': '2026-09-01T01:00:00+00:00',
    },
  ];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final bytes = await request.finalize().toBytes();
    final body = bytes.isEmpty ? null : jsonDecode(utf8.decode(bytes));
    requests.add(
      _CapturedRequest(
        request.method,
        request.url,
        body is Map ? Map<String, dynamic>.from(body) : null,
      ),
    );
    final path = request.url.path;
    if (path.endsWith('/auth/v1/token')) {
      return _json(request, {
        'access_token': 'test-token',
        'refresh_token': 'test-refresh',
        'token_type': 'bearer',
        'expires_in': 3600,
        'user': {
          'id': userId,
          'aud': 'authenticated',
          'role': 'authenticated',
          'email': 'test@example.com',
          'app_metadata': <String, dynamic>{},
          'user_metadata': <String, dynamic>{},
          'created_at': '2026-09-01T00:00:00+00:00',
        },
      });
    }
    if (!path.contains('/rest/v1/')) {
      return _json(request, {'error': 'not found'}, 404);
    }
    final table = path.substring(
      path.indexOf('/rest/v1/') + '/rest/v1/'.length,
    );
    String? queryEq(String key) {
      final value = request.url.queryParameters[key];
      return value != null && value.startsWith('eq.')
          ? value.substring(3)
          : null;
    }

    if (request.method == 'GET') {
      final rows = switch (table) {
        'sentences' || 'vocab_items' => <Map<String, dynamic>>[],
        'sprite_memories' => memoryRows.values.where((row) {
          return queryEq('companion_id') == row['companion_id'] &&
              (queryEq('unlocked') == null ||
                  queryEq('unlocked') == row['unlocked'].toString());
        }).toList(),
        'learning_events' => events,
        'user_profiles' =>
          queryEq('id') == userId ? [profile] : <Map<String, dynamic>>[],
        'companions' =>
          queryEq('user_id') == userId
              ? (queryEq('id') == null
                    ? companionRows.values
                          .where((row) => row['active'] == true)
                          .toList()
                    : companionRows[queryEq('id')] == null
                    ? <Map<String, dynamic>>[]
                    : [companionRows[queryEq('id')]!])
              : <Map<String, dynamic>>[],
        _ => <Map<String, dynamic>>[],
      };
      final single = request.headers.values.any(
        (value) => value.contains('application/vnd.pgrst.object'),
      );
      return _json(request, single ? (rows.isEmpty ? null : rows.first) : rows);
    }
    if (request.method == 'PATCH' &&
        (table == 'companions' || table == 'user_profiles')) {
      final row = table == 'companions'
          ? companionRows[queryEq('id')]
          : profile;
      if (row == null) return _json(request, []);
      final expected = queryEq('updated_at');
      if (table == 'companions' && conflict) {
        row['updated_at'] = '2026-09-06T00:00:00+00:00';
        return _json(request, []);
      }
      if (expected != row['updated_at']) return _json(request, []);
      if (body is Map) row.addAll(Map<String, dynamic>.from(body));
      row['updated_at'] = '2026-09-05T00:00:00+00:00';
      return _json(request, [row]);
    }
    if (request.method == 'PATCH' && table == 'sprite_memories') {
      final row = memoryRows[queryEq('memory_key')];
      if (row == null || queryEq('companion_id') != row['companion_id']) {
        return _json(request, []);
      }
      final unlocked = request.url.queryParameters['unlocked'];
      if (unlocked != null && unlocked != 'eq.${row['unlocked']}') {
        return _json(request, []);
      }
      if (body is Map) row.addAll(Map<String, dynamic>.from(body));
      return _json(request, [row]);
    }
    if (request.method == 'POST') {
      if (table == 'companions' && body is List && body.isNotEmpty) {
        final row = Map<String, dynamic>.from(body.first as Map);
        row['updated_at'] = '2026-09-05T00:00:00+00:00';
        companionRows[row['id'] as String] = row;
        return _json(request, []);
      }
      if (table == 'sprite_memories' && body is List && body.isNotEmpty) {
        final row = Map<String, dynamic>.from(body.first as Map);
        memoryRows.putIfAbsent(row['memory_key'] as String, () => row);
        return _json(request, []);
      }
      return _json(request, []);
    }
    return _json(request, {'error': 'unsupported'}, 400);
  }

  http.StreamedResponse _json(
    http.BaseRequest request,
    Object? body, [
    int status = 200,
  ]) {
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(body))),
      status,
      headers: const {'content-type': 'application/json'},
      request: request,
    );
  }
}

void main() {
  test('recording MIME normalization accepts WAV aliases and parameters', () {
    expect(
      SupabaseLearningGateway.normalizeRecordingMime(' Audio/X-WAV; codecs=1 '),
      'audio/x-wav',
    );
    expect(SupabaseLearningGateway.recordingExtension('audio/x-wav'), 'wav');
    expect(
      () => SupabaseLearningGateway.normalizeRecordingMime('audio/flac'),
      throwsA(
        isA<LearningFailure>().having(
          (e) => e.code,
          'code',
          'unsupported_audio_format',
        ),
      ),
    );
  });

  test('recording duration rejects missing/zero/over-limit values', () {
    expect(SupabaseLearningGateway.validateRecordingDuration('1500'), 1500);
    expect(
      () => SupabaseLearningGateway.validateRecordingDuration(0),
      throwsA(
        isA<LearningFailure>().having(
          (e) => e.code,
          'code',
          'invalid_audio_duration',
        ),
      ),
    );
    expect(
      () => SupabaseLearningGateway.validateRecordingDuration(180001),
      throwsA(
        isA<LearningFailure>().having(
          (e) => e.code,
          'code',
          'audio_duration_too_long',
        ),
      ),
    );
  });

  test('profile companion pointer wins over fallback selection', () {
    expect(
      SupabaseLearningGateway.preferredCompanionId({
        'active_companion_id': 'preferred',
      }),
      'preferred',
    );
    expect(
      SupabaseLearningGateway.preferredCompanionId({
        'active_companion_id': null,
      }),
      isNull,
    );
  });

  test(
    'idempotent retry repeats transient operation but not deterministic failure',
    () async {
      var attempts = 0;
      final value = await SupabaseLearningGateway.retryIdempotent(
        () async {
          attempts++;
          if (attempts < 3) throw StateError('temporary');
          return 7;
        },
        attempts: 3,
        delay: Duration.zero,
      );
      expect(value, 7);
      expect(attempts, 3);

      attempts = 0;
      await expectLater(
        SupabaseLearningGateway.retryIdempotent<int>(
          () async {
            attempts++;
            throw const LearningFailure('conflict', code: 'sync_conflict');
          },
          attempts: 3,
          delay: Duration.zero,
        ),
        throwsA(
          isA<LearningFailure>().having((e) => e.code, 'code', 'sync_conflict'),
        ),
      );
      expect(attempts, 1);
    },
  );

  test(
    'transport failures map to stable network code without exposing details',
    () {
      final failure = SupabaseLearningGateway.functionFailure(
        0,
        'private network details',
      );
      expect(failure.code, 'network_unavailable');
      expect(failure.message, isNot(contains('private')));
    },
  );

  test('sentence sync preserves language and generation provenance', () {
    final id = newId();
    final sentence = LearnSentence(
      id: id,
      source: '駅はどこですか？',
      target: 'Where is the station?',
      sourceLanguage: 'ja',
      targetLanguage: 'en',
      generationModel: 'openai/gpt-4o-mini',
      promptVersion: 'v8.0',
      createdAt: DateTime.parse('2026-09-01T00:00:00Z'),
      updatedAt: DateTime.parse('2026-09-02T00:00:00Z'),
    );

    final payload = SupabaseLearningGateway.sentenceToCloud(sentence, newId());
    expect(payload['source_language'], 'ja');
    expect(payload['target_language'], 'en');
    expect(payload['generation_model'], 'openai/gpt-4o-mini');
    expect(payload['prompt_version'], 'v8.0');

    final restored = SupabaseLearningGateway.sentenceFromCloud({
      'id': id,
      'source_text': sentence.source,
      'target_text': sentence.target,
      'source_language': 'ja',
      'target_language': 'en',
      'generation_model': 'openai/gpt-4o-mini',
      'prompt_version': 'v8.0',
      'category': 'daily_life',
      'origin': 'user_recording',
      'deconstruction': <dynamic>[],
      'archived': false,
      'created_at': '2026-09-01T00:00:00Z',
      'updated_at': '2026-09-02T00:00:00Z',
      'review_state': 'new',
      'next_review_at': '2026-09-02T00:00:00Z',
      'interval_days': 1,
      'lapse_count': 0,
      'last_recall_signal': null,
      'listen_completed_at': null,
      'previewed_at': null,
    }, const []);
    expect(restored.sourceLanguage, 'ja');
    expect(restored.targetLanguage, 'en');
    expect(restored.generationModel, 'openai/gpt-4o-mini');
    expect(restored.promptVersion, 'v8.0');
  });

  test(
    'synchronize uses conditional writes and absorbs server timestamps',
    () async {
      final userId = newId();
      final companionId = newId();
      final httpClient = _SyncHttpClient(
        userId: userId,
        companionId: companionId,
      );
      final client = SupabaseClient(
        'https://sync.example.test',
        'anon',
        httpClient: httpClient,
      );
      final gateway = SupabaseLearningGateway(
        client,
        userIdProvider: () => userId,
      );
      final local = LearningSnapshot.empty()..accountScope = userId;
      local.preferences
        ..name = '本地名字'
        ..voice = 'clear-slow'
        ..updatedAt = DateTime.parse('2026-09-02T00:00:00Z');

      final result = await gateway.synchronize(local);
      expect(result.preferences.name, '本地名字');
      expect(result.preferences.voice, 'clear-slow');
      expect(
        result.preferences.updatedAt.toUtc(),
        DateTime.parse('2026-09-05T00:00:00Z'),
      );
      expect(result.events, hasLength(1));
      expect(httpClient.companion['display_name'], '本地名字');
      expect(httpClient.profile['voice_profile'], 'clear-slow');
      final patches = httpClient.requests.where(
        (request) => request.method == 'PATCH',
      );
      expect(patches, hasLength(2));
      for (final patch in patches) {
        expect(
          patch.url.queryParameters['updated_at'],
          startsWith('eq.2026-09-01'),
        );
        expect(patch.body?.containsKey('updated_at'), isFalse);
      }
      await client.dispose();
    },
  );

  test(
    'synchronize reports an optimistic conflict and leaves local data intact',
    () async {
      final userId = newId();
      final companionId = newId();
      final httpClient = _SyncHttpClient(
        userId: userId,
        companionId: companionId,
        conflict: true,
      );
      final client = SupabaseClient(
        'https://sync.example.test',
        'anon',
        httpClient: httpClient,
      );
      final gateway = SupabaseLearningGateway(
        client,
        userIdProvider: () => userId,
      );
      final local = LearningSnapshot.empty()..accountScope = userId;
      local.preferences
        ..name = '本地名字'
        ..updatedAt = DateTime.parse('2026-09-02T00:00:00Z');

      await expectLater(
        gateway.synchronize(local),
        throwsA(
          isA<LearningFailure>().having(
            (error) => error.code,
            'code',
            'sync_conflict',
          ),
        ),
      );
      expect(local.preferences.name, '本地名字');
      expect(local.lastSyncAt, isNull);
      await client.dispose();
    },
  );

  test(
    'synchronize repairs a missing pointed companion without selecting another active companion',
    () async {
      final userId = newId();
      final fallbackId = newId();
      final pointedId = newId();
      final httpClient = _SyncHttpClient(
        userId: userId,
        companionId: fallbackId,
        profileCompanionId: pointedId,
      );
      final client = SupabaseClient(
        'https://sync.example.test',
        'anon',
        httpClient: httpClient,
      );
      final gateway = SupabaseLearningGateway(
        client,
        userIdProvider: () => userId,
      );
      final local = LearningSnapshot.empty()..accountScope = userId;
      local.preferences
        ..name = '指向的名字'
        ..updatedAt = DateTime.parse('2026-09-02T00:00:00Z');

      final result = await gateway.synchronize(local);

      expect(result.preferences.name, '指向的名字');
      expect(httpClient.companion['display_name'], '云端名字');
      expect(httpClient.companionRows[pointedId]?['display_name'], '指向的名字');
      expect(httpClient.profile['active_companion_id'], pointedId);
      await client.dispose();
    },
  );

  test(
    'synchronize unlocks an existing locked memory and keeps the earliest date',
    () async {
      final userId = newId();
      final companionId = newId();
      final httpClient = _SyncHttpClient(
        userId: userId,
        companionId: companionId,
        lockedMemory: true,
      );
      final client = SupabaseClient(
        'https://sync.example.test',
        'anon',
        httpClient: httpClient,
      );
      final gateway = SupabaseLearningGateway(
        client,
        userIdProvider: () => userId,
      );
      final local = LearningSnapshot.empty()..accountScope = userId;
      local.memories['first_name'] = DateTime.parse('2026-08-30T00:00:00Z');

      await gateway.synchronize(local);

      expect(httpClient.memoryRows['first_name']?['unlocked'], isTrue);
      expect(
        httpClient.memoryRows['first_name']?['unlocked_at'],
        '2026-08-30T00:00:00.000Z',
      );
      final memoryPatches = httpClient.requests.where(
        (request) =>
            request.method == 'PATCH' &&
            request.url.path.endsWith('/sprite_memories'),
      );
      expect(memoryPatches, hasLength(1));
      expect(memoryPatches.single.url.queryParameters['unlocked'], 'eq.false');
      await client.dispose();
    },
  );
}
