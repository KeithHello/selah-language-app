import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../domain/selah_enums.dart';
import 'domain/learning_models.dart';
import 'domain/learning_engine.dart';
import 'domain/audio_preparation.dart';
import 'domain/loop_listening.dart';
import 'domain/research_profile.dart';
import 'domain/web_status.dart';
import 'l10n/selah_strings.dart';
import 'data/learning_gateway.dart';
import 'data/audio_preparation_service.dart';
import 'data/learning_store.dart';
import 'admin/admin_controller.dart';
import 'membership_controller.dart';
import 'research_profile_controller.dart';
import 'feedback_survey_controller.dart';
import 'platform/learning_platform.dart';

String selahAuthRedirectUrl({Uri? current}) {
  final uri = current ?? Uri.base;
  var path = uri.path;
  if (!path.endsWith('/')) {
    path = '$path/';
  }
  return Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
    path: path,
  ).toString();
}

class LearningController extends ChangeNotifier {
  LearningController({
    required this.gateway,
    required this.platform,
    required List<LearnSentence> seeds,
    this.polling = true,
    this.bundledAudio = const {},
    AdminController? adminController,
    MembershipController? membershipController,
    ResearchProfileController? researchProfileController,
    FeedbackSurveyController? feedbackSurveyController,
  }) : _baseSeeds = seeds,
       store = LearningStore(platform),
       admin = adminController ?? AdminController(gateway: gateway),
       membership =
           membershipController ?? MembershipController(gateway: gateway),
       researchProfile =
           researchProfileController ??
           ResearchProfileController(gateway: gateway) {
    feedbackSurvey =
        feedbackSurveyController ??
        FeedbackSurveyController(
          gateway: gateway,
          recordEvent: _recordFeedbackEvent,
        );
  }
  final Map<String, dynamic> bundledAudio;
  final List<LearnSentence> _baseSeeds;
  final LearningGateway gateway;
  final LearningPlatform platform;
  final LearningStore store;
  final AdminController admin;
  final MembershipController membership;
  final ResearchProfileController researchProfile;
  late final FeedbackSurveyController feedbackSurvey;
  List<LearnSentence> get seeds {
    if (nativeLanguage != 'ja') return _baseSeeds;
    return _baseSeeds.map((seed) {
      final japaneseText = seed.jaText;
      if (japaneseText == null) return seed;
      final json = seed.toJson();
      return LearnSentence.fromJson({
        ...json,
        'source': japaneseText,
        'sourceLanguage': 'ja',
      });
    }).toList();
  }

  final bool polling;
  LearningSnapshot state = LearningSnapshot.empty();
  bool initialized = false;
  bool busy = false;
  bool recording = false;
  bool syncing = false;
  bool savingLocal = false;
  bool localSaveFailed = false;
  bool syncFailed = false;
  String? error;
  String? errorCode;
  String? notice;
  int tab = 0;
  int? detailTab;
  String? detailSentenceId;
  LearnSentence? activeSentence;

  /// A same-source record whose generation provenance is unknown. It is only
  /// offered as a history link; it is never treated as a reusable result.
  LearnSentence? legacySentence;
  Map<String, dynamic> playback = {
    'state': 'idle',
    'positionMs': 0,
    'durationMs': 0,
  };
  Map<String, dynamic> loopPlayback = {
    'state': 'idle',
    'phase': null,
    'sentenceIndex': 0,
    'sentenceCount': 0,
    'remainingMs': 0,
    'order': 'targetFirst',
    'stopReason': null,
  };
  bool loopPreparing = false;
  bool loopReady = false;
  int loopPreparedTracks = 0;
  int loopTotalTracks = 0;
  List<Map<String, Object?>> _loopTracks = [];
  final AudioPreparationService _audioPreparation = AudioPreparationService();
  final Set<String> _loopVerifiedKeys = <String>{};
  String? _loopSessionId;
  String? _loopAccountId;
  Map<String, dynamic> platformInfo = {};
  String _accountId = 'guest';
  String? _playSession;
  String? _playKey;
  String? _playSentenceId;
  String? _previewKey;
  int _playGeneration = 0;
  String? _recordRequestId;
  Map<String, dynamic>? _pendingRecording;
  String? _pendingPracticeSentenceId;
  String? _pendingPracticeSignal;
  Timer? _timer;
  Timer? _syncTimer;
  Timer? _companionTimer;
  Timer? _localInputTimer;
  Timer? _activityTimer;
  SpriteActionId? _companionCue;
  int companionRevision = 0;
  StreamSubscription<String?>? _auth;
  bool _disposed = false;
  bool _polling = false;
  int _accountGeneration = 0;
  Future<void> _accountLoad = Future.value();
  // Concurrent cloud entry points share this Future so a double click cannot
  // create more than one temporary anonymous Supabase identity.
  Future<void>? _cloudSessionLoad;
  String? _remindedDay;
  String? _activitySessionId;
  DateTime? _lastActivityAt;
  DateTime? _activitySlotStart;
  Future<void> _writes = Future.value();
  bool _cloudDirty = false;
  int _cloudRevision = 0;
  int _inputVersion = 0;
  bool _inputDirty = false;
  int _pendingWrites = 0;
  bool? _unloadProtected;
  final _departingInputs = <String, LearningSnapshot>{};
  final _backupGenerations = Expando<int>();
  bool get hasUnsavedChanges =>
      _inputDirty ||
      savingLocal ||
      localSaveFailed ||
      _departingInputs.isNotEmpty ||
      recording ||
      hasPendingRecording ||
      _pendingPracticeSignal != null;
  bool get configured => gateway.configured;
  bool get loopActive => const {
    'starting',
    'playing',
    'gap',
    'paused',
  }.contains(loopPlayback['state']);
  bool get hasSession => gateway.userId != null;
  bool get isAnonymous => gateway.isAnonymous;
  /// Anonymous Supabase sessions authenticate API calls but never become a
  /// cloud account scope; only a formal account can sync or use membership.
  bool get isRegistered => hasSession && !isAnonymous;
  bool get hasPendingRecording => _pendingRecording != null;
  String? get pendingPracticeSignal => _pendingPracticeSignal;
  String? get pendingPracticeSentenceId => _pendingPracticeSentenceId;
  String? get email => gateway.email;
  String get accountId => _accountId;

  /// The interface follows the one native-language choice selected in
  /// Settings.  Keep this getter for widgets that render product copy.
  String get uiLocale => nativeLanguage;
  String get nativeLanguage =>
      normalizeNativeLanguage(state.preferences.nativeLanguage);
  SelahStrings get strings => SelahStrings.of(uiLocale);
  String get sourceLanguage => generationSourceLanguage(nativeLanguage);
  String get targetLanguage => generationTargetLanguage;
  String get todayInput => state.todayInput;
  PreparationDraft? get preparationDraft => state.preparationDraft;
  WebSyncPresentation get syncPresentation => WebSyncPresentation.evaluate(
    configured: configured,
    hasSession: isRegistered,
    online: platformInfo['online'] == true,
    initialized: initialized,
    savingLocal: savingLocal,
    localSaveFailed: localSaveFailed,
    syncing: syncing,
    syncFailed: syncFailed,
    hasPendingCloudChanges: _cloudDirty,
    lastSyncAt: state.lastSyncAt,
    uiLocale: uiLocale,
  );
  SpriteActionId get companionAction {
    if (recording) return SpriteActionId.recRecording;
    if (playback['state'] == 'loading') return SpriteActionId.listenEnter;
    if (_companionCue != null) return _companionCue!;
    if (playback['state'] == 'playing') return SpriteActionId.listenPlaying;
    return SpriteActionId.gentleFloat;
  }

  void _clearCompanionCue() {
    _companionTimer?.cancel();
    _companionCue = null;
  }

  void _showCompanionCue(SpriteActionId action) {
    _clearCompanionCue();
    _companionCue = action;
    companionRevision++;
    _companionTimer = Timer(const Duration(milliseconds: 1400), () {
      _companionCue = null;
      notifyListeners();
    });
    notifyListeners();
  }

  Future<void> updateLoopPreferences({
    LoopOrder? order,
    int? durationMinutes,
  }) => _run((generation) async {
    await _change((next) {
      next.preferences.loopOptions = LoopOptions(
        order: order ?? next.preferences.loopOptions.order,
        durationMinutes:
            durationMinutes ?? next.preferences.loopOptions.durationMinutes,
      ).copyWith();
    }, generation: generation);
    notice = '循环听设置已保存。';
  });

  String _loopVoiceFor(LoopTrackRole role) => role == LoopTrackRole.source
      ? state.preferences.nativeVoice
      : state.preferences.voice;

  Future<String> _loopAudioKey(
    String text,
    LoopTrackRole role,
    String language,
  ) async {
    final hash = await platform.invoke('contentHash', {'text': text});
    if (hash is! String || !RegExp(r'^[a-f0-9]{64}$').hasMatch(hash)) {
      throw const LearningFailure('浏览器无法校验音频内容。');
    }
    return audioTrackKey(
      voice: _loopVoiceFor(role),
      role: role == LoopTrackRole.source
          ? AudioTrackRole.source
          : AudioTrackRole.target,
      language: language,
      contentHash: hash,
    );
  }

  Future<AudioTrackRef> _loopTrackReference(
    LearnSentence sentence,
    LoopTrackRole role,
  ) async {
    final text = role == LoopTrackRole.target
        ? sentence.target.trim()
        : sentence.source.trim();
    final language = role == LoopTrackRole.target
        ? (sentence.targetLanguage ?? currentTargetLanguage)
        : (sentence.sourceLanguage ?? currentSourceLanguage);
    final key = await _loopAudioKey(text, role, language);
    return AudioTrackRef(
      sentenceId: sentence.id,
      role: role == LoopTrackRole.source
          ? AudioTrackRole.source
          : AudioTrackRole.target,
      language: language,
      voice: _loopVoiceFor(role),
      text: text,
      key: key,
    );
  }

  Map<String, dynamic>? _bundledLoopAudio(
    LearnSentence sentence,
    LoopTrackRole role,
    String voice,
    String language,
  ) {
    final seedId = sentence.seedId;
    if (seedId == null) return null;
    final key = role == LoopTrackRole.target
        ? '$seedId:$voice'
        : '$seedId:source:$language';
    final entry = bundledAudio[key];
    if (role == LoopTrackRole.source &&
        entry == null &&
        language == currentSourceLanguage) {
      final legacy = bundledAudio['$seedId:source'];
      return legacy is Map ? Map<String, dynamic>.from(legacy) : null;
    }
    return entry is Map ? Map<String, dynamic>.from(entry) : null;
  }

  Future<bool> _ensureBundledLoopAudio(
    String account,
    LearnSentence sentence,
    AudioTrackRef reference,
  ) async {
    final role = reference.role == AudioTrackRole.source
        ? LoopTrackRole.source
        : LoopTrackRole.target;
    final bundled = _bundledLoopAudio(
      sentence,
      role,
      reference.voice,
      reference.language,
    );
    if (bundled == null) return false;
    final relative = bundled['path'];
    final checksum = bundled['sha256'];
    if (relative is! String ||
        !relative.startsWith('assets/audio/') ||
        relative.contains('..') ||
        checksum is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(checksum)) {
      throw const LearningFailure('本地循环音频清单无效。');
    }
    await platform.invoke('audioEnsure', {
      'accountId': account,
      'key': reference.key,
      'url': Uri.base.resolve('assets/$relative').toString(),
      'sha256': checksum,
    });
    return true;
  }

