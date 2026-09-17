import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/learning_models.dart';
import '../domain/learning_engine.dart';
import 'learning_gateway.dart';

class SupabaseLearningGateway implements LearningGateway {
  static const int maxRecordingBytes = 10 * 1024 * 1024;
  static const int maxRecordingDurationMs = 180 * 1000;
  static const int _syncRetryAttempts = 3;
  static const Duration _syncRetryDelay = Duration(milliseconds: 120);
  static const Map<String, String> _recordingExtensions = {
    'audio/webm': 'webm',
    'audio/mp4': 'mp4',
    'audio/ogg': 'ogg',
    'audio/wav': 'wav',
    'audio/x-wav': 'wav',
    'audio/wave': 'wav',
    'audio/x-pn-wav': 'wav',
  };

  SupabaseLearningGateway(this.client, {this.userIdProvider});
  final SupabaseClient client;
  final String? Function()? userIdProvider;
  @override
  bool get configured => true;
  @override
  String? get userId => userIdProvider?.call() ?? client.auth.currentUser?.id;
  @override
  String? get email => client.auth.currentUser?.email;
  @override
  bool get isAnonymous => client.auth.currentUser?.isAnonymous == true;
  @override
  Stream<String?> get accountChanges => client.auth.onAuthStateChange
      .map((event) => event.session?.user.id)
      .distinct();
  @override
  Future<void> signIn(String email, String password) async {
    await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  @override
  Future<void> signInAnonymously() async {
    await client.auth.signInAnonymously();
    if (userId == null) {
      throw const LearningFailure('暂时无法开始云端学习，请稍后重试。');
    }
  }

  @override
  Future<void> signUp(String email, String password, {String? emailRedirectTo}) async {
    final response = await client.auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: emailRedirectTo,
    );
    if (response.session == null) {
      throw const LearningFailure(
        '请检查邮箱并确认注册，然后回来登录。',
        code: 'email_confirmation',
      );
    }
  }

