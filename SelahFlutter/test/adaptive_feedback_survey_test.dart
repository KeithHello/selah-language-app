import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/web/data/learning_gateway.dart';
import 'package:selah/web/domain/adaptive_feedback_survey.dart';
import 'package:selah/web/domain/learning_models.dart';
import 'package:selah/web/feedback_survey_controller.dart';
import 'package:selah/web/ui/feedback_survey_widgets.dart';

LearnEvent _event(
  String type,
  DateTime at, {
  Map<String, dynamic> metadata = const {},
}) => LearnEvent(
  id: '$type-${at.microsecondsSinceEpoch}',
  type: type,
  at: at,
  metadata: metadata,
);

List<LearnEvent> _engagedEvents(DateTime start) => [
  _event(
    'sentence_created',
    start,
    metadata: const {'origin': 'user_recording'},
  ),
  _event('listen_completed', start.add(const Duration(hours: 25))),
  _event('practice_rated', start.add(const Duration(hours: 49))),
];

void main() {
  test('does not interrupt before the first 48 hours', () {
    final start = DateTime.utc(2026, 9, 1, 9);
    expect(
      FeedbackSurveyEligibility.evaluate(
        events: _engagedEvents(start),
        now: start.add(const Duration(hours: 47, minutes: 59)),
      ),
      isNull,
    );
  });

  test('offers the engaged branch after two learning days', () {
    final start = DateTime.utc(2026, 9, 1, 9);
    expect(
      FeedbackSurveyEligibility.evaluate(
        events: _engagedEvents(start),
        now: start.add(const Duration(days: 3)),
      ),
      FeedbackSurveyStage.engaged,
    );
  });

  test('offers a lighter branch to a returning low-use learner', () {
    final start = DateTime.utc(2026, 9, 1, 9);
    final events = [
      _event(
        'sentence_created',
        start,
        metadata: const {'origin': 'user_text'},
      ),
      _event('listen_completed', start.add(const Duration(hours: 1))),
    ];
    expect(
      FeedbackSurveyEligibility.evaluate(
        events: events,
        now: start.add(const Duration(days: 5)),
      ),
      FeedbackSurveyStage.lowUse,
    );
  });

  test('respects the shown and submitted cooldowns', () {
    final start = DateTime.utc(2026, 9, 1, 9);
    final events = [
      ..._engagedEvents(start),
      _event('feedback_invite_shown', start.add(const Duration(days: 2))),
    ];
    expect(
      FeedbackSurveyEligibility.evaluate(
        events: events,
        now: start.add(const Duration(days: 10)),
      ),
      isNull,
    );
    final submitted = [
      ...events,
      _event(
        'feedback_submitted',
        start.add(const Duration(days: 2, minutes: 1)),
      ),
    ];
    expect(
      FeedbackSurveyEligibility.evaluate(
        events: submitted,
        now: start.add(const Duration(days: 61)),
      ),
      isNull,
    );
    expect(
      FeedbackSurveyEligibility.evaluate(
        events: submitted,
        now: start.add(const Duration(days: 93)),
      ),
      FeedbackSurveyStage.engaged,
    );
  });

  test('can defer when another research invite is already visible', () {
    final start = DateTime.utc(2026, 9, 1, 9);
    expect(
      FeedbackSurveyEligibility.evaluate(
        events: _engagedEvents(start),
        now: start.add(const Duration(days: 3)),
        blockedByOtherInvite: true,
      ),
      isNull,
    );
  });

  test('answer payload uses stable IDs and never stores free text', () {
    const answers = FeedbackSurveyAnswers(
      satisfaction: 4,
      scenario: 'daily_conversation',
      improvement: 'more_natural_phrasing',
      purchaseIntent: 'likely',
      planInterest: 'plus',
    );
    expect(answers.toMetadata('engaged', 'ja'), {
      'survey_version': adaptiveFeedbackSurveyVersion,
      'stage': 'engaged',
      'display_locale': 'ja',
      'satisfaction': 4,
      'scenario': 'daily_conversation',
      'improvement': 'more_natural_phrasing',
      'purchase_intent': 'likely',
      'plan_interest': 'plus',
    });
    expect(answers.isValid, isTrue);
    expect(
      const FeedbackSurveyAnswers(
        satisfaction: 4,
        scenario: 'free_text',
        improvement: 'more_natural_phrasing',
        purchaseIntent: 'likely',
      ).isValid,
      isFalse,
    );
  });

  test(
    'controller records an invite and prevents a second invite this session',
    () async {
      final gateway = _Gateway();
      final controller = FeedbackSurveyController(gateway: gateway);
      final start = DateTime.utc(2026, 9, 1, 9);
      final events = _engagedEvents(start);
      expect(
        await controller.maybeOfferAfterLearning(
          events: events,
          uiLocale: 'zh-Hans',
          now: start.add(const Duration(days: 3)),
        ),
        isTrue,
      );
      expect(controller.canShowInvite, isTrue);
      expect(gateway.eventTypes, contains('feedback_invite_shown'));
      expect(
        await controller.maybeOfferAfterLearning(
          events: events,
          uiLocale: 'zh-Hans',
          now: start.add(const Duration(days: 3, minutes: 1)),
        ),
        isFalse,
      );
      await controller.dismiss();
      expect(controller.canShowInvite, isFalse);
      expect(controller.blocksOtherInvites, isTrue);
      expect(gateway.eventTypes, contains('feedback_invite_dismissed'));
      controller.dispose();
    },
  );

  testWidgets('invite copy follows the selected mother tongue', (tester) async {
    final gateway = _Gateway();
    final controller = FeedbackSurveyController(gateway: gateway);
    controller.offeredStage = FeedbackSurveyStage.engaged;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FeedbackSurveyInvite(
            controller: controller,
            uiLocale: 'ja',
            onOpen: () {},
          ),
        ),
      ),
    );
    expect(find.text('60 秒で、もっと役立つ機能を一緒につくる'), findsOneWidget);
    expect(find.text('アンケートを始める'), findsOneWidget);
    controller.dispose();
  });
}

class _Gateway implements LearningGateway {
  final eventTypes = <String>[];

  @override
  bool get configured => true;

  @override
  String? get userId => '11111111-1111-1111-1111-111111111111';

  @override
  String? get email => 'test@example.com';

  @override
  Stream<String?> get accountChanges => const Stream.empty();

  @override
  Future<Map<String, dynamic>> invoke(
    String function,
    Map<String, dynamic> body, {
    bool get = false,
  }) async {
    if (function == 'events') eventTypes.add(body['eventType'] as String);
    return const {};
  }

  @override
  bool get isAnonymous => false;

  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signInAnonymously() async {}

  @override
  Future<void> signUp(String email, String password, {String? emailRedirectTo}) async {}

  @override
  Future<void> resetPassword(String email, {String? emailRedirectTo}) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<LearningSnapshot> synchronize(LearningSnapshot local) async => local;

  @override
  Future<Map<String, dynamic>?> seedAudio(String seedId, String voice) async =>
      null;

  @override
  Future<String> transcribe(
    Map<String, dynamic> recording,
    String requestId,
  ) async => '';
}