  Future<void> prepareLoop() => _run((generation) => _prepareLoop(generation));

  Future<void> _recordAudioFailure(
    AudioTrackRef reference,
    Object failure,
    int generation,
  ) async {
    if (!_current(generation)) return;
    final previous = state.audio[reference.key];
    try {
      await _change(
        (next) {
          next.audio[reference.key] = {
            ...?previous,
            'status': 'failed',
            'errorCode': failure is LearningFailure
                ? failure.code
                : 'unavailable',
          };
        },
        sync: false,
        generation: generation,
      );
    } catch (_) {
      // Background audio must never turn a successfully saved sentence into
      // a failed Today operation. Loop preparation will retry the key later.
    }
  }

  Future<void> _ensureAudioTrack(
    AudioTrackRef reference,
    int generation,
  ) async {
    _ensureCurrent(generation);
    final account = _accountId;
    var cached =
        await platform.invoke('audioCached', {
          'accountId': account,
          'key': reference.key,
        }) ==
        true;
    _ensureCurrent(generation);
    final sentence = state.sentences
        .where((candidate) => candidate.id == reference.sentenceId)
        .firstOrNull;
    if (!cached && sentence != null) {
      cached = await _ensureBundledLoopAudio(account, sentence, reference);
      _ensureCurrent(generation);
    }
    if (!cached) {
      if (sentence == null || sentence.archived) {
        throw const LearningFailure('句子已删除，跳过音频准备。', code: 'audio_cancelled');
      }
      final isSeed = sentence.seedId != null;
      if (!hasSession) {
        await ensureCloudSession();
        _ensureCurrent(generation);
      }
      if (!hasSession) {
        throw LearningFailure(
          isSeed
              ? '例句的母语音频尚未随应用包就绪，请更新包含例句母语音频的版本。'
              : '登录后即可为自己的句子补齐音频。',
          code: isSeed ? 'seed_native_audio_missing' : 'login_required',
        );
      }
      if (!gateway.configured) {
        throw const LearningFailure(
          '在线服务尚未配置。你可以继续学习已保存的内容。',
          code: 'not_configured',
        );
      }
      final savedManifest = state.audio[reference.key];
      if (savedManifest?['manifestId'] != null) {
        final response = await gateway.invoke('audio-download-url', {
          'manifestId': savedManifest!['manifestId'],
        });
        await _ensureLoopAudio(
          account,
          reference.key,
          requiredText(response['downloadUrl'], '音频地址'),
        );
      } else {
        final requestId = savedManifest?['requestId'] as String? ?? newId();
        await _change(
          (next) {
            next.audio[reference.key] = {
              ...?next.audio[reference.key],
              'requestId': requestId,
              'status': 'pending',
            };
          },
          sync: false,
          generation: generation,
        );
        final response = await gateway.invoke('audio-generate', {
          'sentenceId': reference.sentenceId,
          'contractVersion': 2,
          'text': reference.text,
          'audioRole': reference.role.name,
          'sourceLanguage': sentence.sourceLanguage ?? currentSourceLanguage,
          'targetLanguage': sentence.targetLanguage ?? currentTargetLanguage,
          'accent': reference.accent,
          'voiceProfile': reference.voice,
          'reason': 'audio_preparation',
          'clientRequestId': requestId,
        });
        final stored = {
          ...response,
          'requestId': requestId,
          'status': response['status'] ?? 'ready',
        };
        await _change(
          (next) => next.audio[reference.key] = stored,
          sync: false,
          generation: generation,
        );
        if (response['status'] != 'ready' || response['downloadUrl'] == null) {
          throw const LearningFailure(
            '音频正在准备，请稍后重试。',
            code: 'audio_pending',
          );
        }
        await _ensureLoopAudio(
          account,
          reference.key,
          requiredText(response['downloadUrl'], '音频地址'),
        );
      }
      cached = true;
    }
    if (!cached) throw const LearningFailure('音频缓存不存在，请先联网获取。');
    _loopVerifiedKeys.add(reference.key);
  }

  Future<void> _prepareSentenceAudio(
    LearnSentence sentence,
    int generation,
  ) async {
    try {
      final references = await Future.wait([
        _loopTrackReference(sentence, LoopTrackRole.target),
        _loopTrackReference(sentence, LoopTrackRole.source),
      ]);
      for (final reference in references) {
        try {
          await _audioPreparation.ensure(
            reference,
            (track) => _ensureAudioTrack(track, generation),
          );
        } catch (failure) {
          if (failure is! LearningFailure || failure.code != 'audio_cancelled') {
            await _recordAudioFailure(reference, failure, generation);
          }
        }
      }
    } catch (_) {
      // Content persistence has already completed. Audio can be retried from
      // Loop or on the next background attempt.
    }
  }

  void _scheduleSentenceAudio(LearnSentence sentence, int generation) {
    unawaited(_prepareSentenceAudio(sentence, generation));
  }

  Future<void> _cleanupRemovedLoopAudio(
    String account,
    Iterable<String> keys,
  ) async {
    for (final key in keys) {
      try {
        await platform.invoke('audioCacheDelete', {
          'accountId': account,
          'key': key,
        });
      } catch (_) {
        // Cache cleanup is opportunistic; a missing delete bridge must not
        // block playback of the current desired set.
      }
    }
  }

  Future<Set<String>> _cachedLoopAudioKeys(String account) async {
    try {
      final value = await platform.invoke('audioCacheKeys', {
        'accountId': account,
      });
      if (value is! List) return <String>{};
      return value
          .whereType<String>()
          .where((key) => key.startsWith(audioCacheKeyPrefix))
          .toSet();
    } catch (_) {
      // Older bridge versions may not enumerate cache keys. Known in-memory
      // keys are still cleaned up below.
      return <String>{};
    }
  }

