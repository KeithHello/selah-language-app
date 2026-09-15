import 'dart:async';

import 'package:flutter/foundation.dart';

import 'data/learning_gateway.dart';
import 'domain/adaptive_feedback_survey.dart';
import 'domain/learning_models.dart';

typedef FeedbackEventRecorder =
    Future<void> Function(String eventType, Map<String, dynamic> metadata);

class FeedbackSurveyController extends ChangeNotifier {
  FeedbackSurveyController({required this.gateway, this.recordEvent}) {
    _accountId = gateway.userId;
    _accountSubscription = gateway.accountChanges.listen((id) {
      if (id != _accountId) {
        _accountId = id;
        _resetSession();
        if (!_disposed) notifyListeners();
      }
    });
  }

  final LearningGateway gateway;
  final FeedbackEventRecorder? recordEvent;
  StreamSubscription<String?>? _accountSubscription;
  FeedbackSurveyStage? offeredStage;
  String _uiLocale = defaultUiLocale;
  String? _accountId;
  bool _interactedThisSession = false;
  bool _disposed = false;

  bool get available => gateway.configured && gateway.userId != null;
  bool get canShowInvite => available && offeredStage != null;

  /// Once a learner acts on the survey, keep the other research invite out of
  /// the same session.  The server-side profile can be shown again after a
  /// fresh load if it is still eligible.
  bool get blocksOtherInvites => _interactedThisSession || offeredStage != null;

  String get uiLocale => _uiLocale;

  Future<bool> maybeOfferAfterLearning({
    required Iterable<LearnEvent> events,
    required String uiLocale,
    bool blockedByOtherInvite = false,
    DateTime? now,
  }) async {
    if (_disposed || !available || canShowInvite || _interactedThisSession) {
      return false;
    }
    final stage = FeedbackSurveyEligibility.evaluate(
      events: events,
      now: now ?? DateTime.now(),
      blockedByOtherInvite: blockedByOtherInvite,
    );
    if (stage == null) return false;
    _uiLocale = normalizeUiLocale(uiLocale);
    offeredStage = stage;
    await _record('feedback_invite_shown', {
      'survey_version': adaptiveFeedbackSurveyVersion,
      'stage': stage.name,
      'display_locale': _uiLocale,
    });
    if (!_disposed) notifyListeners();
    return true;
  }

  Future<void> dismiss() async {
    final stage = offeredStage;
    if (stage == null) return;
    _interactedThisSession = true;
    offeredStage = null;
    await _record('feedback_invite_dismissed', {
      'survey_version': adaptiveFeedbackSurveyVersion,
      'stage': stage.name,
      'display_locale': _uiLocale,
    });
    if (!_disposed) notifyListeners();
  }

  Future<void> submit(FeedbackSurveyAnswers answers) async {
    final stage = offeredStage;
    if (stage == null) {
      throw LearningFailure(_errorCopy('surveyClosed'), code: 'survey_closed');
    }
    if (!answers.isValid) {
      throw LearningFailure(
        _errorCopy('surveyIncomplete'),
        code: 'survey_incomplete',
      );
    }
    _interactedThisSession = true;
    offeredStage = null;
    await _record(
      'feedback_submitted',
      answers.toMetadata(stage.name, _uiLocale),
    );
    if (!_disposed) notifyListeners();
  }

  Future<void> viewPlan(String planId) async {
    if (!feedbackSurveyPlanInterests.contains(planId)) return;
    await _record('feedback_plan_viewed', {
      'survey_version': adaptiveFeedbackSurveyVersion,
      'stage': offeredStage?.name ?? 'completed',
      'display_locale': _uiLocale,
      'plan_id': planId,
    });
  }

  Future<void> _record(String eventType, Map<String, dynamic> metadata) async {
    try {
      if (recordEvent != null) {
        await recordEvent!(eventType, metadata);
      } else if (available) {
        await gateway.invoke('events', {
          'eventType': eventType,
          'metadata': metadata,
        });
      }
    } catch (_) {
      // A feedback prompt should remain usable when analytics is temporarily
      // unavailable.  The caller's local event recorder can retry at sync.
    }
  }

  String _errorCopy(String key) {
    if (_uiLocale == 'ja') {
      return key == 'surveyClosed'
          ? 'このアンケートは送信済みか、閉じられています。'
          : '必須項目を入力してから送信してください。';
    }
    if (_uiLocale == 'zh-Hant') {
      return key == 'surveyClosed' ? '這份問卷已提交或已關閉。' : '請完成必答項目後再提交。';
    }
    return key == 'surveyClosed' ? '这份问卷已经提交或已关闭。' : '请完成必答项后再提交。';
  }

  void _resetSession() {
    offeredStage = null;
    _uiLocale = defaultUiLocale;
    _interactedThisSession = false;
  }

  @override
  void dispose() {
    _disposed = true;
    _accountSubscription?.cancel();
    super.dispose();
  }
}
