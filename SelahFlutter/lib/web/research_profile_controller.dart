import 'dart:async';

import 'package:flutter/foundation.dart';

import 'data/learning_gateway.dart';
import 'domain/research_profile.dart';

class ResearchProfileController extends ChangeNotifier {
  ResearchProfileController({required this.gateway}) {
    _accountId = gateway.userId;
    _accountSubscription = gateway.accountChanges.listen((id) {
      if (id != _accountId) {
        _accountId = id;
        _generation++;
        _reset();
        if (!_disposed) notifyListeners();
      }
      unawaited(load());
    });
  }

  static const noticeVersion = '2026-09-12-v1';

  final LearningGateway gateway;
  StreamSubscription<String?>? _accountSubscription;
  ResearchProfile profile = const ResearchProfile();
  ResearchProfilePromptState promptState = ResearchProfilePromptState.unseen;
  ResearchProfileConsentState consentState = ResearchProfileConsentState.none;
  String loadedNoticeVersion = noticeVersion;
  int revision = 0;
  bool canInvite = false;
  bool loading = false;
  bool checked = false;
  bool saving = false;
  String? error;
  bool _disposed = false;
  String? _accountId;
  int _generation = 0;

  bool get available => gateway.configured && gateway.userId != null;
  bool get hasBeenAnswered =>
      promptState == ResearchProfilePromptState.answered;
  bool get canShowInvite =>
      available && canInvite && promptState == ResearchProfilePromptState.offered;

  Future<void> load() async {
    if (_disposed) return;
    final expectedAccountId = gateway.userId;
    if (expectedAccountId != _accountId) {
      _accountId = expectedAccountId;
      _generation++;
      _reset();
    }
    final requestGeneration = _generation;
    if (!available) {
      _reset();
      checked = true;
      notifyListeners();
      return;
    }
    loading = true;
    error = null;
    notifyListeners();
    try {
      final response = await gateway.invoke('user-research-profile', {}, get: true);
      if (!_isCurrent(expectedAccountId, requestGeneration)) return;
      _apply(response);
      checked = true;
    } on LearningFailure catch (failure) {
      if (!_isCurrent(expectedAccountId, requestGeneration)) return;
      error = failure.code == 'profile_unavailable'
          ? '研究资料暂时不可用，学习不受影响。'
          : failure.message;
      checked = true;
    } catch (_) {
      if (!_isCurrent(expectedAccountId, requestGeneration)) return;
      error = '研究资料暂时无法读取，学习不受影响。';
      checked = true;
    } finally {
      if (_isCurrent(expectedAccountId, requestGeneration)) {
        loading = false;
        if (!_disposed) notifyListeners();
      }
    }
  }

  Future<bool> maybeOfferAfterLearning() async {
    if (_disposed || !available || !checked || !canInvite ||
        promptState != ResearchProfilePromptState.unseen) {
      return false;
    }
    try {
      await _mutate('offer');
      return promptState == ResearchProfilePromptState.offered;
    } catch (_) {
      return false;
    }
  }

  Future<void> save(ResearchProfile next, {required bool consent}) async {
    if (!consent) {
      throw const LearningFailure(
        '请先确认研究资料用途说明，或选择跳过。',
        code: 'profile_consent_required',
      );
    }
    await _mutate(
      'save',
      profile: next,
      noticeVersion: noticeVersion,
      researchConsent: true,
    );
  }

  Future<bool> skip() async {
    await _mutate('skip');
    return promptState == ResearchProfilePromptState.skipped;
  }

  Future<void> withdraw() async {
    await _mutate('withdraw');
  }

  Future<void> _mutate(
    String operation, {
    ResearchProfile? profile,
    String? noticeVersion,
    bool? researchConsent,
  }) async {
    if (_disposed) return;
    if (!available) {
      throw const LearningFailure('登录后才能管理研究资料。', code: 'login_required');
    }
    saving = true;
    error = null;
    final expectedAccountId = gateway.userId;
    final requestGeneration = _generation;
    notifyListeners();
    try {
      final response = await gateway.invoke('user-research-profile', {
        'operation': operation,
        ...?profile != null ? {'profile': profile.toJson()} : null,
        ...?noticeVersion != null ? {'noticeVersion': noticeVersion} : null,
        ...?researchConsent != null
            ? {'researchConsent': researchConsent}
            : null,
        'expectedRevision': revision,
      });
      if (!_isCurrent(expectedAccountId, requestGeneration)) {
        throw const LearningFailure('账户已切换，请重新操作。', code: 'account_changed');
      }
      _apply(response);
      checked = true;
    } on LearningFailure catch (failure) {
      if (_isCurrent(expectedAccountId, requestGeneration)) {
        error = failure.message;
      }
      rethrow;
    } catch (_) {
      if (_isCurrent(expectedAccountId, requestGeneration)) {
        error = '研究资料暂时无法保存，请稍后重试。';
      }
      rethrow;
    } finally {
      saving = false;
      if (!_disposed) notifyListeners();
    }
  }

  void _apply(Map<String, dynamic> response) {
    final snapshot = ResearchProfileSnapshot.fromJson(response);
    profile = snapshot.profile;
    promptState = snapshot.promptState;
    consentState = snapshot.consentState;
    loadedNoticeVersion = snapshot.noticeVersion;
    revision = snapshot.revision;
    canInvite = snapshot.canInvite;
  }

  void _reset() {
    profile = const ResearchProfile();
    promptState = ResearchProfilePromptState.unseen;
    consentState = ResearchProfileConsentState.none;
    loadedNoticeVersion = noticeVersion;
    revision = 0;
    canInvite = false;
    error = null;
  }

  bool _isCurrent(String? accountId, int generation) =>
      !_disposed && accountId == gateway.userId && generation == _generation;

  @override
  void dispose() {
    _disposed = true;
    _accountSubscription?.cancel();
    super.dispose();
  }
}
