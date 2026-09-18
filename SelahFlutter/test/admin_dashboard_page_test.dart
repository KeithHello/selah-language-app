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
  testWidgets('admin dashboard exposes one product mode control', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = AdminController(gateway: _DashboardGateway())
      ..checked = true
      ..data = _data()
      ..controls = const AdminServiceControls(
        configured: true,
        anonymousTestModeEnabled: true,
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

    expect(find.text('运行模式'), findsOneWidget);
    expect(find.text('测试模式'), findsOneWidget);
    expect(find.text('启用会员限制'), findsNothing);
    expect(find.text('开放匿名测试'), findsNothing);
  });

  testWidgets('admin dashboard explains and can normalize mixed mode flags', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = AdminController(gateway: _DashboardGateway())
      ..checked = true
      ..data = _data()
      ..controls = const AdminServiceControls(
        configured: true,
        anonymousTestModeEnabled: true,
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

    expect(find.text('当前远端开关不是完整的测试或生产配置，匿名入口可能仍然开放。请先应用生产模式归一化。'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '应用生产模式'), findsOneWidget);
  });
}
