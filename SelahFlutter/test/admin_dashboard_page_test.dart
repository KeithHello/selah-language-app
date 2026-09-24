import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/design/selah_theme.dart';
import 'package:selah/web/admin/admin_controller.dart';
import 'package:selah/web/data/learning_gateway.dart';
import 'package:selah/web/domain/admin_dashboard.dart';
import 'package:selah/web/domain/admin_membership.dart';
import 'package:selah/web/ui/admin_dashboard_page.dart';

class _DashboardGateway extends UnconfiguredGateway {
  @override
  bool get configured => true;

  @override
  String get userId => 'admin';
}

AdminDashboardData _data() => AdminDashboardData(
  summary: AdminSummary(
    activeLearners: 0,
    learningSessions: 0,
    effectiveLearningMinutes: 0,
    featureUsage: const [],
    dailyActivity: const [],
    api: AdminApiSummary(
      businessRequests: 0,
      reusedRequests: 0,
      providerAttempts: 0,
      knownEstimatedCostUsd: 0,
      providerRecordedCostUsd: 0,
      unknownUsageAttempts: 0,
      byFeature: const [],
    ),
  ),
  attempts: const [],
  generatedAt: DateTime.utc(2026, 9, 18),
);

void main() {
  testWidgets('admin dashboard explains registered-account access', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = AdminController(gateway: _DashboardGateway())
      ..checked = true
      ..data = _data()
      ..controls = const AdminServiceControls(
        configured: true,
        membershipEnforcementEnabled: false,
      );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: SelahTheme.light(),
        home: Scaffold(
          body: AdminDashboardPage(controller: controller, uiLocale: 'zh-Hans'),
        ),
      ),
    );

    expect(find.text('云端账户要求'), findsOneWidget);
    expect(find.text('正式账户模式'), findsOneWidget);
    expect(find.textContaining('生成、转写、个人音频、会员与同步均要求注册并登录'), findsOneWidget);
    expect(find.text('启用会员限制'), findsNothing);
  });

  testWidgets('admin dashboard does not offer legacy test-mode controls', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = AdminController(gateway: _DashboardGateway())
      ..checked = true
      ..data = _data()
      ..controls = const AdminServiceControls(
        configured: true,
        membershipEnforcementEnabled: true,
      );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: SelahTheme.light(),
        home: Scaffold(
          body: AdminDashboardPage(controller: controller, uiLocale: 'zh-Hans'),
        ),
      ),
    );

    expect(find.text('测试模式'), findsNothing);
    expect(find.text('开放匿名测试'), findsNothing);
    expect(find.text('应用生产模式'), findsNothing);
  });
}
