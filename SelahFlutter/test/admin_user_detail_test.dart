import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/web/data/learning_gateway.dart';
import 'package:selah/web/domain/admin_membership.dart';
import 'package:selah/web/ui/admin_user_detail.dart';

class _AdminDetailGateway extends UnconfiguredGateway {
  final requests = <Map<String, dynamic>>[];

  @override
  bool get configured => true;

  @override
  String? get userId => 'admin-user';

  @override
  Future<Map<String, dynamic>> invoke(
    String function,
    Map<String, dynamic> body, {
    bool get = false,
  }) async {
    requests.add({'function': function, ...body});
    if (function == 'admin-users') {
      return {
        'userId': body['userId'],
        'periods': [],
        'orders': [],
        'auditLogs': [],
        'usageAttempts': [
          {
            'id': 'usage-2',
            'feature': 'transcription',
            'model': 'gpt-4o-mini-transcribe',
            'provider_status': 'succeeded',
            'delivery_status': 'succeeded',
            'item_count': 1,
            'input_characters': null,
            'duration_ms': 60000,
            'estimated_cost_usd': '0.0009000000',
            'usage_source': 'provider',
            'started_at': '2026-10-03T06:25:00Z',
          },
          {
            'id': 'usage-1',
            'feature': 'tts',
            'model': 'tts-1',
            'provider_status': 'succeeded',
            'delivery_status': 'succeeded',
            'item_count': 1,
            'input_characters': 120,
            'duration_ms': null,
            'estimated_cost_usd': '0.0018000000',
            'usage_source': 'request_estimate',
            'started_at': '2026-10-03T06:20:00Z',
          },
        ],
        'login': {
          'lastLoginAt': '2026-10-03T06:30:00Z',
          'createdAt': '2026-09-01T00:00:00Z',
        },
      };
    }
    if (function == 'admin-membership-actions') return {'success': true};
    throw const LearningFailure('unexpected function');
  }
}

void main() {
  testWidgets('admin can grant Pro and sends the selected plan', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final gateway = _AdminDetailGateway();
    final user = AdminUserItem(
      userId: 'target-user',
      emailMasked: 'u***@example.com',
      plan: 'free',
      status: 'none',
      createdAt: DateTime.utc(2026, 9, 24),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) =>
                    AdminUserDetailDialog(gateway: gateway, user: user),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final dropdowns = find.byType(DropdownButtonFormField<String>);
    expect(dropdowns, findsNWidgets(2));
    await tester.tap(dropdowns.last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pro').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == '操作原因（必填）',
      ),
      '内测验证 Pro 会员权益',
    );
    await tester.tap(find.text('确认操作'));
    await tester.pumpAndSettle();
    expect(find.textContaining('会员方案：Pro'), findsOneWidget);
    await tester.tap(find.text('继续提交'));
    await tester.pumpAndSettle();

    final action = gateway.requests.singleWhere(
      (request) => request['function'] == 'admin-membership-actions',
    );
    expect(action['action'], 'grant_membership');
    expect(action['plan'], 'pro');
    expect(action['months'], 1);
  });

  testWidgets('admin user detail shows recent login and provider usage', (
    tester,
  ) async {
    final gateway = _AdminDetailGateway();
    final user = AdminUserItem(
      userId: 'target-user',
      emailMasked: 'u***@example.com',
      plan: 'free',
      status: 'none',
      createdAt: DateTime.utc(2026, 9, 24),
      lastLoginAt: DateTime.utc(2026, 10, 3, 6, 30),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) =>
                    AdminUserDetailDialog(gateway: gateway, user: user),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.textContaining('最近登录：'), findsOneWidget);
    expect(find.textContaining('最近用量：2 笔'), findsOneWidget);
    expect(find.textContaining('AI 配音 · 120 字元 · 成功'), findsOneWidget);
    expect(find.textContaining('录音转写 · 1 分 · 成功'), findsOneWidget);
  });
}
