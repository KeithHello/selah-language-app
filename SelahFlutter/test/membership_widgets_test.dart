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

Map<String, dynamic> _monthlyStatus({int sentenceRemaining = 19}) {
  final now = DateTime.now().toUtc();
  final periodStart = now.subtract(const Duration(days: 18));
  final periodEnd = now.add(const Duration(days: 12, hours: 12));
  return {
    'membershipModeEnabled': true,
    'trialSignupsEnabled': true,
    'membershipSalesEnabled': true,
    'paymentProviderConfigured': true,
    'proSalesEnabled': false,
    'plan': 'monthly',
    'status': 'active',
    'periodStartsAt': periodStart.toIso8601String(),
    'periodEndsAt': periodEnd.toIso8601String(),
    'membershipSource': 'paid',
    'usage': {
      'asOf': '2026-09-28T00:00:00.000Z',
      'sentences': {
        'used': sentenceRemaining == 0 ? 300 : 281,
        'limit': 300,
        'remaining': sentenceRemaining,
      },
      'ttsCharacters': {'used': 27150, 'limit': 30000, 'remaining': 2850},
      'transcriptionMs': {
        'used': 3360000,
        'limit': 3600000,
        'remaining': 240000,
      },
      'preparations': {'used': 28, 'limit': 30, 'remaining': 2},
    },
    'futurePeriods': [],
  };
}

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

