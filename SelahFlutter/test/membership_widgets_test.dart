import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/web/data/learning_gateway.dart';
import 'package:selah/web/domain/learning_models.dart';
import 'package:selah/web/membership_controller.dart';
import 'package:selah/web/ui/membership_widgets.dart';

class _Gateway implements LearningGateway {
  _Gateway({required this.status, this.preview, this.delay});

  Map<String, dynamic> status;
  final Map<String, dynamic>? preview;
  final Duration? delay;
  bool statusFails = false;

  @override
  bool get configured => true;
  @override
  String? get userId => '11111111-1111-1111-1111-111111111111';
  @override
  String? get email => 'tester@example.com';
  @override
  Stream<String?> get accountChanges => const Stream.empty();
  @override
  Future<Map<String, dynamic>> invoke(
    String function,
    Map<String, dynamic> body, {
    bool get = false,
  }) async {
    if (delay != null) await Future.delayed(delay!);
    if (function == 'membership-plan-preview') {
      return preview ?? {'quotes': []};
    }
    if (statusFails) {
      throw const LearningFailure('status unavailable', code: 'network_error');
    }
    return status;
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

Map<String, dynamic> _monthlyStatus({int sentenceRemaining = 19}) => {
  'membershipModeEnabled': true,
  'trialSignupsEnabled': true,
  'membershipSalesEnabled': true,
  'paymentProviderConfigured': true,
  'proSalesEnabled': false,
  'plan': 'monthly',
  'status': 'active',
  'periodStartsAt': '2026-09-01T00:00:00.000Z',
  'periodEndsAt': '2026-10-01T00:00:00.000Z',
  'membershipSource': 'paid',
  'usage': {
    'asOf': '2026-09-28T00:00:00.000Z',
    'sentences': {
      'used': sentenceRemaining == 0 ? 300 : 281,
      'limit': 300,
      'remaining': sentenceRemaining,
    },
    'ttsCharacters': {'used': 27150, 'limit': 30000, 'remaining': 2850},
    'transcriptionMs': {'used': 3360000, 'limit': 3600000, 'remaining': 240000},
    'preparations': {'used': 28, 'limit': 30, 'remaining': 2},
  },
  'futurePeriods': [],
};

Map<String, dynamic> _quote({
  required String action,
  required int chargeFenCny,
  required String effectiveAt,
  required String currentPeriodEffect,
  String? unavailableReason,
}) => {
  'action': action,
  'chargeFenCny': chargeFenCny,
  'effectiveAt': effectiveAt,
  'currentPeriodEffect': currentPeriodEffect,
  'limitsAfter': null,
  'usageAfter': null,
  'futurePeriods': [],
  'warnings': [],
  'unavailableReason': unavailableReason,
};

void main() {
  testWidgets('membership mode off keeps the card visible for free accounts', (
    tester,
  ) async {
    final controller = MembershipController(
      gateway: _Gateway(
        status: {
          'membershipModeEnabled': false,
          'plan': 'free',
          'status': 'none',
        },
      ),
    );
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MembershipStatusCard(
            controller: controller,
            uiLocale: 'zh-Hans',
          ),
        ),
      ),
    );

    expect(find.text('会员'), findsOneWidget);
    expect(find.text('未开通'), findsOneWidget);
    expect(find.text('当前未开通会员，学习不受限制。'), findsOneWidget);
    expect(find.text('更改方案'), findsNothing);
    expect(find.text('本账期剩余'), findsNothing);
    expect(find.text('0'), findsNothing);
    controller.dispose();
  });

  testWidgets('membership mode off keeps identity and remaining balances', (
    tester,
  ) async {
    final status = _monthlyStatus();
    status['membershipModeEnabled'] = false;
    final controller = MembershipController(gateway: _Gateway(status: status));
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MembershipStatusCard(
            controller: controller,
            uiLocale: 'zh-Hans',
          ),
        ),
      ),
    );

    expect(find.text('月会员'), findsOneWidget);
    expect(find.text('本账期剩余'), findsOneWidget);
    expect(find.text('19 条'), findsOneWidget);
    expect(find.text('会员额度限制尚未对所有用户开启，当前不会按额度限制你的学习。'), findsOneWidget);
    expect(find.text('更改方案'), findsNothing);
    controller.dispose();
  });

  testWidgets('first load keeps the card visible with a loading indicator', (
    tester,
  ) async {
    final gateway = _Gateway(
      status: _monthlyStatus(),
      delay: const Duration(milliseconds: 50),
    );
    final controller = MembershipController(gateway: gateway);
    final loadFuture = controller.load();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MembershipStatusCard(
            controller: controller,
            uiLocale: 'zh-Hans',
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('会员'), findsOneWidget);
    // The gateway delay runs in fake async time; advance it with pump.
    await tester.pump(const Duration(milliseconds: 100));
    await loadFuture;
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('月会员'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('failed status refresh offers a retry action', (tester) async {
    final gateway = _Gateway(status: _monthlyStatus());
    final controller = MembershipController(gateway: gateway);
    await controller.load();
    gateway.statusFails = true;
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MembershipStatusCard(
            controller: controller,
            uiLocale: 'zh-Hans',
          ),
        ),
      ),
    );

    expect(find.text('会员状态暂时无法读取，请稍后重试。'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(find.text('19 条'), findsNothing);
    expect(find.text('2850 字符'), findsNothing);
    controller.dispose();
  });

  testWidgets('monthly status shows server balances without progress meters', (
    tester,
  ) async {
    final controller = MembershipController(
      gateway: _Gateway(status: _monthlyStatus()),
    );
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MembershipStatusCard(
            controller: controller,
            uiLocale: 'zh-Hans',
          ),
        ),
      ),
    );

    expect(find.text('月会员'), findsOneWidget);
    expect(find.text('付费'), findsOneWidget);
    expect(find.text('本账期剩余'), findsOneWidget);
    expect(find.text('19 条'), findsOneWidget);
    expect(find.text('2850 字符'), findsOneWidget);
    expect(find.text('4 分钟'), findsOneWidget);
    expect(find.text('2 次'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.textContaining('%'), findsNothing);
    controller.dispose();
  });

  testWidgets('zero balance is explicit only on the exhausted feature', (
    tester,
  ) async {
    final controller = MembershipController(
      gateway: _Gateway(status: _monthlyStatus(sentenceRemaining: 0)),
    );
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MembershipStatusCard(
            controller: controller,
            uiLocale: 'zh-Hans',
          ),
        ),
      ),
    );

    expect(find.text('本账期已用完'), findsOneWidget);
    expect(find.text('2850 字符'), findsOneWidget);
    expect(find.text('4 分钟'), findsOneWidget);
    expect(find.text('2 次'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('preparing trial keeps its existing start-condition copy', (
    tester,
  ) async {
    final controller = MembershipController(
      gateway: _Gateway(
        status: {
          'membershipModeEnabled': true,
          'trialSignupsEnabled': true,
          'plan': 'trial',
          'status': 'trial',
          'trialState': 'preparing',
          'trialStartedAt': null,
          'trialExpiresAt': null,
          'usage': null,
        },
      ),
    );
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MembershipStatusCard(
            controller: controller,
            uiLocale: 'zh-Hans',
          ),
        ),
      ),
    );

    expect(find.text('试用准备中'), findsOneWidget);
    expect(find.textContaining('首次个人表达成功保存后开始计时'), findsOneWidget);
    expect(find.text('本账期剩余'), findsNothing);
    controller.dispose();
  });

  testWidgets('eligible unstarted trial is explained before first membership', (
    tester,
  ) async {
    final controller = MembershipController(
      gateway: _Gateway(
        status: {
          'membershipModeEnabled': true,
          'trialSignupsEnabled': true,
          'plan': 'free',
          'status': 'none',
          'trialState': 'not_started',
          'usage': null,
        },
      ),
    );
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MembershipStatusCard(
            controller: controller,
            uiLocale: 'zh-Hans',
          ),
        ),
      ),
    );

    expect(find.text('未开通'), findsOneWidget);
    expect(find.text('试用尚未开始'), findsOneWidget);
    expect(find.textContaining('不会因注册或登录提前计时'), findsOneWidget);
    expect(find.text('本账期剩余'), findsNothing);
    controller.dispose();
  });

  testWidgets('change-plan sheet disables Pro and offers only legal actions', (
    tester,
  ) async {
    final controller = MembershipController(
      gateway: _Gateway(
        status: _monthlyStatus(),
        preview: {
          'quotes': [
            _quote(
              action: 'upgrade_pro_now',
              chargeFenCny: 601,
              effectiveAt: '2026-09-28T00:00:00.000Z',
              currentPeriodEffect: 'replace_remainder',
              unavailableReason: 'pro_sales_disabled',
            ),
            _quote(
              action: 'extend_monthly',
              chargeFenCny: 3990,
              effectiveAt: '2026-10-01T00:00:00.000Z',
              currentPeriodEffect: 'schedule_after',
            ),
          ],
        },
      ),
    );
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MembershipStatusCard(
            controller: controller,
            uiLocale: 'zh-Hans',
          ),
        ),
      ),
    );

    await tester.tap(find.text('更改方案'));
    await tester.pumpAndSettle();

    expect(find.text('升级到 Pro'), findsNWidgets(2));
    expect(find.text('再购买一个月会员'), findsNWidgets(2));
    expect(find.text('Pro 购买尚未开放。'), findsOneWidget);
    expect(find.textContaining('降级'), findsNothing);
    final proButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '升级到 Pro'),
    );
    expect(proButton.onPressed, isNull);
    controller.dispose();
  });
}