  Future<void> _prepareLoop(int generation) async {
    loopReady = false;
    loopPreparing = true;
    loopPreparedTracks = 0;
    loopTotalTracks = 0;
    _loopTracks = [];
    notifyListeners();
    try {
      final items = buildLoopQueue(
        state.sentences.where((sentence) => !sentence.archived).toList(),
      );
      if (items.isEmpty) throw const LearningFailure('还没有可循环播放的句子。');

      final references = <AudioTrackRef>[];
      for (final item in items) {
        final sentence = state.sentences.firstWhere(
          (candidate) => candidate.id == item.sentenceId,
        );
        references
          ..add(await _loopTrackReference(sentence, LoopTrackRole.target))
          ..add(await _loopTrackReference(sentence, LoopTrackRole.source));
      }
      _ensureCurrent(generation);
      final diff = diffAudioTracks(
        desired: references,
        preparedKeys: _loopVerifiedKeys,
      );
      final account = _accountId;
      final desiredKeys = references.map((reference) => reference.key).toSet();
      final cachedKeys = await _cachedLoopAudioKeys(account);
      final orphanKeys = <String>{
        ...diff.removedKeys,
        ...cachedKeys.where((key) => !desiredKeys.contains(key)),
      };
      _loopVerifiedKeys.removeAll(orphanKeys);
      await _cleanupRemovedLoopAudio(account, orphanKeys);
      _sameAccount(account);
      _ensureCurrent(generation);
      loopTotalTracks = diff.missing.length;
      notifyListeners();
      for (final reference in diff.missing) {
        await _audioPreparation.ensure(
          reference,
          (track) => _ensureAudioTrack(track, generation),
        );
        _sameAccount(account);
        _ensureCurrent(generation);
        loopPreparedTracks += 1;
        notifyListeners();
      }
      _loopTracks = references.map((reference) => reference.toLoopTrack()).toList();
      loopPreparing = false;
      loopReady = true;
      notice = '双语音频已准备好。';
      notifyListeners();
    } catch (_) {
      loopPreparing = false;
      loopReady = false;
      _loopTracks = [];
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _ensureLoopAudio(String account, String key, String url) async {
    final uri = Uri.tryParse(url);
    final isLocalHttp =
        uri != null &&
        uri.scheme == 'http' &&
        const {'localhost', '127.0.0.1'}.contains(uri.host);
    if (uri == null || (uri.scheme != 'https' && !isLocalHttp)) {
      throw const FormatException('音频地址无效。');
    }
    await platform.invoke('audioEnsure', {
      'accountId': account,
      'key': key,
      'url': url,
    });
  }

  Future<bool> get isLoopReady async {
    final items = buildLoopQueue(
      state.sentences.where((sentence) => !sentence.archived).toList(),
    );
    for (final item in items) {
      final sentence = state.sentences.firstWhere(
        (candidate) => candidate.id == item.sentenceId,
      );
      for (final role in LoopTrackRole.values) {
        final reference = await _loopTrackReference(sentence, role);
        final cached = await platform.invoke('audioCached', {
          'accountId': _accountId,
          'key': reference.key,
        });
        if (cached != true) return false;
      }
    }
    return true;
  }

  Future<void> startLoop() => _run((generation) async {
    try {
      try {
        await platform.invoke('audioUnlock');
      } catch (_) {
        // Unlocking is an enhancement. The bridge still reports a clear
        // retryable state if the browser blocks the eventual media play.
      }
      await _prepareLoop(generation);
      _ensureCurrent(generation);
      await _beginLoopSession(generation);
    } catch (_) {
      loopPreparing = false;
      rethrow;
    }
  });

  Future<void> _beginLoopSession(int generation) async {
    _loopSessionId = newId();
    _loopAccountId = _accountId;
    final order = state.preferences.loopOptions.order.name;
    final started = await platform.invoke('audioLoopStart', {
      'accountId': _accountId,
      'sessionId': _loopSessionId,
      'order': order,
      'durationMs': state.preferences.loopOptions.durationMinutes * 60 * 1000,
      'speed': state.preferences.speed,
      'tracks': _loopTracks,
      'gapMs': {'language': 1000, 'sentence': 2000},
    });
    _ensureCurrent(generation);
    loopPlayback = started is Map
        ? objectMap(started)
        : objectMap(
            await platform.invoke('audioLoopStatus', {
              'accountId': _accountId,
              'sessionId': _loopSessionId,
            }),
          );
    notifyListeners();
  }

  Future<void> pauseLoop() => _loopControl('audioLoopPause');
  Future<void> resumeLoop() => _loopControl('audioLoopResume');
  Future<void> nextLoopSentence() => _loopControl('audioLoopNext');

  String? get loopSessionId => _loopSessionId;

  Future<void> setLoopOrder(LoopOrder order) async {
    await updateLoopPreferences(order: order);
    if (_loopSessionId != null) {
      final status = await platform.invoke('audioLoopOrder', {
        'accountId': _accountId,
        'sessionId': _loopSessionId,
        'order': order.name,
      });
      if (status is Map) loopPlayback = objectMap(status);
      notifyListeners();
    }
  }

  Future<void> _loopControl(String action) async {
    final sessionId = _loopSessionId;
    if (sessionId == null) return;
    final status = await platform.invoke(action, {
      'accountId': _accountId,
      'sessionId': sessionId,
    });
    if (status is Map) loopPlayback = objectMap(status);
    notifyListeners();
  }

  Future<void> stopLoop({String reason = 'user'}) async {
    final sessionId = _loopSessionId;
    _loopSessionId = null;
    loopPreparing = false;
    if (sessionId != null) {
      await platform.invoke('audioLoopStop', {
        'accountId': _loopAccountId ?? _accountId,
        'sessionId': sessionId,
      });
    }
    loopPlayback = {
      'state': 'idle',
      'phase': null,
      'sentenceIndex': 0,
      'sentenceCount': 0,
      'remainingMs': 0,
      'order': state.preferences.loopOptions.order.name,
      'stopReason': reason,
    };
    notifyListeners();
  }

  List<LearnSentence> get due =>
      LearningEngine.due(state.sentences, DateTime.now());
  @override
  void notifyListeners() {
    if (_disposed) return;
    if (hasSession) _markActive();
    final enabled = hasUnsavedChanges;
    if (_unloadProtected != enabled) {
      _unloadProtected = enabled;
      unawaited(
        platform
            .invoke('setUnloadProtection', {'enabled': enabled})
            .catchError((Object _) => null),
      );
    }
    super.notifyListeners();
  }

  void _markActive() {
    final now = DateTime.now().toUtc();
    if (_activitySessionId == null ||
        _lastActivityAt == null ||
        now.difference(_lastActivityAt!) > const Duration(minutes: 30)) {
      _activitySessionId = newId();
      _activitySlotStart = null;
    }
    _lastActivityAt = now;
  }

  Future<void> _recordActivityHeartbeat() async {
    if (!hasSession ||
        platformInfo['online'] == false ||
        _disposed ||
        !initialized) {
      return;
    }
    final now = DateTime.now().toUtc();
    final playing = playback['state'] == 'playing';
    final visible = platformInfo['hidden'] != true;
    final recent =
        _lastActivityAt != null &&
        now.difference(_lastActivityAt!) <= const Duration(minutes: 2);
    if (!((visible && recent) || playing)) return;
    _markActive();
    final slotStart = DateTime.fromMillisecondsSinceEpoch(
      now.millisecondsSinceEpoch ~/ 30000 * 30000,
      isUtc: true,
    );
    if (_activitySlotStart == slotStart) return;
    _activitySlotStart = slotStart;
    final event = LearnEvent(
      id: newId(),
      type: 'activity_heartbeat',
      metadata: {
        'session_id': _activitySessionId,
        'slot_start': slotStart.millisecondsSinceEpoch ~/ 1000,
        'duration_ms': 30000,
        'visible': visible,
        'audio_playing': playing,
      },
    );
    try {
      await gateway.invoke('events', {
        'id': event.id,
        'eventType': event.type,
        'metadata': event.metadata,
      });
      await _change((next) => next.events.add(event));
    } catch (_) {
      _activitySlotStart = null;
    }
  }

  Future<void> ensureCloudSession() {
    if (hasSession) return Future<void>.value();
    final existing = _cloudSessionLoad;
    if (existing != null) return existing;
    final load = _ensureCloudSession().whenComplete(() {
      _cloudSessionLoad = null;
    });
    _cloudSessionLoad = load;
    return load;
  }

  Future<void> _ensureCloudSession() async {
    if (!configured) {
      throw const LearningFailure(
        '在线服务尚未配置。你可以继续学习种子句和已保存的内容。',
        code: 'not_configured',
      );
    }
    if (platformInfo['online'] == false) {
      throw const LearningFailure('现在处于离线状态，联网后可继续生成。');
    }
    _localInputTimer?.cancel();
    await _writes;
    await store.save('guest', state.copy());
    // Keep the browser's guest scope while using the anonymous identity only
    // as a short-lived credential for protected Edge Function requests.
    await gateway.signInAnonymously();
    if (gateway.userId == null) {
      throw const LearningFailure('暂时无法开始云端学习，请稍后重试。');
    }
    _ensureCurrent(_accountGeneration);
  }

  Future<void> initialize() async {
    if (initialized) return;
    try {
      _auth ??= gateway.accountChanges.listen((id) {
        if (gateway.isAnonymous) {
          // Anonymous cloud calls share the local guest scope. Establishing a
          // temporary Supabase identity must not clear the current page.
          notifyListeners();
          return;
        }
        if ((id ?? 'guest') != _accountId) {
          unawaited(_switchAccount(id ?? 'guest'));
        }
      });
      final initialAccount = gateway.isAnonymous
          ? 'guest'
          : (gateway.userId ?? 'guest');
      await _switchAccount(initialAccount, force: true);
      platformInfo = objectMap(await platform.invoke('platformInfo'));
      if (polling) {
        _timer ??= Timer.periodic(
          const Duration(milliseconds: 450),
          (_) => unawaited(_poll()),
        );
        _activityTimer ??= Timer.periodic(
          const Duration(seconds: 30),
          (_) => unawaited(_recordActivityHeartbeat()),
        );
      }
      if (isRegistered && platformInfo['online'] == true) _scheduleSync();
    } catch (e) {
      errorCode = e is LearningFailure ? e.code : null;
      error = _message(e, fallback: '无法读取本机学习记录，请检查浏览器存储权限后重试。');
    }
    notifyListeners();
  }

  Future<void> _switchAccount(String id, {bool force = false}) {
    if (id == _accountId && !force) return _accountLoad;
    final previousLoopSession = _loopSessionId;
    final previousLoopAccount = _loopAccountId ?? _accountId;
    _loopSessionId = null;
    _loopAccountId = null;
    loopPreparing = false;
    loopReady = false;
    _loopVerifiedKeys.clear();
    _audioPreparation.clear();
    if (initialized && (_inputDirty || localSaveFailed)) {
      _saveDepartingInput(_accountId, state.copy());
    }
    final generation = ++_accountGeneration;
    _accountId = id;
    _syncTimer?.cancel();
    _clearCompanionCue();
    _playSession = null;
    _playKey = null;
    _playSentenceId = null;
    _previewKey = null;
    _playGeneration++;
    initialized = false;
    busy = false;
    syncing = false;
    savingLocal = false;
    localSaveFailed = false;
    syncFailed = false;
    _cloudDirty = false;
    _cloudRevision = 0;
    _inputDirty = false;
    _inputVersion = 0;
    _pendingWrites = 0;
    _localInputTimer?.cancel();
    error = null;
    errorCode = null;
    notice = null;
    recording = false;
    _pendingRecording = null;
    _recordRequestId = null;
    _pendingPracticeSentenceId = null;
    _pendingPracticeSignal = null;
    state = LearningSnapshot.empty()..accountScope = id;
    activeSentence = null;
    legacySentence = null;
    detailTab = null;
    detailSentenceId = null;
    playback = {'state': 'idle', 'positionMs': 0, 'durationMs': 0};
    loopPlayback = {
      'state': 'idle',
      'phase': null,
      'sentenceIndex': 0,
      'sentenceCount': 0,
      'remainingMs': 0,
      'order': state.preferences.loopOptions.order.name,
      'stopReason': 'accountChanged',
    };
    if (previousLoopSession != null) {
      unawaited(
        platform
            .invoke('audioLoopStop', {
              'accountId': previousLoopAccount,
              'sessionId': previousLoopSession,
            })
            .catchError((Object _) => null),
      );
    }
    _activitySessionId = null;
    _lastActivityAt = null;
    _activitySlotStart = null;
    notifyListeners();
    _accountLoad = _loadAccount(id, generation);
    return _accountLoad;
  }

  void _saveDepartingInput(String account, LearningSnapshot draft) {
    _departingInputs[account] = draft;
    _writes = _writes
        .then((_) async {
          final saved = await store.load(account);
          saved.todayInput = draft.todayInput;
          saved.segmentInputs
            ..clear()
            ..addAll(draft.segmentInputs);
          saved.preparationDraft = draft.preparationDraft == null
              ? null
              : PreparationDraft.fromJson(draft.preparationDraft!.toJson());
          await store.save(account, saved);
          if (identical(_departingInputs[account], draft)) {
            _departingInputs.remove(account);
          }
        })
        .catchError((Object _) {
          // Keep the departing account's draft in memory for retry and restoration.
          localSaveFailed = true;
          errorCode = null;
          error = '先前账户的输入尚未保存，请检查浏览器存储后重试本机保存。';
        })
        .whenComplete(notifyListeners);
  }

  Future<void> _loadAccount(String id, int generation) async {
    try {
      await platform.invoke('audioStop');
      if (!_current(generation)) return;
      await platform.invoke('recordCancel');
      await _writes;
      if (!_current(generation)) return;
      final loaded = await store.load(id);
      if (!_current(generation)) return;
      state = loaded;
      final unsaved = _departingInputs[id];
      if (unsaved != null) {
        state.todayInput = unsaved.todayInput;
        state.segmentInputs
          ..clear()
          ..addAll(unsaved.segmentInputs);
        state.preparationDraft = unsaved.preparationDraft == null
            ? null
            : PreparationDraft.fromJson(unsaved.preparationDraft!.toJson());
        _inputDirty = true;
      }
      _inputVersion = [
        ...state.drafts.map((draft) => draft.inputVersion ?? 0),
        if (state.preparationDraft?.inputVersion != null)
          state.preparationDraft!.inputVersion!,
      ].fold<int>(0, (max, value) => value > max ? value : max);
      initialized = true;
      localSaveFailed = _departingInputs.isNotEmpty;
      syncFailed = false;
      _cloudDirty = false;
      if (isRegistered) {
        unawaited(membership.load());
        unawaited(researchProfile.load());
        _scheduleSync();
      }
    } catch (e) {
      if (_current(generation)) {
        errorCode = e is LearningFailure ? e.code : null;
        error = _message(e, fallback: '读取账户数据失败，请刷新重试。');
      }
    }
    if (_current(generation)) notifyListeners();
  }

  bool _current(int generation) =>
      !_disposed &&
      generation == _accountGeneration &&
      (gateway.isAnonymous
          ? _accountId == 'guest'
          : (gateway.userId ?? 'guest') == _accountId);
  void _ensureCurrent(int generation) {
    if (!_current(generation)) {
      throw const LearningFailure('账户已切换，请重新操作。', code: 'account_changed');
    }
  }

  void clearMessage() {
    error = null;
    errorCode = null;
    notice = null;
    notifyListeners();
  }

  void updateTodayInput(String text) {
    if (!initialized || text == state.todayInput) return;
    state.todayInput = text;
    _queueInputSave();
  }

  void _queueInputSave() {
    _inputVersion++;
    _inputDirty = true;
    _localInputTimer?.cancel();
    _localInputTimer = Timer(const Duration(milliseconds: 300), () {
      unawaited(flushLocalWrites());
    });
    notifyListeners();
  }

  Future<void> clearTodayInput() async {
    updateTodayInput('');
    await flushPendingLocalWritesForTest();
  }

  void updateSegmentInputs(List<String> texts) {
    if (!initialized) return;
    if (texts.length > PreparationDraft.maxSegments) {
      throw const LearningFailure('分段最多保留二十段，请先减少内容后重试。');
    }
    state.segmentInputs
      ..clear()
      ..addAll(texts);
    _queueInputSave();
  }

  void updatePreparationSegment(int index, String text) {
    final preparation = state.preparationDraft;
    if (!initialized || preparation == null) return;
    if (index < 0 || index >= preparation.segments.length) return;
    if (busy) {
      notice = '生成中，请等待完成后再编辑分句。';
      notifyListeners();
      return;
    }
    final source = text.trim();
    if (source.isEmpty || source.length > 500) return;
    final segment = preparation.segments[index];
    if (segment.sourceText == source) return;
    segment
      ..sourceText = source
      ..id = newId()
      ..status = 'pending'
      ..updatedAt = DateTime.now();
    preparation.updatedAt = DateTime.now();
    _queueInputSave();
    preparation.inputVersion = _inputVersion;
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

  PreparationDraft? _mergeLivePreparation(
    PreparationDraft? before,
    PreparationDraft? saved,
    PreparationDraft? live,
  ) {
    if (before == null) {
      return live == null ? null : _copyPreparationDraft(live);
    }
    if (live == null) return null;
    if (saved == null) {
      final changed =
          before.id != live.id ||
          before.sourceText != live.sourceText ||
          before.segments.length != live.segments.length ||
          before.segments.asMap().entries.any((entry) {
            final current = entry.value;
            final original = before.segments[entry.key];
            return current.id != original.id ||
                current.sourceText != original.sourceText ||
                current.status != original.status;
          });
      return changed ? _copyPreparationDraft(live) : null;
    }
    if (before.id != live.id || before.sourceText != live.sourceText) {
      return _copyPreparationDraft(live);
    }
    final beforeById = {
      for (final segment in before.segments) segment.id: segment,
    };
    final savedById = {
      for (final segment in saved.segments) segment.id: segment,
    };
    final used = <String>{};
    final replaced = <String>{};
    final segments = <PreparationSegment>[];
    for (var index = 0; index < live.segments.length; index++) {
      final current = live.segments[index];
      final original = beforeById[current.id];
      final changed =
          original == null ||
          original.sourceText != current.sourceText ||
          original.status != current.status;
      if (changed && original != null) replaced.add(original.id);
      final replacement = changed ? current : savedById[current.id];
      segments.add(_copyPreparationSegment(replacement ?? current));
      used.add((replacement ?? current).id);
    }
    for (final segment in saved.segments) {
      if (!used.contains(segment.id) && !replaced.contains(segment.id)) {
        segments.add(_copyPreparationSegment(segment));
      }
    }
    return PreparationDraft(
      id: saved.id,
      sourceText: saved.sourceText,
      inputVersion: saved.inputVersion ?? live.inputVersion,
      segments: segments,
      sourceLanguage: saved.sourceLanguage,
      targetLanguage: saved.targetLanguage,
      createdAt: saved.createdAt,
      updatedAt: saved.updatedAt,
    );
  }

  void _copyLiveInputs(
    LearningSnapshot next, {
    required LearningSnapshot before,
  }) {
    next.todayInput = state.todayInput;
    next.segmentInputs
      ..clear()
      ..addAll(state.segmentInputs);
    next.preparationDraft = _mergeLivePreparation(
      before.preparationDraft,
      next.preparationDraft,
      state.preparationDraft,
    );
  }

  Future<void> clearSegmentInputs() async {
    updateSegmentInputs([]);
    await flushLocalWrites();
  }

  void cancelPreparation() {
    if (!initialized || state.preparationDraft == null) return;
    state.preparationDraft = null;
    state.segmentInputs.clear();
    _queueInputSave();
  }

  @visibleForTesting
  Future<void> flushPendingLocalWritesForTest() => flushLocalWrites();

  Future<void> flushLocalWrites() async {
    _localInputTimer?.cancel();
    if (_inputDirty && initialized) {
      try {
        await _saveLocal((_) {}, sync: false);
      } catch (_) {
        // The save queue exposes failure and keeps the live input for retry.
      }
    }
    await _writes;
  }

  Future<void> retryLocalSave() async {
    for (final entry in _departingInputs.entries.toList()) {
      _saveDepartingInput(entry.key, entry.value);
    }
    if (initialized && localSaveFailed) _inputDirty = true;
    await flushLocalWrites();
  }

  void navigate(int value) {
    final next = value.clamp(0, 5);
    if (tab == next) return;
    tab = next;
    detailTab = null;
    detailSentenceId = null;
    if (next == 5) unawaited(admin.load());
    notifyListeners();
  }

  void selectSentence(LearnSentence sentence, {bool autoplay = false}) {
    openDetail(1, sentence);
    if (autoplay) unawaited(play(sentence));
  }

  void openDetail(int page, LearnSentence sentence) {
    if (page != 1 && page != 3) throw ArgumentError('不支持此详情页面。');
    final selected = state.sentences
        .where((s) => s.id == sentence.id)
        .firstOrNull;
    if (!initialized || selected == null) {
      throw const LearningFailure('这句内容在当前账户不可用。');
    }
    activeSentence = selected;
    tab = page;
    detailTab = page;
    detailSentenceId = selected.id;
    notifyListeners();
  }

  void closeDetail() {
    detailTab = null;
    detailSentenceId = null;
    notifyListeners();
  }

  Future<void> addSeed(LearnSentence seed) => _run((generation) async {
    if (seed.seedId == null ||
        !seeds.any((item) => item.seedId == seed.seedId)) {
      throw const LearningFailure('这条种子内容无效。');
    }
    await _change((next) {
      if (!next.sentences.any((item) => item.seedId == seed.seedId)) {
        next.sentences.add(
          LearnSentence.fromJson({
            ...seed.toJson(),
            'id': newId(),
            'vocabulary': seed.vocabulary
                .map((v) => {...v.toJson(), 'id': newId()})
                .toList(),
          }),
        );
      }
    }, generation: generation);
    _ensureCurrent(generation);
    selectSentence(
      state.sentences.firstWhere((item) => item.seedId == seed.seedId),
    );
  });

  String _message(Object e, {String fallback = '暂时无法完成操作，内容已保留，请稍后重试。'}) {
    if (e is LearningFailure) return e.message;
    if (e is FormatException) return e.message;
    final original = e.toString();
    final text = original.toLowerCase();
    const audioMessages = [
      '音频下载失败',
      '音频校验失败',
      '音频缓存失败',
      '音频地址无效',
      '音频播放失败',
      '音频缓存不存在，请先联网获取',
      '当前浏览器无法载入音频',
      '当前浏览器不支持音频播放',
      '循环听时长无效',
      '循环听缺少音频',
      '循环听需要中英双语音频',
    ];
    for (final message in audioMessages) {
      if (text.contains(message.toLowerCase())) return message;
    }
    if (text.contains('invalid login credentials')) return '邮箱或密码不正确，请重新输入。';
    if (text.contains('email not confirmed')) return '请先通过邮件确认账户。';
    if (text.contains('notallowederror') || text.contains('permission')) {
      return '浏览器未允许此操作，请检查麦克风或播放权限。';
    }
    if (text.contains('quota') || text.contains('storage')) {
      return '浏览器存储空间不足或不可用，请先导出备份并检查空间。';
    }
    return fallback;
  }

  Future<void> _run(Future<void> Function(int generation) action) async {
    if (busy) return;
    final generation = _accountGeneration;
    busy = true;
    error = null;
    errorCode = null;
    notice = null;
    notifyListeners();
    try {
      await action(generation);
    } catch (e) {
      if (_current(generation)) {
        errorCode = e is LearningFailure ? e.code : null;
        error = _message(e);
        if (playback['state'] == 'loading') playback['state'] = 'idle';
      }
    } finally {
      if (_current(generation)) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> _saveLocal(
    void Function(LearningSnapshot next) change, {
    bool sync = true,
    int? generation,
  }) {
    final account = _accountId;
    final expectedGeneration = generation ?? _accountGeneration;
    var storageFailed = false;
    Future<void> work() async {
      _ensureCurrent(expectedGeneration);
      if (!initialized) throw const LearningFailure('账户资料尚未读取完成，请稍后重试。');
      final before = state.copy();
      final next = state.copy();
      final inputVersion = _inputVersion;
      change(next);
      LearningEngine.unlock(next, DateTime.now());
      try {
        await store.save(account, next);
      } catch (_) {
        storageFailed = true;
        rethrow;
      }
      _ensureCurrent(expectedGeneration);
      if (inputVersion != _inputVersion) {
        _copyLiveInputs(next, before: before);
      } else {
        _inputDirty = false;
        _departingInputs.remove(account);
      }
      state = next;
      localSaveFailed = _departingInputs.isNotEmpty;
      if (activeSentence != null) {
        activeSentence = state.sentences
            .where((s) => s.id == activeSentence!.id)
            .firstOrNull;
      }
      notifyListeners();
      if (sync) {
        _cloudRevision++;
        _cloudDirty = true;
        _scheduleSync();
      }
    }

    _pendingWrites++;
    savingLocal = true;
    notifyListeners();
    final done = _writes.then((_) => work());
    _writes = done.then(
      (_) {
        if (_current(expectedGeneration)) {
          savingLocal = --_pendingWrites > 0;
          notifyListeners();
        }
      },
      onError: (Object failure) {
        if (_current(expectedGeneration)) {
          savingLocal = --_pendingWrites > 0;
          if (storageFailed) localSaveFailed = true;
          errorCode = failure is LearningFailure ? failure.code : null;
          error = _message(failure, fallback: '本机保存失败，内容仍保留，请重试。');
          notifyListeners();
        }
      },
    );
    return done;
  }

  Future<void> _change(
    void Function(LearningSnapshot next) change, {
    bool sync = true,
    int? generation,
  }) => _saveLocal(change, sync: sync, generation: generation);

  void _scheduleSync() {
    if (!isRegistered || platformInfo['online'] == false || _disposed) return;
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(seconds: 2), () => unawaited(sync()));
  }

  void _online() {
    if (!configured) throw const LearningFailure('在线服务尚未配置。你可以继续学习种子句和已保存的内容。');
    if (!hasSession) {
      throw const LearningFailure('请先登录，便能生成自己的英文和语音。', code: 'login_required');
    }
    if (platformInfo['online'] == false) {
      throw const LearningFailure('现在处于离线状态，联网后可继续生成。');
    }
  }

  Future<void> _ensureOnlineSession() async {
    await ensureCloudSession();
    _online();
  }

  void _sameAccount(String account) {
    final sameScope = gateway.isAnonymous
        ? account == 'guest' && _accountId == 'guest'
        : (gateway.userId ?? 'guest') == account;
    if (account != _accountId || !sameScope) {
      throw const LearningFailure('账户已切换，本次结果没有写入新账户。');
    }
  }

  Future<void> _recordFeedbackEvent(
    String eventType,
    Map<String, dynamic> metadata,
  ) async {
    if (_disposed || !hasSession) return;
    final event = LearnEvent(
      id: newId(),
      type: eventType,
      metadata: Map<String, dynamic>.from(metadata),
    );
    await _change((next) {
      if (!next.events.any((item) => item.id == event.id)) {
        next.events.add(event);
      }
    });
    if (platformInfo['online'] == false) return;
    try {
      await gateway.invoke('events', {
        'id': event.id,
        'eventType': event.type,
        'metadata': event.metadata,
      });
    } catch (_) {
      // The local event remains queued for the next normal synchronization.
    }
  }

  Future<void> _offerAfterLearning() async {
    if (_disposed || !hasSession || platformInfo['online'] == false) return;
    final offered = await feedbackSurvey.maybeOfferAfterLearning(
      events: state.events,
      uiLocale: uiLocale,
      blockedByOtherInvite: researchProfile.canShowInvite,
    );
    if (!offered && !feedbackSurvey.blocksOtherInvites) {
      await researchProfile.maybeOfferAfterLearning();
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> onboard(String name, List<String> seedIds) => _run((
    generation,
  ) async {
    final cleaned = requiredText(name, '精灵名字', max: 24);
    if (seedIds.toSet().length < minOnboardingSeedCount ||
        seedIds.any((id) => !seeds.any((s) => s.id == id || s.seedId == id))) {
      throw const LearningFailure('请选择至少三句想学的表达。');
    }
    await _change((next) {
      next.preferences
        ..name = cleaned
        ..onboarded = true
        ..updatedAt = DateTime.now();
      for (final id in seedIds) {
        final seed = seeds.firstWhere((s) => s.id == id || s.seedId == id);
        if (!next.sentences.any((s) => s.seedId == seed.seedId)) {
          next.sentences.add(
            LearnSentence.fromJson({
              ...seed.toJson(),
              'id': newId(),
              'vocabulary': seed.vocabulary
                  .map((v) => {...v.toJson(), 'id': newId()})
                  .toList(),
            }),
          );
        }
      }
    });
    tab = 0;
  });

  Future<void> generate(String text) => _generateText(text, allowReuse: true);

  /// Explicitly requests a new provider attempt, even when a matching
  /// completed sentence is already saved. Network retries use [retryDraft]
  /// instead and therefore retain the original request ID.
  Future<void> regenerate(String text) =>
      _generateText(text, allowReuse: false);

  Future<void> _generateText(String text, {required bool allowReuse}) => _run((
    generation,
  ) async {
    final source = requiredText(
      text,
      nativeLanguage == 'ja' ? '日本語の表現' : '中文表达',
      max: 500,
    );
    final submittedInputVersion = _inputVersion;
    await ensureCloudSession();
    generation = _accountGeneration;
    _ensureCurrent(generation);
    legacySentence = null;
    final existing = state.sentences
        .where(
          (sentence) =>
              normalizeSourceForReuse(sentence.source) ==
                  normalizeSourceForReuse(source) &&
              sentence.origin == 'user_recording',
        )
        .toList();
    final reusable = existing
        .where(
          (sentence) =>
              sentence.hasKnownGenerationProvenance &&
              sentence.generationModel == currentGenerationModel &&
              sentence.promptVersion == currentGenerationPromptVersion &&
              sentence.sourceLanguage == sourceLanguage &&
              sentence.targetLanguage == targetLanguage,
        )
        .firstOrNull;
    if (allowReuse && reusable != null) {
      activeSentence = reusable;
      notice = '这句已经生成过，已为你打开现有记录。';
      return;
    }
    if (allowReuse) {
      legacySentence = existing
          .where((sentence) => !sentence.hasKnownGenerationProvenance)
          .firstOrNull;
      if (legacySentence != null) {
        notice = '发现已有相同内容，来源版本未知；你可以打开历史结果。';
      }
    }
    if (!allowReuse) {
      // An explicit regeneration must never pick up a failed draft: allocate
      // a fresh request ID so the provider call and resulting sentence remain
      // distinguishable from a network retry.
      final fresh = GenerationDraft(
        id: newId(),
        text: source,
        inputVersion: submittedInputVersion,
      );
      await _change((next) => next.drafts.add(fresh), sync: false);
      _ensureCurrent(_accountGeneration);
      await _generate(
        fresh,
        _accountGeneration,
        inputVersion: submittedInputVersion,
      );
      return;
    }
    var draft = state.drafts.where((d) => d.text == source).firstOrNull;
    if (draft == null) {
      draft = GenerationDraft(
        id: newId(),
        text: source,
        inputVersion: submittedInputVersion,
      );
      await _change((next) => next.drafts.add(draft!), sync: false);
    }
    _ensureCurrent(_accountGeneration);
    await _generate(
      draft,
      _accountGeneration,
      inputVersion: draft.inputVersion ?? submittedInputVersion,
    );
  });

  void openLegacySentence() {
    final sentence = legacySentence;
    if (sentence == null) return;
    openDetail(1, sentence);
  }

  Future<void> _generate(
    GenerationDraft draft,
    int generation, {
    int? inputVersion,
  }) async {
    _ensureCurrent(generation);
    _online();
    _ensureCurrent(generation);
    final account = _accountId;
    final result = await gateway.invoke('sentences-generate', {
      'sourceText': draft.text,
      'sourceLanguage': sourceLanguage,
      'targetLanguage': targetLanguage,
      'clientRequestId': draft.id,
    });
    _sameAccount(account);
    final sentence = LearnSentence.generated(
      source: draft.text,
      requestId: draft.id,
      json: result,
    );
    await _change((next) {
      final versionMatches = inputVersion == null
          ? draft.inputVersion == null
                ? next.todayInput.trim() == draft.text.trim()
                : draft.inputVersion == _inputVersion
          : inputVersion == _inputVersion;
      if (versionMatches && next.todayInput.trim() == draft.text.trim()) {
        next.todayInput = '';
      }
      next.preparationDraft = null;
      if (!next.sentences.any((s) => s.id == sentence.id)) {
        next.sentences.add(sentence);
        next.events.add(
          LearnEvent(
            id: newId(),
            type: 'sentence_created',
            sentenceId: sentence.id,
            metadata: {
              'category': sentence.category,
              'origin': sentence.origin,
            },
          ),
        );
      }
      next.drafts.removeWhere((d) => d.id == draft.id);
    }, generation: generation);
    _ensureCurrent(generation);
    activeSentence = state.sentences.firstWhere((s) => s.id == sentence.id);
    if (isRegistered && platformInfo['online'] != false) {
      unawaited(membership.load());
    }
    _scheduleSentenceAudio(sentence, generation);
    notice = '这句英文已保存，准备好就听一听。';
  }

  Future<void> retryDraft(GenerationDraft draft) => _run((generation) async {
    await _ensureOnlineSession();
    _ensureCurrent(generation);
    await _generate(draft, generation);
  });
  Future<List<String>> prepare(String text) async {
    final output = <String>[];
    await _run((generation) async {
      await _ensureOnlineSession();
      _ensureCurrent(generation);
      final source = requiredText(
        text,
        nativeLanguage == 'ja' ? '日本語の表現' : '表达',
        max: 4000,
      );
      final submittedInputVersion = _inputVersion;
      final existingPreparation = state.preparationDraft;
      final samePreparation =
          existingPreparation != null &&
          existingPreparation.sourceText == source &&
          existingPreparation.inputVersion == submittedInputVersion;
      final preparationId = samePreparation ? existingPreparation.id : newId();
      if (!samePreparation) {
        await _change(
          (next) => next.preparationDraft = PreparationDraft(
            id: preparationId,
            sourceText: source,
            inputVersion: submittedInputVersion,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
          ),
          sync: false,
        );
        _ensureCurrent(generation);
      }
      final result = await gateway.invoke('sentences-prepare', {
        'rawTranscript': source,
        'sourceLanguage': sourceLanguage,
        'targetLanguage': targetLanguage,
        'clientRequestId': preparationId,
      });
      _ensureCurrent(generation);
      if (_inputVersion != submittedInputVersion) {
        return;
      }
      final rawSegments = result['segments'];
      if (rawSegments is! List ||
          rawSegments.isEmpty ||
          rawSegments.length > PreparationDraft.maxSegments) {
        throw const LearningFailure('整理结果不完整，原文已保留，请修改后重试。');
      }
      final raw = mapList(rawSegments, max: PreparationDraft.maxSegments);
      final ids = <String>{};
      final segments = <PreparationSegment>[];
      for (final segment in raw) {
        final id = validId(segment['segmentId']);
        if (!ids.add(id)) {
          throw const LearningFailure('整理结果含重复分句，原文已保留，请稍后重试。');
        }
        segments.add(
          PreparationSegment(
            id: id,
            sourceText: requiredText(segment['sourceText'], '分句', max: 500),
          ),
        );
      }
      if (segments.isEmpty) {
        throw const LearningFailure('没有整理出可学习的句子，请修改文字后重试。');
      }
      final currentPreparation = state.preparationDraft;
      if (currentPreparation == null ||
          currentPreparation.id != preparationId ||
          currentPreparation.inputVersion != submittedInputVersion) {
        return;
      }
      final mergedSegments = segments.map((segment) {
        final existing = currentPreparation.segments
            .where((candidate) => candidate.id == segment.id)
            .firstOrNull;
        if (existing == null || existing.sourceText != segment.sourceText) {
          return segment;
        }
        return PreparationSegment(
          id: segment.id,
          sourceText: segment.sourceText,
          status: existing.status,
          updatedAt: existing.updatedAt,
        );
      }).toList();
      output.addAll(mergedSegments.map((segment) => segment.sourceText));
      final prepared = PreparationDraft(
        id: preparationId,
        sourceText: source,
        inputVersion: submittedInputVersion,
        segments: mergedSegments,
      );
      await _change((next) => next.preparationDraft = prepared, sync: false);
    });
    return output;
  }

  Future<void> generatePreparedSegments() => _run((generation) async {
    await _ensureOnlineSession();
    _ensureCurrent(generation);
    final account = _accountId;
    var generatedCount = 0;
    while (true) {
      final preparation = state.preparationDraft;
      if (preparation == null) {
        if (generatedCount > 0) break;
        throw const LearningFailure('请先整理并确认要生成的分句。');
      }
      if (preparation.segments.isEmpty) {
        throw const LearningFailure('请先整理并确认要生成的分句。');
      }
      final batch = preparation.pendingSegments.take(5).toList();
      if (batch.isEmpty) break;
      final submittedInputVersion = _inputVersion;
      final preparationId = preparation.id;
      final preparationInputVersion = preparation.inputVersion;
      final batchSourceById = {
        for (final segment in batch) segment.id: segment.sourceText,
      };
      final result = await gateway.invoke('sentences-batch-generate', {
        'clientRequestId': newId(),
        'sourceLanguage': preparation.sourceLanguage,
        'targetLanguage': preparation.targetLanguage,
        'segments': batch
            .asMap()
            .entries
            .map(
              (entry) => {
                'segmentId': entry.value.id,
                'orderIndex': preparation.segments.indexOf(entry.value),
                'sourceText': entry.value.sourceText,
              },
            )
            .toList(),
      });
      _sameAccount(account);
      final currentPreparation = state.preparationDraft;
      if (currentPreparation == null ||
          currentPreparation.id != preparationId ||
          currentPreparation.inputVersion != preparationInputVersion ||
          batchSourceById.entries.any((entry) {
            final segment = currentPreparation.segments
                .where((candidate) => candidate.id == entry.key)
                .firstOrNull;
            return segment == null || segment.sourceText != entry.value;
          })) {
        throw const LearningFailure('分句已发生变化，当前批次结果已保留，请检查后重试。');
      }
      final items = mapList(result['items'], max: 5);
      final batchProvenance = <String, dynamic>{
        if (result['model'] != null) 'model': result['model'],
        if (result['generationModel'] != null)
          'generationModel': result['generationModel'],
        if (result['promptVersion'] != null)
          'promptVersion': result['promptVersion'],
        if (result['sourceLanguage'] != null)
          'sourceLanguage': result['sourceLanguage'],
        if (result['targetLanguage'] != null)
          'targetLanguage': result['targetLanguage'],
      };
      if (items.length != batch.length ||
          items.map((item) => item['segmentId']).toSet().length !=
              batch.length) {
        throw const LearningFailure('返回的分句不完整，已完成的部分会保留。');
      }
      final sentences = batch.map((segment) {
        final item = items
            .where((candidate) => candidate['segmentId'] == segment.id)
            .firstOrNull;
        if (item == null) throw const FormatException('分句对应关系不正确。');
        return LearnSentence.generated(
          source: segment.sourceText,
          requestId: segment.id,
          json: {...batchProvenance, ...item},
        );
      }).toList();
      await _change((next) {
        for (final sentence in sentences) {
          next.preparationDraft?.segments
              .where((segment) => segment.id == sentence.id)
              .forEach((segment) => segment.status = 'succeeded');
          if (!next.sentences.any((existing) => existing.id == sentence.id)) {
            next.sentences.add(sentence);
            next.events.add(
              LearnEvent(
                id: newId(),
                type: 'sentence_created',
                sentenceId: sentence.id,
                metadata: {
                  'category': sentence.category,
                  'origin': sentence.origin,
                },
              ),
            );
          }
        }
        final currentPreparation = next.preparationDraft;
        if (currentPreparation != null &&
            currentPreparation.pendingSegments.isEmpty) {
          if (submittedInputVersion == _inputVersion &&
              next.todayInput.trim() == currentPreparation.sourceText.trim()) {
            next.todayInput = '';
          }
          next.preparationDraft = null;
        }
      }, generation: generation);
      _ensureCurrent(generation);
      generatedCount += sentences.length;
      for (final sentence in sentences) {
        _scheduleSentenceAudio(sentence, generation);
      }
      if (isRegistered && platformInfo['online'] != false) {
        unawaited(membership.load());
      }
    }
    notice = state.preparationDraft == null
        ? strings.generatedCount(generatedCount)
        : strings.generatedRemaining(generatedCount);
  });

  Future<String> _audioKey(LearnSentence s) async {
    final hash = await platform.invoke('contentHash', {'text': s.target});
    if (hash is! String || !RegExp(r'^[a-f0-9]{64}$').hasMatch(hash)) {
      throw const LearningFailure('浏览器无法校验音频内容。');
    }
    return singleAudioTrackKey(
      sentenceId: s.id,
      voice: state.preferences.voice,
      language: s.targetLanguage ?? currentTargetLanguage,
      contentHash: hash,
    );
  }

  bool isPlaybackFor(LearnSentence sentence) =>
      _playSentenceId == sentence.id &&
      (_playKey?.startsWith('audio:v2:sentence:${sentence.id}:') ??
          false);

  LearnSentence? get playingSentence {
    final id = _playSentenceId;
    if (id == null || playback['state'] == 'idle') return null;
    return state.sentences.where((sentence) => sentence.id == id).firstOrNull;
  }

  Future<bool> isAudioCached(LearnSentence sentence) async =>
      await platform.invoke('audioCached', {
        'accountId': _accountId,
        'key': await _audioKey(sentence),
      }) ==
      true;
  Future<void> previewSeed(LearnSentence seed, {String? voice}) async {
    if (loopActive) await pauseLoop();
    final generation = _accountGeneration;
    final previewGeneration = ++_playGeneration;
    bool current() =>
        _current(generation) && previewGeneration == _playGeneration;
    try {
      final sample = seeds
          .where((s) => s.seedId == seed.seedId && s.id == seed.id)
          .firstOrNull;
      final selectedVoice = voice ?? state.preferences.voice;
      final bundled = bundledAudio['${sample?.seedId}:$selectedVoice'];
      if (sample == null ||
          !voices.containsKey(selectedVoice) ||
          bundled is! Map ||
          bundled['path'] is! String ||
          !(bundled['path'] as String).startsWith('assets/audio/') ||
          (bundled['path'] as String).contains('..') ||
          bundled['sha256'] is! String ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(bundled['sha256'] as String)) {
        throw const LearningFailure('这条内容没有可用的内置试听。');
      }
      _playSession = null;
      _playKey = null;
      _playSentenceId = null;
      _previewKey = null;
      await platform.invoke('audioStop');
      if (!current()) return;
      error = null;
      errorCode = null;
      final key =
          'preview:${sample.seedId}:$selectedVoice:${bundled['sha256']}';
      playback = {'state': 'loading', 'positionMs': 0, 'durationMs': 0};
      notifyListeners();
      final cached = await platform.invoke('audioCached', {
        'accountId': _accountId,
        'key': key,
      });
      if (!current()) return;
      if (cached != true) {
        await platform.invoke('audioEnsure', {
          'accountId': _accountId,
          'key': key,
          'url': Uri.base.resolve('assets/${bundled['path']}').toString(),
          'sha256': bundled['sha256'],
        });
      }
      if (!current()) return;
      await platform.invoke('audioPlay', {
        'accountId': _accountId,
        'key': key,
        'speed': state.preferences.speed,
      });
      if (!current()) return;
      _previewKey = key;
      playback = {
        'state': 'playing',
        'key': key,
        'positionMs': 0,
        'durationMs': 0,
      };
    } catch (e) {
      if (current()) {
        errorCode = e is LearningFailure ? e.code : null;
        error = _message(e);
        playback = {'state': 'idle', 'positionMs': 0, 'durationMs': 0};
      }
    } finally {
      if (current()) notifyListeners();
    }
  }

  Future<void> play([LearnSentence? sentence]) => _run((generation) async {
    if (loopActive) await pauseLoop();
    await stopPlayback();
    final playbackGeneration = _playGeneration;
    void ensurePlayback() {
      _ensureCurrent(generation);
      if (playbackGeneration != _playGeneration) {
        throw const LearningFailure('播放已取消。', code: 'playback_cancelled');
      }
    }

    ensurePlayback();
    final selected = sentence ?? activeSentence ?? state.sentences.firstOrNull;
    if (selected == null) throw const LearningFailure('先选一句想听的英文。');
    final account = _accountId;
    final key = await _audioKey(selected);
    ensurePlayback();
    final voice = state.preferences.voice;
    _clearCompanionCue();
    _playSession = null;
    await platform.invoke('audioStop');
    ensurePlayback();
    activeSentence = selected;
    playback = {'state': 'loading', 'positionMs': 0, 'durationMs': 0};
    notifyListeners();
    var cached = await isAudioCached(selected);
    ensurePlayback();
    final bundled = bundledAudio['${selected.seedId}:$voice'];
    if (!cached && bundled is Map) {
      final relative = bundled['path'];
      if (relative is String &&
          relative.startsWith('assets/audio/') &&
          !relative.contains('..')) {
        await platform.invoke('audioEnsure', {
          'accountId': account,
          'key': key,
          'url': Uri.base.resolve('assets/$relative').toString(),
          'sha256': bundled['sha256'],
        });
        cached = true;
      }
    }
    if (!cached) {
      ensurePlayback();
      await _ensureOnlineSession();
      _ensureCurrent(generation);
      var manifest = state.audio[key];
      if (manifest?['manifestId'] != null) {
        manifest = await gateway.invoke('audio-download-url', {
          'manifestId': manifest!['manifestId'],
        });
      } else if (selected.seedId != null) {
        manifest = await gateway.seedAudio(selected.seedId!, voice);
      }
      if (manifest == null || manifest['status'] != 'ready') {
        ensurePlayback();
        final requestId = state.audio[key]?['requestId'] as String? ?? newId();
        await _change(
          (next) => next.audio[key] = {'requestId': requestId},
          sync: false,
          generation: generation,
        );
        ensurePlayback();
        manifest = await gateway.invoke('audio-generate', {
          'sentenceId': selected.id,
          'contractVersion': 2,
          'text': selected.target,
          'audioRole': 'target',
          'sourceLanguage': selected.sourceLanguage ?? currentSourceLanguage,
          'targetLanguage': selected.targetLanguage ?? currentTargetLanguage,
          'accent': audioAccentFor(
            voice: voice,
            language: selected.targetLanguage ?? currentTargetLanguage,
          ),
          'voiceProfile': voice,
          'reason': 'initial_generation',
          'clientRequestId': requestId,
        });
        manifest['requestId'] = requestId;
      }
      _sameAccount(account);
      ensurePlayback();
      final response = manifest;
      await _change(
        (next) => next.audio[key] = response,
        sync: false,
        generation: generation,
      );
      ensurePlayback();
      if (response['status'] != 'ready' || response['downloadUrl'] == null) {
        throw const LearningFailure('音频正在准备，请稍后再次播放。', code: 'audio_pending');
      }
      final url = requiredText(response['downloadUrl'], '音频地址');
      final uri = Uri.tryParse(url);
      if (uri == null || uri.scheme != 'https') {
        throw const FormatException('音频地址无效。');
      }
      await platform.invoke('audioEnsure', {
        'accountId': account,
        'key': key,
        'url': url,
        'sha256': response['sha256'],
      });
      cached = true;
    }
    ensurePlayback();
    if (cached) {
      await platform.invoke('audioPlay', {
        'accountId': account,
        'key': key,
        'speed': state.preferences.speed,
      });
      ensurePlayback();
      _playSession = newId();
      _playKey = key;
      _playSentenceId = selected.id;
      playback = {
        'state': 'playing',
        'key': key,
        'positionMs': 0,
        'durationMs': 0,
      };
    }
  });
  Future<void> togglePlayback() async {
    if (playback['state'] == 'playing') {
      await _run((generation) async {
        await platform.invoke('audioPause');
        _ensureCurrent(generation);
        playback['state'] = 'paused';
      });
    } else if (playback['state'] == 'paused') {
      await _run((generation) async {
        await platform.invoke('audioResume');
        _ensureCurrent(generation);
        playback['state'] = 'playing';
      });
    } else {
      await play();
    }
  }

  Future<void> seek(double milliseconds) => _run((generation) async {
    await platform.invoke('audioSeek', {'positionMs': milliseconds.round()});
  });

  Future<void> stopPlayback() async {
    final generation = _accountGeneration;
    _playGeneration++;
    _previewKey = null;
    _playSession = null;
    _playKey = null;
    _playSentenceId = null;
    playback = {'state': 'idle', 'positionMs': 0, 'durationMs': 0};
    notifyListeners();
    await platform.invoke('audioStop');
    if (_current(generation)) notifyListeners();
  }

  Future<void> _poll() async {
    if (_polling || _disposed || !initialized) return;
    final generation = _accountGeneration;
    _polling = true;
    try {
      final wasOnline = platformInfo['online'];
      platformInfo = objectMap(await platform.invoke('platformInfo'));
      if (wasOnline == false && platformInfo['online'] == true) _scheduleSync();
      final value = objectMap(await platform.invoke('audioStatus'));
      if (_loopSessionId != null) {
        loopPlayback = objectMap(
          await platform.invoke('audioLoopStatus', {
            'accountId': _accountId,
            'sessionId': _loopSessionId,
          }),
        );
        if (loopPlayback['state'] == 'ended') {
          _loopSessionId = null;
        }
      }
      _ensureCurrent(generation);
      if (_previewKey != null && value['key'] == _previewKey) {
        playback = value;
        if (value['state'] == 'ended' || value['state'] == 'error') {
          _previewKey = null;
        }
      }
      if (_playSession != null && value['key'] == _playKey) {
        playback = value;
        if (value['state'] == 'ended') {
          final eventId = _playSession!;
          final sentenceId = _playSentenceId;
          await _change((next) {
            final sentence = next.sentences
                .where((s) => s.id == sentenceId)
                .firstOrNull;
            if (sentence != null && !next.events.any((e) => e.id == eventId)) {
              LearningEngine.listen(sentence, DateTime.now());
              next.events.add(
                LearnEvent(
                  id: eventId,
                  type: 'listen_completed',
                  sentenceId: sentence.id,
                  metadata: {'duration_ms': value['durationMs'] ?? 0},
                ),
              );
            }
          }, generation: generation);
          if (_current(generation) && _playSession == eventId) {
            _playSession = null;
            if (state.events.any((event) => event.id == eventId)) {
              _showCompanionCue(SpriteActionId.listenComplete);
              if (platformInfo['online'] != false) {
                unawaited(_offerAfterLearning());
              }
            }
          }
        } else if (value['state'] == 'error') {
          _playSession = null;
          errorCode = null;
          error = '音频播放中断，请重新播放。';
        }
      }
      final now = DateTime.now();
      final today = '${now.year}-${now.month}-${now.day}';
      final clock =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      if (state.preferences.reminderEnabled &&
          state.preferences.reminderTime == clock &&
          _remindedDay != today) {
        _remindedDay = today;
        await platform.invoke('notify', {
          'title': '和 ${state.preferences.name} 学一句英文',
          'body': '留一点时间，给今天想说的话。',
        });
      }
      notifyListeners();
    } catch (e) {
      if (_current(generation)) {
        errorCode = e is LearningFailure ? e.code : null;
        error = _message(e);
        notifyListeners();
      }
    } finally {
      _polling = false;
    }
  }

  @visibleForTesting
  Future<void> poll() => _poll();

  void stagePracticeRating(LearnSentence sentence, String signal) {
    if (!['clear', 'almost', 'failed'].contains(signal)) {
      throw ArgumentError('未知自评信号。');
    }
    if (!state.sentences.any((item) => item.id == sentence.id)) {
      throw const LearningFailure('这句练习已不可用。');
    }
    _clearCompanionCue();
    _pendingPracticeSentenceId = sentence.id;
    _pendingPracticeSignal = signal;
    notifyListeners();
  }

  void clearPendingPracticeRating() {
    _pendingPracticeSentenceId = null;
    _pendingPracticeSignal = null;
    _clearCompanionCue();
    notifyListeners();
  }

  Future<void> commitPracticeRating() => _run((generation) async {
    final sentenceId = _pendingPracticeSentenceId;
    final signal = _pendingPracticeSignal;
    if (sentenceId == null || signal == null) return;
    await _commitRating(sentenceId, signal, generation);
    if (_current(generation) &&
        _pendingPracticeSentenceId == sentenceId &&
        _pendingPracticeSignal == signal) {
      _pendingPracticeSentenceId = null;
      _pendingPracticeSignal = null;
    }
  });

  Future<void> rate(LearnSentence sentence, String signal) =>
      _run((generation) async {
        await _commitRating(sentence.id, signal, generation);
      });

  Future<void> _commitRating(
    String sentenceId,
    String signal,
    int generation,
  ) async {
    _clearCompanionCue();
    await _change((next) {
      final target = next.sentences.firstWhere((s) => s.id == sentenceId);
      LearningEngine.rate(target, signal, DateTime.now());
      next.events.add(
        LearnEvent(
          id: newId(),
          type: 'practice_rated',
          sentenceId: target.id,
          metadata: {'signal': signal},
        ),
      );
    }, generation: generation);
    _ensureCurrent(generation);
    _showCompanionCue(
      signal == 'clear' ? SpriteActionId.quizGood : SpriteActionId.quizFail,
    );
    if (platformInfo['online'] != false) {
      unawaited(_offerAfterLearning());
    }
    notice = signal == 'clear' ? '记住的表达，会慢慢成为你的语言。' : '已经记下，下次会陪你再练一遍。';
  }

  Future<void> markPreviewed(List<LearnSentence> sentences) =>
      _run((generation) async {
        await _change((next) {
          final ids = sentences.map((s) => s.id).toSet();
          final at = DateTime.now();
          var changed = false;
          for (final s in next.sentences) {
            if (ids.contains(s.id) && s.previewedAt == null) {
              s.previewedAt = at;
              s.updatedAt = at;
              changed = true;
            }
          }
          if (changed) {
            next.events.add(LearnEvent(id: newId(), type: 'preview_completed'));
          }
        });
      });
  Future<bool> setVocabularyState(
    LearnSentence sentence,
    VocabularyEntry entry,
    String value, {
    String? expectedState,
  }) async {
    var saved = false;
    await _run((generation) async {
      if (!vocabularyStates.contains(value)) {
        throw const LearningFailure('词汇状态无效。');
      }
      await _change((next) {
        final s = next.sentences.firstWhere((s) => s.id == sentence.id);
        final vocabulary = s.vocabulary.firstWhere((v) => v.id == entry.id);
        if (expectedState != null && vocabulary.state != expectedState) {
          throw const LearningFailure('词汇状态已更新，无法撤销这次旧操作。');
        }
        vocabulary
          ..state = value
          ..updatedAt = DateTime.now();
        s.updatedAt = DateTime.now();
      }, generation: generation);
      _ensureCurrent(generation);
      saved = true;
    });
    return saved;
  }

  Future<void> updatePreferences({
    String? name,
    String? voice,
    String? nativeVoice,
    double? speed,
    bool? companionRailVisible,
    bool? reminderEnabled,
    String? reminderTime,

    /// Deprecated compatibility parameter.  Selecting it now changes the
    /// unified native-language choice as well.
    String? uiLocale,
    String? nativeLanguage,
  }) => _run((generation) async {
    final previousVoice = state.preferences.voice;
    final previousNativeVoice = state.preferences.nativeVoice;
    if (reminderEnabled == true) {
      final permission = await platform.invoke('requestNotifications');
      if (permission != 'granted') {
        throw const LearningFailure('提醒需要通知权限，你可以在浏览器设置中开启。');
      }
    }
    await _change((next) {
      final json = next.preferences.toJson();
      if (name != null) json['name'] = name;
      if (voice != null) json['voice'] = voice;
      if (nativeVoice != null) json['nativeVoice'] = nativeVoice;
      if (speed != null) json['speed'] = speed;
      if (companionRailVisible != null) {
        json['companionRailVisible'] = companionRailVisible;
      }
      if (reminderEnabled != null) json['reminderEnabled'] = reminderEnabled;
      if (reminderTime != null) json['reminderTime'] = reminderTime;
      final languageChoice = nativeLanguage ?? uiLocale;
      if (languageChoice != null) {
        json['nativeLanguage'] = normalizeNativeLanguage(languageChoice);
      }
      json['updatedAt'] = DateTime.now().toUtc().toIso8601String();
      next.preferences = LearnPreferences.fromJson(json);
    }, generation: generation);
    _ensureCurrent(generation);
    if (speed != null) await platform.invoke('audioSpeed', {'speed': speed});
    if (voice != null || nativeVoice != null) {
      _playSession = null;
      await platform.invoke('audioStop');
      playback['state'] = 'idle';
      if ((voice != null && voice != previousVoice) ||
          (nativeVoice != null && nativeVoice != previousNativeVoice)) {
        loopReady = false;
        _loopTracks = [];
        await stopLoop(reason: 'voiceChanged');
      }
    }
    notice = '偏好已保存。';
  });
  Future<void> login(
    String email,
    String password, {
    bool register = false,
    ResearchProfile? registrationProfile,
  }) => _run((generation) async {
        if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email.trim()) ||
            password.length < 6) {
          throw const LearningFailure('请输入有效邮箱，密码至少六位。');
        }
        try {
          if (register) {
            await gateway.signUp(
              email,
              password,
              emailRedirectTo: selahAuthRedirectUrl(),
            );
          } else {
            await gateway.signIn(email, password);
          }
        } on LearningFailure catch (failure) {
          if (failure.code != 'email_confirmation') rethrow;
          if (_current(generation)) notice = '请先通过邮件确认账户，再回来登录。';
          return;
        }
        if (gateway.userId == null) {
          notice = '注册请求已提交，请检查邮箱并确认账户后登录。';
          return;
        }
        await _switchAccount(gateway.userId!);
        final loadedGeneration = _accountGeneration;
        if (!initialized) return;
        await sync();
        _ensureCurrent(loadedGeneration);
        if (syncFailed) return;
        var profileNotice = '';
        if (register &&
            registrationProfile?.hasAnyAnswer == true &&
            isRegistered) {
          try {
            await researchProfile.load();
            if (!researchProfile.profile.hasAnyAnswer) {
              await researchProfile.save(
                registrationProfile!,
                consent: true,
              );
            }
          } catch (_) {
            profileNotice = '个人资料暂未保存，可在设置中补充。';
          }
        }
        notice = profileNotice.isEmpty
            ? '已登录，学习内容将同步到你的账户。'
            : '已登录，学习内容将同步到你的账户。$profileNotice';
        notifyListeners();
      });
  Future<void> logout() => _run((generation) async {
    await gateway.signOut();
    await _switchAccount('guest');
    notice = '已退出账户，本机学习资料仍保留。';
    notifyListeners();
  });
  Future<void> resetPassword(String email) => _run((generation) async {
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email.trim())) {
      throw const LearningFailure('请输入有效邮箱，才能发送找回密码邮件。');
    }
    await gateway.resetPassword(email, emailRedirectTo: selahAuthRedirectUrl());
    notice = '如果这个邮箱已注册，找回密码邮件很快会送到。';
  });
  Future<void> sync() async {
    if (syncing ||
        !initialized ||
        !isRegistered ||
        platformInfo['online'] == false) {
      return;
    }
    _syncTimer?.cancel();
    syncing = true;
    syncFailed = false;
    notifyListeners();
    final account = _accountId;
    final generation = _accountGeneration;
    final revision = _cloudRevision;
    final submitted = state.copy();
    try {
      final result = await gateway.synchronize(submitted.copy());
      _sameAccount(account);
      await _change(
        (next) {
          final merged = _mergeSyncResult(next, submitted, result);
          next.preferences = merged.preferences;
          next.sentences
            ..clear()
            ..addAll(merged.sentences);
          next.events
            ..clear()
            ..addAll(merged.events);
          next.memories
            ..clear()
            ..addAll(merged.memories);
          next.lastSyncAt = result.lastSyncAt;
        },
        sync: false,
        generation: generation,
      );
      if (_current(generation)) {
        _cloudDirty = _cloudRevision > revision;
        if (_cloudDirty) _scheduleSync();
      }
    } catch (e) {
      if (_current(generation)) {
        syncFailed = true;
        errorCode = e is LearningFailure ? e.code : null;
        error = _message(e, fallback: '同步未完成，本机内容已保留，联网后可以重试。');
      }
    } finally {
      if (_current(generation)) {
        syncing = false;
        notifyListeners();
      }
    }
  }

  LearningSnapshot _mergeSyncResult(
    LearningSnapshot current,
    LearningSnapshot submitted,
    LearningSnapshot result,
  ) {
    final merged = current.merge(result);
    // A successful write acknowledges the server version even when a device's
    // clock is ahead. Only edits made since submission retain their local time.
    final before = {
      for (final sentence in submitted.sentences) sentence.id: sentence,
    };
    final local = {
      for (final sentence in current.sentences) sentence.id: sentence,
    };
    final acknowledged = {
      for (final sentence in result.sentences)
        sentence.id: LearnSentence.fromJson(sentence.toJson()),
    };
    for (final entry in local.entries) {
      final original = before[entry.key];
      if (original == null ||
          jsonEncode(original.toJson()) != jsonEncode(entry.value.toJson())) {
        final sentence = LearnSentence.fromJson(entry.value.toJson());
        final server = acknowledged[entry.key];
        if (server != null && original != null) {
          final originalVocab = {for (final v in original.vocabulary) v.id: v};
          final vocab = {for (final v in server.vocabulary) v.id: v};
          for (final v in sentence.vocabulary) {
            if (originalVocab[v.id] == null ||
                jsonEncode(originalVocab[v.id]!.toJson()) !=
                    jsonEncode(v.toJson())) {
              vocab[v.id] = v;
            }
          }
          sentence.vocabulary
            ..clear()
            ..addAll(vocab.values);
        }
        acknowledged[entry.key] = sentence;
      }
    }
    merged.sentences
      ..clear()
      ..addAll(acknowledged.values);
    if (jsonEncode(current.preferences.toJson()) ==
        jsonEncode(submitted.preferences.toJson())) {
      merged.preferences = LearnPreferences.fromJson(
        result.preferences.toJson(),
      );
    } else {
      merged.preferences = LearnPreferences.fromJson(
        current.preferences.toJson(),
      );
    }
    return merged;
  }

  Future<void> exportBackup() => _run((generation) async {
    final data = state.toBackup();
    data['audio'] =
        {}; // Signed delivery URLs and account-specific cache handles are not portable backups.
    await platform.invoke('downloadBackup', {
      'filename':
          'selah-backup-${DateTime.now().toIso8601String().substring(0, 10)}.json',
      'text': const JsonEncoder.withIndent('  ').convert(data),
    });
    notice = '备份已导出，包含句子、词汇、复习进度和精灵回忆。';
  });
  Future<void> importBackup() => _run((generation) async {
    final raw = await platform.invoke('importBackup');
    if (raw == null) return;
    final imported = LearningSnapshot.importBackup(raw as String);
    await _mergeImport(imported, generation);
    notice = '备份已合并，已有记录按较新版本保留。';
  });

  Future<LearningSnapshot?> pickBackup() async {
    LearningSnapshot? picked;
    await _run((generation) async {
      final raw = await platform.invoke('importBackup');
      _ensureCurrent(generation);
      if (raw == null) return;
      final incoming = LearningSnapshot.importBackup(raw as String);
      // Keep the established account namespace validation before confirmation.
      incoming.forAccount(_accountId);
      _backupGenerations[incoming] = generation;
      picked = incoming;
    });
    return picked;
  }

  Future<void> mergeBackup(LearningSnapshot incoming) =>
      _run((generation) async {
        final pickedGeneration = _backupGenerations[incoming];
        if (pickedGeneration != null) _ensureCurrent(pickedGeneration);
        final validated = LearningSnapshot.importBackup(
          jsonEncode(incoming.toBackup()),
        );
        await _mergeImport(validated, generation);
        _ensureCurrent(generation);
        notice = '备份已合并，已有记录按较新版本保留。';
      });

  Future<LearningSnapshot?> loadGuestData() async {
    if (!hasSession || !initialized) return null;
    final generation = _accountGeneration;
    try {
      await _writes;
      _ensureCurrent(generation);
      final guest = await store.load('guest');
      _ensureCurrent(generation);
      return guest;
    } catch (e) {
      if (_current(generation)) {
        errorCode = e is LearningFailure ? e.code : null;
        error = _message(e);
        notifyListeners();
      }
      return null;
    }
  }

  Future<void> bringGuestInput() => _run((generation) async {
    if (!isRegistered) {
      notice = '当前已在本机资料中，无需导入。';
      return;
    }
    final guest = await loadGuestData();
    _ensureCurrent(generation);
    if (guest == null || guest.todayInput.isEmpty) return;
    final input = state.todayInput.isEmpty
        ? guest.todayInput
        : '${state.todayInput}\n${guest.todayInput}';
    if (input.length > 4000) {
      throw const LearningFailure('合并后的输入超过四千字，请先整理当前输入。');
    }
    updateTodayInput(input);
    await flushLocalWrites();
    _ensureCurrent(generation);
    if (!localSaveFailed) notice = '访客输入已追加，原输入仍保留在访客区。';
  });
  Future<void> _mergeImport(LearningSnapshot imported, int generation) =>
      _change((next) {
        final merged = next.merge(imported.forAccount(_accountId));
        next.preferences = merged.preferences;
        next.sentences
          ..clear()
          ..addAll(merged.sentences);
        next.events
          ..clear()
          ..addAll(merged.events);
        next.drafts
          ..clear()
          ..addAll(merged.drafts);
        next.audio
          ..clear()
          ..addAll(
            merged.audio.map((key, value) => MapEntry(key, Map.of(value))),
          );
        next.memories
          ..clear()
          ..addAll(merged.memories);
        next.todayInput = merged.todayInput;
        next.segmentInputs
          ..clear()
          ..addAll(merged.segmentInputs);
        next.preparationDraft = merged.preparationDraft == null
            ? null
            : PreparationDraft.fromJson(merged.preparationDraft!.toJson());
      }, generation: generation);
  Future<void> importGuest() => _run((generation) async {
    if (!isRegistered) {
      notice = '测试模式下已直接使用本机资料。';
      return;
    }
    await _ensureOnlineSession();
    _ensureCurrent(generation);
    final guest = await store.load('guest');
    await _mergeImport(guest, generation);
    notice = '本机学习资料已合并到当前账户。';
  });
  Future<void> install() => _run((generation) async {
    final installed = await platform.invoke('install');
    await _refreshPlatformInfo();
    notice = installed == true ? '已添加 Selah。' : '可在浏览器菜单中选择「添加到主屏幕」或「安装应用」。';
  });
  Future<void> applyUpdate() => _run((generation) async {
    await flushLocalWrites();
    _ensureCurrent(generation);
    if (hasUnsavedChanges) {
      throw const LearningFailure('请先保存本机内容，并完成录音转写或练习评分，再更新应用。');
    }
    final applied = await platform.invoke('applyUpdate');
    if (applied != true) notice = '当前已经是最新版本。';
    if (applied == true) await _refreshPlatformInfo();
  });
  Future<void> persistStorage() => _run((generation) async {
    final granted = await platform.invoke('persistentStorage');
    await _refreshPlatformInfo();
    notice = granted == true ? '浏览器已允许持久保存学习缓存。' : '浏览器暂未授予持久存储，请定期导出备份。';
  });
  Future<void> checkForUpdates() => _run((generation) async {
    final result = await platform.invoke('checkUpdate');
    await _refreshPlatformInfo();
    final info = result is Map ? Map<String, dynamic>.from(result) : const {};
    notice = switch (info['status']) {
      'available' => '有新版本可用。',
      'unsupported' => '当前浏览器不支持自动检查更新。',
      _ => '当前已经是最新版本。',
    };
  });

  Future<void> _refreshPlatformInfo() async {
    platformInfo = objectMap(await platform.invoke('platformInfo'));
    notifyListeners();
  }

  Future<void> startRecording() => _run((generation) async {
    if (loopActive) await pauseLoop();
    if (recording || hasPendingRecording) {
      throw const LearningFailure('请先完成或取消上一次录音转写。');
    }
    await _ensureOnlineSession();
    _ensureCurrent(generation);
    _clearCompanionCue();
    _playSession = null;
    await platform.invoke('audioStop');
    _ensureCurrent(generation);
    playback = {'state': 'idle', 'positionMs': 0, 'durationMs': 0};
    await platform.invoke('recordStart');
    _ensureCurrent(generation);
    _recordRequestId = newId();
    _pendingRecording = null;
    recording = true;
  });
  Future<String?> stopRecording() async {
    String? transcript;
    final startedGeneration = _accountGeneration;
    await _run((generation) async {
      final account = _accountId;
      final captured =
          _pendingRecording ?? objectMap(await platform.invoke('recordStop'));
      captured['language'] = transcriptionLanguage(nativeLanguage);
      _ensureCurrent(generation);
      _pendingRecording = captured;
      recording = false;
      notifyListeners();
      await _ensureOnlineSession();
      _ensureCurrent(generation);
      final result = await gateway.transcribe(
        _pendingRecording!,
        _recordRequestId ??= newId(),
      );
      _sameAccount(account);
      _ensureCurrent(generation);
      transcript = result;
      _pendingRecording = null;
      _recordRequestId = null;
      _showCompanionCue(SpriteActionId.recDone);
      notice = '录音已转为文字，可以修改后生成英文。';
    });
    if (_current(startedGeneration)) {
      recording = false;
      notifyListeners();
    }
    return transcript;
  }

  Future<void> cancelRecording() => _run((generation) async {
    await platform.invoke('recordCancel');
    _ensureCurrent(generation);
    _clearCompanionCue();
    recording = false;
    _pendingRecording = null;
    _recordRequestId = null;
  });
  @override
  void dispose() {
    _localInputTimer?.cancel();
    _disposed = true;
    _timer?.cancel();
    unawaited(stopLoop(reason: 'disposed'));
    _activityTimer?.cancel();
    _syncTimer?.cancel();
    _companionTimer?.cancel();
    _auth?.cancel();
    membership.dispose();
    researchProfile.dispose();
    feedbackSurvey.dispose();
    unawaited(platform.invoke('audioStop').catchError((Object _) => null));
    unawaited(platform.invoke('recordCancel').catchError((Object _) => null));
    super.dispose();
  }
}
