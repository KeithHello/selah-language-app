import 'learning_models.dart';

/// Versioned contract for the adaptive feedback survey.  Answers use these
/// stable IDs so Chinese and Japanese responses can be analysed together.
const adaptiveFeedbackSurveyVersion = '2026-09-13-v1';
const feedbackSurveyScenarios = <String>{
  'daily_conversation',
  'work_or_study',
  'travel',
  'emotional_expression',
};
const feedbackSurveyImprovements = <String>{
  'simpler_onboarding',
  'more_natural_phrasing',
  'faster_audio',
  'more_review_guidance',
  'voice_and_listening',
  'long_text_workflow',
};
const feedbackSurveyPurchaseIntents = <String>{
  'now',
  'likely',
  'not_sure',
  'not_for_me',
};
const feedbackSurveyPlanInterests = <String>{'plus', 'pro', 'not_sure'};

enum FeedbackSurveyStage { engaged, lowUse }

class FeedbackSurveyAnswers {
  const FeedbackSurveyAnswers({
    required this.satisfaction,
    required this.scenario,
    required this.improvement,
    required this.purchaseIntent,
    this.planInterest,
  });

  final int satisfaction;
  final String scenario;
  final String improvement;
  final String purchaseIntent;
  final String? planInterest;

  bool get isValid =>
      satisfaction >= 1 &&
      satisfaction <= 5 &&
      feedbackSurveyScenarios.contains(scenario) &&
      feedbackSurveyImprovements.contains(improvement) &&
      feedbackSurveyPurchaseIntents.contains(purchaseIntent) &&
      (planInterest == null ||
          feedbackSurveyPlanInterests.contains(planInterest)) &&
      ((purchaseIntent == 'now' || purchaseIntent == 'likely')
          ? planInterest != null
          : planInterest == null);

  Map<String, dynamic> toMetadata(String stage, String displayLocale) => {
    'survey_version': adaptiveFeedbackSurveyVersion,
    'stage': stage,
    'display_locale': displayLocale,
    'satisfaction': satisfaction,
    'scenario': scenario,
    'improvement': improvement,
    'purchase_intent': purchaseIntent,
    if (planInterest != null) 'plan_interest': planInterest,
  };
}

/// Timing rules are intentionally pure.  This keeps product frequency
/// control testable without a browser, network, or clock mock.
class FeedbackSurveyEligibility {
  const FeedbackSurveyEligibility._();

  static const firstInviteDelay = Duration(hours: 48);
  static const lowUseInviteDelay = Duration(days: 5);
  static const shownCooldown = Duration(days: 30);
  static const submittedCooldown = Duration(days: 90);

  static FeedbackSurveyStage? evaluate({
    required Iterable<LearnEvent> events,
    required DateTime now,
    bool blockedByOtherInvite = false,
  }) {
    if (blockedByOtherInvite) return null;
    final current = now.toUtc();
    final all = events
        .where((event) => !event.at.toUtc().isAfter(current))
        .toList();
    final firstPersonal = _firstPersonalGeneration(all);
    if (firstPersonal == null) return null;

    final lastSubmitted = _latest(all, 'feedback_submitted');
    if (lastSubmitted != null &&
        current.difference(lastSubmitted).compareTo(submittedCooldown) < 0) {
      return null;
    }
    final lastShown = _latest(all, 'feedback_invite_shown');
    if (lastShown != null &&
        current.difference(lastShown).compareTo(shownCooldown) < 0) {
      return null;
    }
    final lastDismissed = _latest(all, 'feedback_invite_dismissed');
    if (lastDismissed != null &&
        current.difference(lastDismissed).compareTo(shownCooldown) < 0) {
      return null;
    }

    final age = current.difference(firstPersonal);
    if (age.isNegative) return null;
    final learningActions = all.where(
      (event) =>
          (event.type == 'listen_completed' ||
              event.type == 'practice_rated') &&
          !event.at.toUtc().isBefore(firstPersonal),
    );
    if (learningActions.isEmpty) return null;
    final activeDays = learningActions
        .map((event) => _dayKey(event.at))
        .toSet()
        .length;
    if (activeDays >= 2 && age.compareTo(firstInviteDelay) >= 0) {
      return FeedbackSurveyStage.engaged;
    }
    if (activeDays == 1 && age.compareTo(lowUseInviteDelay) >= 0) {
      return FeedbackSurveyStage.lowUse;
    }
    return null;
  }

  static DateTime? _firstPersonalGeneration(Iterable<LearnEvent> events) {
    final dates = events
        .where(
          (event) =>
              event.type == 'sentence_created' &&
              event.metadata['origin'] != 'seed',
        )
        .map((event) => event.at.toUtc())
        .toList();
    if (dates.isEmpty) return null;
    dates.sort();
    return dates.first;
  }

  static DateTime? _latest(Iterable<LearnEvent> events, String type) {
    DateTime? latest;
    for (final event in events.where((item) => item.type == type)) {
      final at = event.at.toUtc();
      if (latest == null || at.isAfter(latest)) latest = at;
    }
    return latest;
  }

  static String _dayKey(DateTime at) {
    final date = at.toUtc();
    return '${date.year}-${date.month}-${date.day}';
  }
}
