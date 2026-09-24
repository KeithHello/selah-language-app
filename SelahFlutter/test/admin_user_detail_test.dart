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
}
