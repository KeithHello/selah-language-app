import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/web/data/learning_gateway.dart';
import 'package:selah/web/domain/learning_models.dart';
import 'package:selah/web/domain/membership.dart';
import 'package:selah/web/membership_controller.dart';

class MockGateway implements LearningGateway {
  MockGateway({
    this.userId = 'user-123',
    this.mockResponse,
    this.previewFails = false,
  });
  @override
  bool get configured => true;
  @override
  final String? userId;
  @override
  String? get email => 'test@example.com';
  @override
  Stream<String?> get accountChanges => const Stream.empty();
  final Map<String, dynamic>? mockResponse;
  bool previewFails;
  final calls = <({String function, Map<String, dynamic> body, bool get})>[];

  @override
  Future<Map<String, dynamic>> invoke(
    String function,
    Map<String, dynamic> body, {
    bool get = false,
  }) async {
    calls.add((function: function, body: body, get: get));
    if (function == 'membership-plan-preview' && previewFails) {
      throw const LearningFailure('Network error', code: 'network_error');
    }
    if (mockResponse != null) return mockResponse!;
    throw const LearningFailure('Network error', code: 'network_error');
  }

  @override
  bool get isAnonymous => false;

  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signUp(
    String email,
    String password, {
    String? emailRedirectTo,
  }) async {}
  @override
  Future<void> resetPassword(String email, {String? emailRedirectTo}) async {}
  @override
  Future<void> updatePassword(String newPassword) async {}
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

void main() {
  test('missing server usage remains null instead of becoming zero', () {
    final summary = MembershipSummary.fromJson({
      'plan': 'monthly',
      'status': 'active',
      'usage': null,
    });

    expect(summary.usage, isNull);
  });

  test('membership usage keeps the server remaining value', () {
    final summary = MembershipSummary.fromJson({
      'plan': 'monthly',
      'status': 'active',
      'usage': {
        'asOf': '2026-09-28T00:00:00.000Z',
        'sentences': {'used': 5, 'limit': 30, 'remaining': 19},
        'ttsCharacters': {'used': 150, 'limit': 3000, 'remaining': 2850},
        'transcriptionMs': {
          'used': 60000,
          'limit': 300000,
          'remaining': 240000,
        },
        'preparations': {'used': 1, 'limit': 3, 'remaining': 2},
      },
      'futurePeriods': [
        {
          'id': 'future-1',
          'plan': 'monthly',
          'source': 'grant',
          'startsAt': '2026-10-01T00:00:00.000Z',
          'endsAt': '2026-11-01T00:00:00.000Z',
        },
      ],
    });

    expect(summary.usage!.sentences.remaining, 19);
    expect(summary.futurePeriods.single.plan, MembershipPlan.monthly);
    expect(summary.futurePeriods.single.source, MembershipSource.grant);
  });

  test('loads server-owned plan quotes with an empty request body', () async {
    final gateway = MockGateway(
      mockResponse: {
        'quotes': [
          {
            'action': 'upgrade_pro_now',
            'chargeFenCny': 601,
            'effectiveAt': '2026-09-28T00:00:00.000Z',
            'currentPeriodEffect': 'replace_remainder',
            'limitsAfter': {
              'maxSentences': 90,
              'maxTtsCharacters': 9007,
              'maxTranscriptionMs': 1080900,
              'maxPreparations': 9,
            },
            'usageAfter': {
              'asOf': '2026-09-28T00:00:00.000Z',
              'sentences': {'used': 10, 'limit': 90, 'remaining': 80},
              'ttsCharacters': {'used': 150, 'limit': 9007, 'remaining': 8857},
              'transcriptionMs': {
                'used': 60000,
                'limit': 1080900,
                'remaining': 1020900,
              },
              'preparations': {'used': 1, 'limit': 9, 'remaining': 8},
            },
            'futurePeriods': [],
            'warnings': ['future_periods_unchanged'],
            'unavailableReason': 'pro_sales_disabled',
          },
        ],
      },
    );
    final controller = MembershipController(gateway: gateway);

    await controller.loadPlanPreview();

    expect(gateway.calls.single.function, 'membership-plan-preview');
    expect(gateway.calls.single.body, isEmpty);
    expect(gateway.calls.single.get, isFalse);
    expect(controller.planPreviewFailed, isFalse);
    expect(controller.planQuotes.single.action, 'upgrade_pro_now');
    expect(controller.planQuotes.single.chargeFenCny, 601);
    expect(controller.planQuotes.single.usageAfter!.sentences.remaining, 80);
    expect(
      controller.planQuotes.single.unavailableReason,
      'pro_sales_disabled',
    );
    controller.dispose();
  });

  test('preview failure clears prior quote data', () async {
    final gateway = MockGateway(
      mockResponse: {
        'quotes': [
          {
            'action': 'extend_monthly',
            'chargeFenCny': 3990,
            'effectiveAt': '2026-10-28T00:00:00.000Z',
            'currentPeriodEffect': 'schedule_after',
            'futurePeriods': [],
            'warnings': [],
            'unavailableReason': null,
          },
        ],
      },
    );
    final controller = MembershipController(gateway: gateway);
    await controller.loadPlanPreview();
    expect(controller.planQuotes, hasLength(1));

    gateway.previewFails = true;
    await controller.loadPlanPreview();

    expect(controller.planPreviewFailed, isTrue);
    expect(controller.planQuotes, isEmpty);
    controller.dispose();
  });

  test('parses active monthly membership summary cleanly', () {
    final summary = MembershipSummary.fromJson({
      'plan': 'monthly',
      'status': 'active',
      'periodStartsAt': '2026-09-10T00:00:00.000Z',
      'periodEndsAt': '2026-10-10T00:00:00.000Z',
      'membershipSource': 'paid',
      'nextPeriodStartsAt': '2026-10-10T00:00:00.000Z',
      'nextPeriodSource': 'paid',
      'renewalMode': 'manual',
      'entitlementVersion': 'monthly-v1',
      'modelDisclosure': 'openai-gpt-4o-mini-v1',
      'staticEntitlements': {
        'maxSentences': 300,
        'maxTtsCharacters': 30000,
        'maxTranscriptionMs': 3600000,
        'maxPreparations': 30,
      },
    });

    expect(summary.plan, MembershipPlan.monthly);
    expect(summary.status, MembershipStatus.active);
    expect(summary.isPaidActive, isTrue);
    expect(summary.hasActiveEntitlements, isTrue);
    expect(summary.staticEntitlements.maxSentences, 300);
    expect(summary.staticEntitlements.maxTtsCharacters, 30000);
  });

  test('MembershipController loads status and updates state', () async {
    final gateway = MockGateway(
      mockResponse: {
        'plan': 'monthly',
        'status': 'active',
        'periodStartsAt': '2026-09-10T00:00:00.000Z',
        'periodEndsAt': '2026-10-10T00:00:00.000Z',
        'membershipSource': 'paid',
        'staticEntitlements': {
          'maxSentences': 300,
          'maxTtsCharacters': 30000,
          'maxTranscriptionMs': 3600000,
          'maxPreparations': 30,
        },
      },
    );
    final controller = MembershipController(gateway: gateway);
    await controller.load();
    expect(controller.checked, isTrue);
    expect(controller.loading, isFalse);
    expect(controller.summary.isPaidActive, isTrue);
    expect(controller.error, isNull);
    controller.dispose();
  });

  test('preserves the server trial source instead of labeling it paid', () {
    final summary = MembershipSummary.fromJson({
      'plan': 'trial',
      'status': 'trial',
      'membershipSource': 'system_trial',
      'periodStartsAt': '2026-09-10T00:00:00.000Z',
      'periodEndsAt': '2026-09-17T00:00:00.000Z',
      'staticEntitlements': {
        'maxSentences': 30,
        'maxTtsCharacters': 3000,
        'maxTranscriptionMs': 300000,
        'maxPreparations': 3,
      },
    });

    expect(summary.membershipSource, MembershipSource.systemTrial);
    expect(summary.isTrialActive, isTrue);
  });

  test('parses an unstarted or preparing trial without inventing dates', () {
    final summary = MembershipSummary.fromJson({
      'plan': 'trial',
      'status': 'trial',
      'trialState': 'preparing',
      'trialStartedAt': null,
      'trialExpiresAt': null,
    });
    expect(summary.trialState, TrialState.preparing);
    expect(summary.trialStartedAt, isNull);
    expect(summary.trialExpiresAt, isNull);
  });

  test(
    'parses a server-gated Pro contract without enabling checkout by default',
    () {
      final summary = MembershipSummary.fromJson({
        'plan': 'pro',
        'status': 'active',
        'proSalesEnabled': false,
        'proPriceFenCny': 9990,
        'proEntitlements': {
          'maxSentences': 900,
          'maxTtsCharacters': 90000,
          'maxTranscriptionMs': 10800000,
          'maxPreparations': 90,
        },
      });
      expect(summary.plan, MembershipPlan.pro);
      expect(summary.isPaidActive, isTrue);
      expect(summary.proSalesEnabled, isFalse);
      expect(summary.proPriceFenCny, 9990);
      expect(summary.proEntitlements.maxPreparations, 90);
    },
  );

  test(
    'keeps all checkout paths disabled until a provider is configured',
    () async {
      final controller = MembershipController(
        gateway: MockGateway(
          mockResponse: {
            'membershipModeEnabled': true,
            'membershipSalesEnabled': true,
            'proSalesEnabled': true,
            'paymentProviderConfigured': false,
            'plan': 'free',
            'status': 'none',
          },
        ),
      );
      await controller.load();
      expect(controller.membershipSalesAvailable, isFalse);
      expect(controller.proSalesAvailable, isFalse);
      await controller.startMonthlyCheckout();
      expect(controller.error, '支付渠道尚未配置，暂未开放。');
      controller.dispose();
    },
  );
}