Future<void> _pumpCard(
  WidgetTester tester,
  MembershipController controller, {
  String uiLocale = 'zh-Hans',
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: MembershipStatusCard(
            controller: controller,
            uiLocale: uiLocale,
          ),
        ),
      ),
    ),
  );
}

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
    await _pumpCard(tester, controller);
    await tester.pumpAndSettle();

    expect(find.text('未开通'), findsOneWidget);
    expect(find.text('当前未开通会员，学习不受限制。'), findsOneWidget);
    expect(find.text('更改方案'), findsNothing);
    expect(find.textContaining('本期用量'), findsNothing);
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
    await _pumpCard(tester, controller);
    await tester.pumpAndSettle();

    expect(find.text('月会员'), findsOneWidget);
    expect(find.textContaining('本期用量'), findsOneWidget);
    expect(find.text('剩 19 条'), findsOneWidget);
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
    await _pumpCard(tester, controller);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('月会员'), findsNothing);
    // The gateway delay runs in fake async time; advance it with pump.
    await tester.pump(const Duration(milliseconds: 100));
    await loadFuture;
    await tester.pumpAndSettle();
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
    await _pumpCard(tester, controller);
    await tester.pumpAndSettle();

    expect(find.text('会员状态暂时无法读取，请稍后重试。'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(find.text('剩 19 条'), findsNothing);
    expect(find.text('剩 2850 字符'), findsNothing);
    controller.dispose();
  });

  testWidgets('monthly status shows balances with progress meters', (
    tester,
  ) async {
    final controller = MembershipController(
      gateway: _Gateway(status: _monthlyStatus()),
    );
    await controller.load();
    await _pumpCard(tester, controller);
    await tester.pumpAndSettle();

    expect(find.text('月会员'), findsOneWidget);
    expect(find.text('付费'), findsOneWidget);
    expect(find.textContaining('本期用量'), findsOneWidget);
    expect(find.textContaining('还剩 12 天'), findsOneWidget);
    expect(find.text('已用 281 / 300 条'), findsOneWidget);
    expect(find.text('剩 19 条'), findsOneWidget);
    expect(find.text('剩 2850 字符'), findsOneWidget);
    expect(find.text('剩 4 分钟'), findsOneWidget);
    expect(find.text('剩 2 次'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.textContaining('%'), findsNothing);
    final bar = tester.widget<FractionallySizedBox>(
      find
          .descendant(
            of: find.byKey(const ValueKey<String>('quota-bar-sentences')),
            matching: find.byType(FractionallySizedBox),
          )
          .first,
    );
    expect(bar.widthFactor, closeTo(281 / 300, 0.001));
    controller.dispose();
  });

  testWidgets('zero balance is explicit only on the exhausted feature', (
    tester,
  ) async {
    final controller = MembershipController(
      gateway: _Gateway(status: _monthlyStatus(sentenceRemaining: 0)),
    );
    await controller.load();
    await _pumpCard(tester, controller);
    await tester.pumpAndSettle();

    expect(find.text('本账期已用完'), findsOneWidget);
    expect(find.text('已用 300 / 300 条'), findsOneWidget);
    expect(find.text('剩 2850 字符'), findsOneWidget);
    expect(find.text('剩 4 分钟'), findsOneWidget);
    expect(find.text('剩 2 次'), findsOneWidget);
    final bar = tester.widget<FractionallySizedBox>(
      find
          .descendant(
            of: find.byKey(const ValueKey<String>('quota-bar-sentences')),
            matching: find.byType(FractionallySizedBox),
          )
          .first,
    );
    expect(bar.widthFactor, 1.0);
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
    await _pumpCard(tester, controller);
    await tester.pumpAndSettle();

    expect(find.text('试用准备中'), findsOneWidget);
    expect(find.textContaining('首次个人表达成功保存后开始计时'), findsOneWidget);
    expect(find.textContaining('本期用量'), findsNothing);
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
    await _pumpCard(tester, controller);
    await tester.pumpAndSettle();

    expect(find.text('未开通'), findsOneWidget);
    expect(find.text('试用尚未开始'), findsOneWidget);
    expect(find.textContaining('不会因注册或登录提前计时'), findsOneWidget);
    expect(find.textContaining('本期用量'), findsNothing);
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
    await _pumpCard(tester, controller);
    await tester.pumpAndSettle();

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

  testWidgets('active period with missing usage shows a retry hint', (
    tester,
  ) async {
    final status = _monthlyStatus();
    status['usage'] = null;
    final controller = MembershipController(gateway: _Gateway(status: status));
    await controller.load();
    await _pumpCard(tester, controller);
    await tester.pumpAndSettle();

    expect(find.text('月会员'), findsOneWidget);
    expect(find.text('额度信息暂时无法读取，请稍后重试。'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(find.textContaining('本期用量'), findsNothing);
    controller.dispose();
  });

  testWidgets('usage retry restores balances after the gateway recovers', (
    tester,
  ) async {
    final gateway = _Gateway(status: _monthlyStatus());
    final controller = MembershipController(gateway: gateway);
    await controller.load();
    final degraded = _monthlyStatus();
    degraded['usage'] = null;
    gateway.status = degraded;
    await controller.load();
    await _pumpCard(tester, controller);
    await tester.pumpAndSettle();

    expect(find.text('额度信息暂时无法读取，请稍后重试。'), findsOneWidget);
    gateway.status = _monthlyStatus();
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();

    expect(find.textContaining('本期用量'), findsOneWidget);
    expect(find.text('剩 19 条'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('usage fallback copy follows the interface locale', (
    tester,
  ) async {
    final status = _monthlyStatus();
    status['usage'] = null;
    final controller = MembershipController(gateway: _Gateway(status: status));
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MembershipStatusCard(
              controller: controller,
              uiLocale: 'ja',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('利用量の情報を読み込めません。しばらくしてからもう一度お試しください。'),
      findsOneWidget,
    );
    controller.dispose();
  });

  testWidgets('quota help button opens an explanation dialog', (tester) async {
    final controller = MembershipController(
      gateway: _Gateway(status: _monthlyStatus()),
    );
    await controller.load();
    await _pumpCard(tester, controller);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.help_outline_rounded).first);
    await tester.pumpAndSettle();
    expect(
      find.text(
        '写下今天的母语句子，生成对应的英语学习内容；每成功生成一条，计一次。长文整理后确认生成的句子，也按条计入这里。',
      ),
      findsOneWidget,
    );
    expect(find.text('关闭'), findsOneWidget);

    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        '写下今天的母语句子，生成对应的英语学习内容；每成功生成一条，计一次。长文整理后确认生成的句子，也按条计入这里。',
      ),
      findsNothing,
    );
    controller.dispose();
  });

  testWidgets('quota help copy explains both preparation counting layers', (
    tester,
  ) async {
    final copies = [
      {
        'locale': 'zh-Hans',
        'close': '关闭',
        'sentences': '写下今天的母语句子，生成对应的英语学习内容；每成功生成一条，计一次。长文整理后确认生成的句子，也按条计入这里。',
        'tts': '为英语和母语句子合成语音；按新增配音的字符数计。',
        'transcription': '把「说出来」的录音转成文字；按录音时长计。',
        'preparations':
            '超过直接生成长度的长文，先自动分段整理再逐段生成；每整理一次计一次。整理本身不消耗个人表达条数；确认生成时，按实际保存的条数计入个人表达。',
      },
      {
        'locale': 'zh-Hant',
        'close': '關閉',
        'sentences': '寫下今天的母語句子，產生對應的英語學習內容；每成功產生一條，計一次。長文整理後確認產生的句子，也按條計入這裡。',
        'tts': '為英語和母語句子合成語音；按新增配音的字元數計。',
        'transcription': '把「說出來」的錄音轉成文字；按錄音時長計。',
        'preparations':
            '超過直接產生長度的長文，先自動分段整理再逐段產生；每整理一次計一次。整理本身不消耗個人表達條數；確認產生時，按實際保存的條數計入個人表達。',
      },
      {
        'locale': 'ja',
        'close': '閉じる',
        'sentences':
            '今日の母語の文を書くと、対応する英語学習コンテンツを生成します。生成 1 件ごとにカウントします。長文整理で確認生成した文も、ここに 1 文ずつカウントされます。',
        'tts': '英語と母語の文の音声を合成します。新規音声の文字数でカウントします。',
        'transcription': '話した録音を文字に起こします。録音時間でカウントします。',
        'preparations':
            '直接生成できる長さを超える長文は、先に分割して整理してから生成します。整理 1 回ごとにカウントします。整理自体は個人表現の件数を消費せず、確認生成時に実際に保存した文数が個人表現としてカウントされます。',
      },
    ];

    for (final copy in copies) {
      final controller = MembershipController(
        gateway: _Gateway(status: _monthlyStatus()),
      );
      await controller.load();
      await _pumpCard(tester, controller, uiLocale: copy['locale']!);
      await tester.pumpAndSettle();

      for (final index in [0, 1, 2, 3]) {
        await tester.tap(find.byIcon(Icons.help_outline_rounded).at(index));
        await tester.pumpAndSettle();
        final helpKey = [
          'sentences',
          'tts',
          'transcription',
          'preparations',
        ][index];
        expect(find.text(copy[helpKey]!), findsOneWidget);
        await tester.tap(find.text(copy['close']!));
        await tester.pumpAndSettle();
      }

      controller.dispose();
    }
  });

  testWidgets('usage grid switches between two columns and one column', (
    tester,
  ) async {
    final controller = MembershipController(
      gateway: _Gateway(status: _monthlyStatus()),
    );
    await controller.load();
    await _pumpCard(tester, controller);
    await tester.pumpAndSettle();

    final icons = find.byIcon(Icons.help_outline_rounded);
    expect(icons, findsNWidgets(4));
    final wideFirst = tester.getCenter(icons.at(0)).dy;
    final wideSecond = tester.getCenter(icons.at(1)).dy;
    expect(wideSecond, wideFirst);

    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpAndSettle();

    final narrowFirst = tester.getCenter(icons.at(0)).dy;
    final narrowSecond = tester.getCenter(icons.at(1)).dy;
    expect(narrowSecond, greaterThan(narrowFirst));
    controller.dispose();
  });
}