  @override
  Future<void> resetPassword(String email, {String? emailRedirectTo}) async {
    await client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: emailRedirectTo,
    );
  }

  @override
  Future<void> signOut() => client.auth.signOut(scope: SignOutScope.local);
  String _requireUser() {
    final id = userId;
    if (id == null) {
      throw const LearningFailure('登录后就能生成自己的英文和语音。', code: 'login_required');
    }
    return id;
  }

  @override
  Future<Map<String, dynamic>> invoke(
    String function,
    Map<String, dynamic> body, {
    bool get = false,
  }) async {
    _requireUser();
    try {
      final result = await client.functions.invoke(
        function,
        body: get ? null : body,
        method: get ? HttpMethod.get : HttpMethod.post,
        abortSignal: Future<void>.delayed(const Duration(seconds: 100)),
      );
      return objectMap(result.data);
    } on FunctionException catch (e) {
      throw functionFailure(e.status, e.details);
    } on TimeoutException {
      throw const LearningFailure('请求超时，草稿已保留，请稍后重试。', code: 'timeout');
    }
  }

  static LearningFailure functionFailure(int status, Object? details) {
    final payload = details is Map
        ? Map<String, dynamic>.from(details)
        : const <String, dynamic>{};
    final code =
        payload['error']?.toString() ?? payload['code']?.toString() ?? '';
    final feature = payload['feature']?.toString();
    final resetsAt = payload['resetsAt'] is String
        ? DateTime.tryParse(payload['resetsAt'] as String)
        : null;
    final currentPeriodEndsAt = payload['currentPeriodEndsAt'] is String
        ? DateTime.tryParse(payload['currentPeriodEndsAt'] as String)
        : null;
    final retryAfterSeconds = payload['retryAfterSeconds'] is num
        ? (payload['retryAfterSeconds'] as num).toInt()
        : null;
    final requestId = payload['requestId']?.toString();
    LearningFailure membershipFailure(String message) => LearningFailure(
      message,
      code: code,
      feature: feature,
      resetsAt: resetsAt,
      currentPeriodEndsAt: currentPeriodEndsAt,
      renewalRequired: payload['renewalRequired'] == true,
      retryAfterSeconds: retryAfterSeconds,
      requestId: requestId,
    );
    switch (code) {
      case 'trial_expired':
        return membershipFailure('试用已结束，已有内容仍可学习；开通会员后可继续生成。');
      case 'membership_required':
        return membershipFailure('这项功能需要有效会员，已有内容仍可学习。');
      case 'feature_limit_reached':
        return membershipFailure('这类生成额度已达到当前方案上限，已有内容仍可学习。');
      case 'request_exceeds_feature_limit':
        return membershipFailure('这次请求超过当前方案单次上限，请缩短内容后重试。');
      case 'service_budget_protected':
        return membershipFailure('系统正在保护服务预算，暂时不能新增生成；草稿已保留。');
      case 'request_conflict':
        return membershipFailure('同一个请求的内容发生变化，请保留当前草稿并重新提交。');
      case 'generation_in_progress':
      case 'request_in_progress':
        return membershipFailure('内容正在准备，请稍后刷新结果。');
      case 'service_paused':
        return membershipFailure('新增生成暂时暂停，已有内容仍可学习。');
      case 'anonymous_test_ended':
        return membershipFailure('匿名测试已经结束，请注册或登录后继续；本机内容仍保留。');
      case 'membership_sales_disabled':
        return membershipFailure('会员购买暂未开放，请稍后再试。');
      case 'payment_provider_unavailable':
        return membershipFailure('支付渠道尚未配置，暂未开放。');
      case 'profile_consent_required':
        return membershipFailure('请先确认研究资料用途说明，或选择跳过。');
      case 'profile_notice_changed':
        return membershipFailure('研究资料说明已更新，请重新阅读后再提交。');
      case 'profile_age_policy_required':
        return membershipFailure('当前年龄段暂不能收集研究资料。');
      case 'profile_conflict':
        return membershipFailure('研究资料已在其他设备更新，请刷新后再编辑。');
      case 'profile_invalid_input':
        return membershipFailure('研究资料格式无效，请检查后重试。');
      case 'profile_unavailable':
        return membershipFailure('研究资料暂时不可用，学习不受影响。');
      case 'quota_exceeded':
        return membershipFailure('当前生成额度已达到上限，已有内容仍可学习。');
    }
    if (status == 401 || (status == 403 && code.isEmpty)) {
      return const LearningFailure('登录已失效，请重新登录。', code: 'unauthorized');
    }
    if (status == 0) {
      return const LearningFailure(
        '网络暂时不可用，内容已保留，请稍后重试。',
        code: 'network_unavailable',
      );
    }
    if (code == 'quota_exceeded') {
      return const LearningFailure(
        '今天的生成额度已用完，已有内容仍可学习。',
        code: 'quota_exceeded',
      );
    }
    if (code == 'request_in_progress') {
      return const LearningFailure(
        '内容正在准备，请稍后重试。',
        code: 'request_in_progress',
      );
    }
    if (code == 'sync_conflict') {
      return const LearningFailure('云端刚刚发生了变化，请再次同步合并。', code: 'sync_conflict');
    }
    if (code == 'invalid_duration' || code == 'audio_duration_too_long') {
      return const LearningFailure(
        '录音时长无效或超过 3 分钟。',
        code: 'invalid_audio_duration',
      );
    }
    if (status == 429) {
      return const LearningFailure('请求有些频繁，请稍后再试。', code: 'rate_limited');
    }
    if (status == 404) {
      return const LearningFailure(
        '这项在线服务尚未就绪，请先使用文字输入或已有内容。',
        code: 'service_missing',
      );
    }
    final message =
        payload['message'] is String &&
            (payload['message'] as String).trim().isNotEmpty
        ? (payload['message'] as String).trim()
        : '在线服务暂时不可用，内容已保留，请稍后重试。';
    return LearningFailure(
      message,
      code: code.isEmpty ? 'provider_unavailable' : code,
      feature: feature,
      resetsAt: resetsAt,
      currentPeriodEndsAt: currentPeriodEndsAt,
      renewalRequired: payload['renewalRequired'] == true,
      retryAfterSeconds: retryAfterSeconds,
      requestId: requestId,
    );
  }

  /// Normalizes browser MIME parameters and accepts the WAV aliases emitted by
  /// different MediaRecorder implementations.
  static String normalizeRecordingMime(Object? value) {
    if (value is! String || value.trim().isEmpty) {
      throw const LearningFailure(
        '浏览器录音格式暂不受支持。',
        code: 'unsupported_audio_format',
      );
    }
    final mime = value.split(';').first.trim().toLowerCase();
    if (!_recordingExtensions.containsKey(mime)) {
      throw const LearningFailure(
        '浏览器录音格式暂不受支持。',
        code: 'unsupported_audio_format',
      );
    }
    return mime;
  }

  static String recordingExtension(String mime) =>
      _recordingExtensions[mime] ??
      (throw const LearningFailure(
        '浏览器录音格式暂不受支持。',
        code: 'unsupported_audio_format',
      ));

  /// The browser bridge reports milliseconds. Rejecting zero avoids a request
  /// that the speech function must reject anyway, and keeps the client error
  /// stable when a recorder returns incomplete metadata.
  static int validateRecordingDuration(Object? value) {
    final number = value is num
        ? value
        : value is String
        ? num.tryParse(value)
        : null;
    if (number == null || !number.isFinite || number % 1 != 0) {
      throw const LearningFailure(
        '录音时长无效，请重新录音。',
        code: 'invalid_audio_duration',
      );
    }
    final duration = number.toInt();
    if (duration <= 0) {
      throw const LearningFailure(
        '录音时长无效，请重新录音。',
        code: 'invalid_audio_duration',
      );
    }
    if (duration > maxRecordingDurationMs) {
      throw const LearningFailure(
        '录音超过 3 分钟，请分段录音。',
        code: 'audio_duration_too_long',
      );
    }
    return duration;
  }

  static String transcriptionRequestId(String value) {
    try {
      return validId(value);
    } on FormatException {
      throw const LearningFailure('录音请求无效，请重新录音。', code: 'invalid_request');
    }
  }

  static DateTime? serverUpdatedAt(Map<String, dynamic>? row) {
    final value = row?['updated_at'];
    if (value is! String) return null;
    return DateTime.tryParse(value)?.toLocal();
  }

  /// Returns the profile pointer before falling back to an active companion.
  /// A pointer is returned even when the row is not in the fallback list so the
  /// caller can fetch that exact companion instead of silently selecting one.
  static String? preferredCompanionId(Map<String, dynamic>? profile) {
    final value = profile?['active_companion_id'];
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return null;
  }

  static bool _sameValue(Object? left, Object? right) {
    if (left is num && right is num) return (left - right).abs() < 0.0001;
    if (left is String &&
        right is String &&
        (left.contains('T') || right.contains('T'))) {
      final leftDate = DateTime.tryParse(left);
      final rightDate = DateTime.tryParse(right);
      if (leftDate != null && rightDate != null) {
        return leftDate.toUtc() == rightDate.toUtc();
      }
    }
    if (left is Map && right is Map) {
      if (left.length != right.length) return false;
      for (final key in left.keys) {
        if (!right.containsKey(key) || !_sameValue(left[key], right[key])) {
          return false;
        }
      }
      return true;
    }
    if (left is List && right is List) {
      if (left.length != right.length) return false;
      for (var i = 0; i < left.length; i++) {
        if (!_sameValue(left[i], right[i])) return false;
      }
      return true;
    }
    return left == right;
  }

  static bool fieldsMatch(
    Map<String, dynamic> actual,
    Map<String, dynamic> desired,
    Iterable<String> fields,
  ) {
    for (final field in fields) {
      if (!_sameValue(actual[field], desired[field])) return false;
    }
    return true;
  }

  /// Retries only operations whose caller has made idempotent. LearningFailure
  /// and malformed data are deterministic and are never retried.
  static Future<T> retryIdempotent<T>(
    Future<T> Function() operation, {
    int attempts = _syncRetryAttempts,
    Duration delay = _syncRetryDelay,
  }) async {
    if (attempts < 1) throw ArgumentError.value(attempts, 'attempts');
    Object? lastError;
    StackTrace? lastStack;
    for (var attempt = 0; attempt < attempts; attempt++) {
      try {
        return await operation();
      } catch (error, stack) {
        if (error is LearningFailure ||
            error is FormatException ||
            attempt == attempts - 1) {
          Error.throwWithStackTrace(error, stack);
        }
        lastError = error;
        lastStack = stack;
        if (delay > Duration.zero) {
          await Future<void>.delayed(
            Duration(milliseconds: delay.inMilliseconds * (attempt + 1)),
          );
        }
      }
    }
    Error.throwWithStackTrace(
      lastError ?? StateError('retry failed'),
      lastStack ?? StackTrace.current,
    );
  }

  @override
  Future<Map<String, dynamic>?> seedAudio(String seedId, String voice) async {
    _requireUser();
    final row = await client
        .from('audio_manifests')
        .select('id')
        .eq('seed_sentence_id', seedId)
        .eq('voice_profile', voice)
        .eq('generation_status', 'ready')
        .maybeSingle();
    if (row == null) return null;
    return invoke('audio-download-url', {'manifestId': row['id']});
  }

  @override
  Future<String> transcribe(
    Map<String, dynamic> recording,
    String requestId,
  ) async {
    _requireUser();
    final mime = normalizeRecordingMime(recording['mimeType']);
    final extension = recordingExtension(mime);
    final id = transcriptionRequestId(requestId);
    final durationMs = validateRecordingDuration(recording['durationMs']);
    late final Uint8List bytes;
    try {
      bytes = base64Decode(
        requiredText(recording['base64'], '录音', max: 14 * 1024 * 1024),
      );
    } on FormatException {
      throw const LearningFailure('录音数据无效，请重新录音。', code: 'invalid_recording');
    }
    if (bytes.isEmpty || bytes.length > maxRecordingBytes) {
      throw const LearningFailure('录音为空或超过 10 MB。', code: 'invalid_recording');
    }
    final boundary = 'selah-${newId()}';
    final multipart = BytesBuilder();
    void write(String text) => multipart.add(utf8.encode(text));
    final language = recording['language'] == 'ja' ? 'ja' : 'zh';
    final fields = {
      'clientRequestId': id,
      'language': language,
      'durationMs': '$durationMs',
    };
    for (final field in fields.entries) {
      write(
        '--$boundary\r\nContent-Disposition: form-data; name="${field.key}"\r\n\r\n${field.value}\r\n',
      );
    }
    write(
      '--$boundary\r\nContent-Disposition: form-data; name="file"; filename="recording.$extension"\r\nContent-Type: $mime\r\n\r\n',
    );
    multipart.add(bytes);
    write('\r\n--$boundary--\r\n');
    try {
      final response = await client.functions.invoke(
        'speech-transcribe',
        body: multipart.takeBytes(),
        headers: {'Content-Type': 'multipart/form-data; boundary=$boundary'},
        abortSignal: Future<void>.delayed(const Duration(seconds: 100)),
      );
      return requiredText(objectMap(response.data)['text'], '转写文本', max: 4000);
    } on FunctionException catch (e) {
      throw functionFailure(e.status, e.details);
    } on RequestAbortedException {
      throw const LearningFailure('转写请求超时，录音已保留，请稍后重试。', code: 'timeout');
    } on TimeoutException {
      throw const LearningFailure('转写请求超时，录音已保留，请稍后重试。', code: 'timeout');
    } on FormatException {
      throw const LearningFailure(
        '转写服务返回了无效结果，请稍后重试。',
        code: 'transcription_invalid_response',
      );
    } catch (_) {
      throw const LearningFailure(
        '网络暂时不可用，录音已保留，请稍后重试。',
        code: 'network_unavailable',
      );
    }
  }

  static const _syncConflict = LearningFailure(
    '云端刚刚发生了变化，请再次同步合并。',
    code: 'sync_conflict',
  );
  static const _syncUnavailable = LearningFailure(
    '同步失败，本地内容已保留，请稍后重试。',
    code: 'sync_unavailable',
  );
  static const _syncInvalidData = LearningFailure(
    '云端数据格式无效，本地内容已保留。',
    code: 'sync_invalid_data',
  );
  static const _accountChanged = LearningFailure(
    '账户已切换，请重新同步。',
    code: 'account_changed',
  );

  static List<Map<String, dynamic>> _maps(Object? value) {
    if (value is! List) throw const FormatException('云端返回格式无效。');
    return value.map((row) {
      if (row is! Map) throw const FormatException('云端返回格式无效。');
      return Map<String, dynamic>.from(row);
    }).toList();
  }

  LearningFailure _syncFailure(Object error) {
    if (error is LearningFailure) return error;
    if (error is FormatException) return _syncInvalidData;
    return _syncUnavailable;
  }

  Future<T> _syncCall<T>(Future<T> Function() operation) async {
    try {
      return await retryIdempotent(operation);
    } catch (error) {
      throw _syncFailure(error);
    }
  }

  void _ensureAccount(String expected) {
    if (userId != expected) {
      throw _accountChanged;
    }
  }

  Future<T> _accountWrite<T>(
    String expected,
    Future<T> Function() operation,
  ) async {
    _ensureAccount(expected);
    final result = await operation();
    _ensureAccount(expected);
    return result;
  }

  Future<List<Map<String, dynamic>>> _rows(
    String table,
    String user, {
    String key = 'user_id',
  }) async {
    final result = <Map<String, dynamic>>[];
    for (var page = 0; page < 100; page++) {
      final rows = await _syncCall(() async {
        final value = await client
            .from(table)
            .select()
            .eq(key, user)
            .order('id')
            .range(page * 500, page * 500 + 499);
        return _maps(value);
      });
      result.addAll(rows);
      if (rows.length < 500) return result;
    }
    throw const LearningFailure('云端记录数量超出本次同步范围，已保留本地数据。', code: 'sync_limit');
  }

  Future<Map<String, dynamic>?> _findById(
    String table,
    String id, {
    String? user,
  }) async {
    final row = await _syncCall(() async {
      final value = user == null
          ? await client.from(table).select().eq('id', id).maybeSingle()
          : await client
                .from(table)
                .select()
                .eq('id', id)
                .eq('user_id', user)
                .maybeSingle();
      if (value == null) return null;
      return Map<String, dynamic>.from(value);
    });
    return row;
  }

  Future<Map<String, dynamic>?> _findMemory(
    String companionId,
    String memoryKey,
  ) async {
    return _syncCall(() async {
      final value = await client
          .from('sprite_memories')
          .select()
          .eq('companion_id', companionId)
          .eq('memory_key', memoryKey)
          .maybeSingle();
      if (value == null) return null;
      return Map<String, dynamic>.from(value);
    });
  }

  Future<List<Map<String, dynamic>>> _activeCompanionRows(String user) async {
    return _syncCall(() async {
      final rows = await client
          .from('companions')
          .select()
          .eq('user_id', user)
          .eq('active', true)
          .order('created_at')
          .limit(1);
      return _maps(rows);
    });
  }

  Future<void> _upsert(
    String table,
    List<Map<String, dynamic>> rows, {
    required String user,
    String conflict = 'id',
    bool ignoreDuplicates = false,
  }) async {
    for (var start = 0; start < rows.length; start += 100) {
      final end = (start + 100).clamp(0, rows.length);
      final chunk = rows.sublist(start, end);
      await _accountWrite(
        user,
        () => _syncCall(
          () => client
              .from(table)
              .upsert(
                chunk,
                onConflict: conflict,
                ignoreDuplicates: ignoreDuplicates,
              ),
        ),
      );
    }
  }

  Future<Map<String, dynamic>> _upsertAndConfirm({
    required String table,
    required Map<String, dynamic> values,
    required String conflict,
    required String user,
    required Future<Map<String, dynamic>?> Function() fetch,
    required Iterable<String> fields,
  }) async {
    LearningFailure? failure;
    try {
      await _accountWrite(
        user,
        () => _syncCall(
          () => client
              .from(table)
              .upsert([values], onConflict: conflict, ignoreDuplicates: true),
        ),
      );
    } catch (error) {
      failure = _syncFailure(error);
    }
    final current = await fetch();
    if (current != null) {
      if (fieldsMatch(current, values, fields)) return current;
      throw _syncConflict;
    }
    if (failure != null) throw failure;
    throw _syncUnavailable;
  }

  Future<Map<String, dynamic>> _conditionalUpdateById({
    required String table,
    required Map<String, dynamic> values,
    required String id,
    required String observedUpdatedAt,
    required Iterable<String> fields,
    required String account,
    String? user,
  }) async {
    List<Map<String, dynamic>>? changed;
    LearningFailure? failure;
    try {
      changed = await _accountWrite(
        account,
        () => _syncCall(() async {
          final rows = user == null
              ? await client
                    .from(table)
                    .update(values)
                    .eq('id', id)
                    .eq('updated_at', observedUpdatedAt)
                    .select()
              : await client
                    .from(table)
                    .update(values)
                    .eq('id', id)
                    .eq('user_id', user)
                    .eq('updated_at', observedUpdatedAt)
                    .select();
          return _maps(rows);
        }),
      );
    } catch (error) {
      failure = _syncFailure(error);
    }
    final current = await _findById(table, id, user: user);
    if (current != null && fieldsMatch(current, values, fields)) return current;
    if (current != null &&
        serverUpdatedAt(current)?.toUtc().toIso8601String() !=
            observedUpdatedAt) {
      throw _syncConflict;
    }
    if (changed != null && changed.isNotEmpty) return changed.first;
    if (failure != null) throw failure;
    throw _syncConflict;
  }

  static DateTime _requiredUpdatedAt(Map<String, dynamic> row) {
    final value = serverUpdatedAt(row);
    if (value == null) throw _syncInvalidData;
    return value;
  }

  static String? _validUuidOrNull(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    try {
      return validId(value);
    } on FormatException {
      return null;
    }
  }

  static const _sentenceFields = [
    'source_text',
    'target_text',
    'category',
    'origin',
    'deconstruction',
    'vocab_candidates',
    'archived',
    'previewed_at',
    'listen_completed_at',
    'review_state',
    'next_review_at',
    'interval_days',
    'last_recall_signal',
    'lapse_count',
  ];
  static const _vocabFields = [
    'sentence_id',
    'surface_text',
    'meaning_in_context',
    'help_state',
  ];
  static const _companionFields = [
    'display_name',
    'decoration_stage',
    'active',
  ];
  static const _profileFields = [
    'active_companion_id',
    'voice_profile',
    'playback_speed',
    'onboarding_completed',
    'notification_enabled',
    'notification_time',
  ];

  static Map<String, dynamic> _sentenceInsertValues(
    LearnSentence sentence,
    String user,
  ) {
    final values = sentenceToCloud(sentence, user);
    // INSERT has no updated_at trigger; omitting it lets Postgres assign the
    // authoritative server timestamp instead of persisting a skewed client clock.
    values.remove('updated_at');
    return values;
  }

  static Map<String, dynamic> _sentenceUpdateValues(
    LearnSentence sentence,
    String user,
  ) {
    final values = sentenceToCloud(sentence, user);
    // created_at is immutable, and updated_at is owned by the BEFORE UPDATE trigger.
    values.remove('created_at');
    values.remove('updated_at');
    return values;
  }

  Future<void> _writeMemory(
    String user,
    String companionId,
    String key,
    DateTime desired,
    Map<String, dynamic>? previous,
  ) async {
    final values = <String, dynamic>{
      'companion_id': companionId,
      'memory_key': key,
      'title': memoryTitles[key]?.$1 ?? key,
      'description_text': memoryTitles[key]?.$2 ?? '',
      'unlocked': true,
      'unlocked_at': desired.toUtc().toIso8601String(),
    };
    if (previous == null) {
      await _upsertAndConfirm(
        table: 'sprite_memories',
        values: values,
        conflict: 'companion_id,memory_key',
        user: user,
        fetch: () => _findMemory(companionId, key),
        fields: const ['unlocked', 'unlocked_at'],
      );
      return;
    }
    final wasUnlocked = previous['unlocked'];
    if (wasUnlocked is! bool) throw _syncInvalidData;
    final observedValue = previous['unlocked_at'];
    if (observedValue != null && observedValue is! String) {
      throw _syncInvalidData;
    }
    final observed = observedValue as String?;
    final oldDate = observed == null ? null : DateTime.tryParse(observed);
    if (observed != null && oldDate == null) throw _syncInvalidData;
    if (wasUnlocked && oldDate == null) throw _syncInvalidData;
    final firstUnlock = oldDate != null && oldDate.isBefore(desired)
        ? oldDate
        : desired;
    values['unlocked_at'] = firstUnlock.toUtc().toIso8601String();
    // Memory unlock dates are first-seen timestamps; retain the earliest one.
    if (wasUnlocked && !desired.isBefore(oldDate!)) return;
    List<Map<String, dynamic>>? changed;
    try {
      changed = await _accountWrite(
        user,
        () => _syncCall(() async {
          final rows = wasUnlocked
              ? await client
                    .from('sprite_memories')
                    .update(values)
                    .eq('companion_id', companionId)
                    .eq('memory_key', key)
                    .eq('unlocked_at', observed!)
                    .select()
              : observed == null
              ? await client
                    .from('sprite_memories')
                    .update(values)
                    .eq('companion_id', companionId)
                    .eq('memory_key', key)
                    .eq('unlocked', false)
                    .isFilter('unlocked_at', null)
                    .select()
              : await client
                    .from('sprite_memories')
                    .update(values)
                    .eq('companion_id', companionId)
                    .eq('memory_key', key)
                    .eq('unlocked', false)
                    .eq('unlocked_at', observed)
                    .select();
          return _maps(rows);
        }),
      );
    } catch (error) {
      final current = await _findMemory(companionId, key);
      if (current != null &&
          fieldsMatch(current, values, const ['unlocked', 'unlocked_at'])) {
        return;
      }
      if (current != null &&
          (current['unlocked'] != wasUnlocked ||
              current['unlocked_at'] != observed)) {
        throw _syncConflict;
      }
      throw _syncFailure(error);
    }
    if (changed == null || changed.isEmpty) {
      final current = await _findMemory(companionId, key);
      if (current != null &&
          fieldsMatch(current, values, const ['unlocked', 'unlocked_at'])) {
        return;
      }
      throw _syncConflict;
    }
  }

  @override
  Future<LearningSnapshot> synchronize(LearningSnapshot local) async {
    try {
      final user = _requireUser();
      final cloud = LearningSnapshot.empty()..accountScope = user;
      final sentenceRows = await _rows('sentences', user);
      final vocabRows = await _rows('vocab_items', user);
      final profile = await _findById('user_profiles', user);
      final preferred = _validUuidOrNull(preferredCompanionId(profile));
      Map<String, dynamic>? companion;
      if (preferred != null) {
        companion = await _findById('companions', preferred, user: user);
      }
      // A valid profile pointer is authoritative. Only choose an active
      // fallback when the profile has no usable pointer at all; otherwise a
      // missing pointed row is repaired under that same ID below.
      if (companion == null && preferred == null) {
        final rows = await _activeCompanionRows(user);
        companion = rows.isEmpty ? null : rows.first;
      }
      for (final row in sentenceRows) {
        cloud.sentences.add(
          sentenceFromCloud(
            row,
            vocabRows.where((v) => v['sentence_id'] == row['id']).toList(),
          ),
        );
      }
      if (profile != null) {
        final profileAt = _requiredUpdatedAt(profile);
        final companionAt = companion == null
            ? profileAt
            : (_requiredUpdatedAt(companion).isAfter(profileAt)
                  ? _requiredUpdatedAt(companion)
                  : profileAt);
        cloud.preferences = LearnPreferences.fromJson({
          'name': companion?['display_name'] ?? '小豆',
          'voice': profile['voice_profile'],
          'speed': profile['playback_speed'],
          'onboarded': profile['onboarding_completed'],
          'reminderEnabled': profile['notification_enabled'],
          'reminderTime': profile['notification_time'],
          'updatedAt': companionAt.toUtc().toIso8601String(),
        });
      } else if (companion != null) {
        cloud.preferences.updatedAt = _requiredUpdatedAt(companion);
        cloud.preferences.name = requiredText(
          companion['display_name'],
          '精灵名字',
          max: 24,
        );
      }
      final eventRows = await _rows('learning_events', user);
      final ids = cloud.sentences.map((s) => s.id).toSet();
      for (final row in eventRows) {
        if (![
          'sentence_created',
          'listen_completed',
          'practice_rated',
          'preview_completed',
          'memory_unlocked',
          'activity_heartbeat',
          'feedback_invite_shown',
          'feedback_invite_dismissed',
          'feedback_submitted',
          'feedback_plan_viewed',
        ].contains(row['event_type'])) {
          continue;
        }
        if (row['sentence_id'] != null && !ids.contains(row['sentence_id'])) {
          continue;
        }
        cloud.events.add(
          LearnEvent.fromJson({
            'id': row['id'],
            'type': row['event_type'],
            'sentenceId': row['sentence_id'],
            'metadata': row['metadata'],
            'at': row['happened_at'],
          }),
        );
      }
      final memoryRows = <Map<String, dynamic>>[];
      if (companion != null) {
        final memories = await _syncCall(() async {
          final rows = await client
              .from('sprite_memories')
              .select()
              .eq('companion_id', companion!['id']);
          return _maps(rows);
        });
        memoryRows.addAll(memories);
        for (final row in memories) {
          final key = row['memory_key'];
          if (key is! String) throw _syncInvalidData;
          if (row['unlocked'] == true) {
            cloud.memories[key] = dateValue(row['unlocked_at'], DateTime.now());
          }
        }
      }
      if (userId != user) throw _accountChanged;
      final merged = local.merge(cloud);
      final existing = {
        for (final row in sentenceRows) row['id'] as String: row,
      };
      for (final sentence in merged.sentences) {
        final previous = existing[sentence.id];
        if (previous == null) {
          final persisted = await _upsertAndConfirm(
            table: 'sentences',
            values: _sentenceInsertValues(sentence, user),
            conflict: 'id',
            user: user,
            fetch: () => _findById('sentences', sentence.id, user: user),
            fields: _sentenceFields,
          );
          final serverAt = serverUpdatedAt(persisted);
          if (serverAt != null) sentence.updatedAt = serverAt;
        } else {
          final observedAt = _requiredUpdatedAt(previous);
          if (sentence.updatedAt.isAfter(observedAt)) {
            final persisted = await _conditionalUpdateById(
              table: 'sentences',
              values: _sentenceUpdateValues(sentence, user),
              id: sentence.id,
              user: user,
              observedUpdatedAt: previous['updated_at'] as String,
              fields: _sentenceFields,
              account: user,
            );
            final serverAt = serverUpdatedAt(persisted);
            if (serverAt != null) sentence.updatedAt = serverAt;
          }
        }
      }
      final vocabById = {for (final row in vocabRows) row['id'] as String: row};
      for (final sentence in merged.sentences) {
        for (final vocab in sentence.vocabulary) {
          final prior = vocabById[vocab.id];
          final values = <String, dynamic>{
            'id': vocab.id,
            'user_id': user,
            'sentence_id': sentence.id,
            'surface_text': vocab.text,
            'meaning_in_context': vocab.meaning,
            'help_state': vocab.state,
          };
          if (prior == null) {
            final persisted = await _upsertAndConfirm(
              table: 'vocab_items',
              values: values,
              conflict: 'id',
              user: user,
              fetch: () => _findById('vocab_items', vocab.id, user: user),
              fields: _vocabFields,
            );
            final serverAt = serverUpdatedAt(persisted);
            if (serverAt != null) vocab.updatedAt = serverAt;
          } else {
            final observedAt = _requiredUpdatedAt(prior);
            if (vocab.updatedAt.isAfter(observedAt)) {
              final persisted = await _conditionalUpdateById(
                table: 'vocab_items',
                values: values,
                id: vocab.id,
                user: user,
                observedUpdatedAt: prior['updated_at'] as String,
                fields: _vocabFields,
                account: user,
              );
              final serverAt = serverUpdatedAt(persisted);
              if (serverAt != null) vocab.updatedAt = serverAt;
            }
          }
        }
      }
      final pref = merged.preferences;
      final preferredId = _validUuidOrNull(preferred);
      final companionId = companion?['id'] as String? ?? preferredId ?? user;
      final desiredCompanion = <String, dynamic>{
        'id': companionId,
        'user_id': user,
        'display_name': pref.name,
        'decoration_stage': LearningEngine.stage(merged),
        'active': true,
      };
      final companionFieldsMatch =
          companion != null &&
          fieldsMatch(companion, desiredCompanion, _companionFields);
      Map<String, dynamic>? persistedCompanion = companion;
      if (!companionFieldsMatch) {
        if (companion == null) {
          persistedCompanion = await _upsertAndConfirm(
            table: 'companions',
            values: desiredCompanion,
            conflict: 'id',
            user: user,
            fetch: () => _findById('companions', companionId, user: user),
            fields: _companionFields,
          );
        } else {
          persistedCompanion = await _conditionalUpdateById(
            table: 'companions',
            values: desiredCompanion,
            id: companionId,
            user: user,
            observedUpdatedAt: companion['updated_at'] as String,
            fields: _companionFields,
            account: user,
          );
        }
      }
      final desiredProfile = <String, dynamic>{
        'id': user,
        'active_companion_id': companionId,
        'voice_profile': pref.voice,
        'playback_speed': pref.speed,
        'onboarding_completed': pref.onboarded,
        'notification_enabled': pref.reminderEnabled,
        'notification_time': pref.reminderTime,
      };
      final profileFieldsMatch =
          profile != null &&
          fieldsMatch(profile, desiredProfile, _profileFields);
      Map<String, dynamic>? persistedProfile = profile;
      if (!profileFieldsMatch) {
        if (profile == null) {
          persistedProfile = await _upsertAndConfirm(
            table: 'user_profiles',
            values: desiredProfile,
            conflict: 'id',
            user: user,
            fetch: () => _findById('user_profiles', user),
            fields: _profileFields,
          );
        } else {
          persistedProfile = await _conditionalUpdateById(
            table: 'user_profiles',
            values: desiredProfile,
            id: user,
            observedUpdatedAt: profile['updated_at'] as String,
            fields: _profileFields,
            account: user,
          );
        }
      }
      final memoryByKey = {
        for (final row in memoryRows) row['memory_key'] as String: row,
      };
      for (final entry in merged.memories.entries) {
        await _writeMemory(
          user,
          companionId,
          entry.key,
          entry.value,
          memoryByKey[entry.key],
        );
      }
      await _upsert(
        'learning_events',
        merged.events
            .map(
              (event) => <String, dynamic>{
                'id': event.id,
                'user_id': user,
                'sentence_id': event.sentenceId,
                'event_type': event.type,
                'metadata': event.metadata,
                'happened_at': event.at.toUtc().toIso8601String(),
              },
            )
            .toList(),
        user: user,
        ignoreDuplicates: true,
      );
      if (userId != user) throw _accountChanged;
      final timestamps = [
        serverUpdatedAt(persistedCompanion),
        serverUpdatedAt(persistedProfile),
      ].whereType<DateTime>().toList();
      if (timestamps.isNotEmpty) {
        merged.preferences.updatedAt = timestamps.reduce(
          (a, b) => a.isAfter(b) ? a : b,
        );
      }
      merged.lastSyncAt = DateTime.now();
      return merged;
    } catch (error) {
      if (error is LearningFailure) rethrow;
      throw _syncFailure(error);
    }
  }

  static Map<String, dynamic> sentenceToCloud(LearnSentence s, String user) => {
    'id': s.id,
    'user_id': user,
    'source_text': s.source,
    'target_text': s.target,
    'category': s.category,
    'origin': s.origin,
    'deconstruction': s.breakdown
        .map((part) => {...part, if (s.seedId != null) 'seedId': s.seedId})
        .toList(),
    'vocab_candidates': s.vocabulary
        .map(
          (v) => {
            'surfaceText': v.text,
            'meaningInContext': v.meaning,
            'suggestedHelpState': v.state,
          },
        )
        .toList(),
    'archived': s.archived,
    'previewed_at': s.previewedAt?.toUtc().toIso8601String(),
    'listen_completed_at': s.listenedAt?.toUtc().toIso8601String(),
    'review_state': s.reviewState,
    'next_review_at': s.nextReviewAt.toUtc().toIso8601String(),
    'interval_days': s.intervalDays,
    'last_recall_signal': s.lastRecallSignal,
    'lapse_count': s.lapseCount,
    'created_at': s.createdAt.toUtc().toIso8601String(),
    'updated_at': s.updatedAt.toUtc().toIso8601String(),
  };
  static LearnSentence sentenceFromCloud(
    Map<String, dynamic> row,
    List<Map<String, dynamic>> vocab,
  ) {
    final id = validId(row['id']);
    final breakdown = mapList(row['deconstruction'], max: 50);
    final seedId = breakdown.isEmpty ? null : breakdown.first['seedId'];
    return LearnSentence.fromJson({
      'id': id,
      'source': row['source_text'],
      'target': row['target_text'],
      'category': row['category'],
      'origin': row['origin'],
      'seedId': seedId,
      'breakdown': row['deconstruction'],
      'archived': row['archived'],
      'createdAt': row['created_at'],
      'updatedAt': row['updated_at'],
      'reviewState': row['review_state'],
      'nextReviewAt': row['next_review_at'],
      'intervalDays': row['interval_days'],
      'lapseCount': row['lapse_count'],
      'lastRecallSignal': row['last_recall_signal'],
      'listenedAt': row['listen_completed_at'],
      'previewedAt': row['previewed_at'],
      'vocabulary': vocab
          .map(
            (v) => {
              'id': v['id'],
              'text': v['surface_text'],
              'meaning': v['meaning_in_context'],
              'state': v['help_state'],
              'updatedAt': v['updated_at'],
            },
          )
          .toList(),
    });
  }
}
