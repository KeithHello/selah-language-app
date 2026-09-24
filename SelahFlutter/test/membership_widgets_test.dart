import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/web/data/learning_gateway.dart';
import 'package:selah/web/domain/learning_models.dart';
import 'package:selah/web/membership_controller.dart';
import 'package:selah/web/ui/membership_widgets.dart';

class _Gateway implements LearningGateway {
  _Gateway(this.response);
  final Map<String, dynamic> response;
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
  }) async => response;
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

void main() {
  testWidgets('free mode renders no membership information', (tester) async {
    final controller = MembershipController(
      gateway: _Gateway({
        'membershipModeEnabled': false,
        'plan': 'free',
        'status': 'none',
        'staticEntitlements': const {},
      }),
    );
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MembershipCenter(
              controller: controller,
              uiLocale: 'zh-Hans',
            ),
          ),
        ),
      ),
    );
    expect(find.byType(MembershipCenter), findsOneWidget);
    expect(find.text('当前为公开体验模式'), findsNothing);
    expect(find.textContaining('会员限制尚未开启。'), findsNothing);
    expect(find.textContaining('剩余'), findsNothing);
    controller.dispose();
  });

  testWidgets(
    'enabled mode shows static plan benefits without a balance counter',
    (tester) async {
      final controller = MembershipController(
        gateway: _Gateway({
          'membershipModeEnabled': true,
          'trialSignupsEnabled': true,
          'membershipSalesEnabled': true,
          'plan': 'free',
          'status': 'none',
        }),
      );
      await controller.load();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MembershipCenter(
                controller: controller,
                uiLocale: 'zh-Hans',
              ),
            ),
          ),
        ),
      );
      expect(find.text('月会员'), findsOneWidget);
      expect(find.text('Pro 会员'), findsOneWidget);
      expect(find.text('支付渠道待接入'), findsOneWidget);
      expect(find.text('即将开放'), findsOneWidget);
      expect(find.text('新增个人表达 300 条'), findsOneWidget);
      expect(find.textContaining('剩余'), findsNothing);
      expect(find.textContaining('已用'), findsNothing);
      controller.dispose();
    },
  );

  testWidgets('preparing trial explains the server-start condition', (
    tester,
  ) async {
    final controller = MembershipController(
      gateway: _Gateway({
        'membershipModeEnabled': true,
        'trialSignupsEnabled': true,
        'membershipSalesEnabled': true,
        'plan': 'trial',
        'status': 'trial',
        'trialState': 'preparing',
        'trialStartedAt': null,
        'trialExpiresAt': null,
      }),
    );
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MembershipCenter(
              controller: controller,
              uiLocale: 'zh-Hans',
            ),
          ),
        ),
      ),
    );
    expect(find.text('试用准备中'), findsOneWidget);
    expect(find.textContaining('首次个人表达成功保存后开始计时'), findsOneWidget);
    controller.dispose();
  });
}
