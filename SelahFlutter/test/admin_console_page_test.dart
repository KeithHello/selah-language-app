import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/web/admin/admin_controller.dart';
import 'package:selah/web/data/learning_gateway.dart';
import 'package:selah/web/ui/admin_console_page.dart';

class _ConsoleGateway extends UnconfiguredGateway {
  bool _signedIn = false;

  @override
  bool get configured => true;

  @override
  String? get userId => _signedIn ? 'admin-user' : null;

  @override
  String? get email => _signedIn ? 'admin@example.com' : null;

  @override
  Future<void> signIn(String email, String password) async {
    _signedIn = true;
  }

  @override
  Future<Map<String, dynamic>> invoke(
    String function,
    Map<String, dynamic> body, {
    bool get = false,
  }) async => switch (function) {
    'admin-summary' => {'summary': {}, 'attempts': []},
    'admin-service-controls' => {
      'membershipEnforcementEnabled': false,
      'trialSignupsEnabled': false,
      'membershipSalesEnabled': false,
      'generationEnabled': true,
    },
    'admin-users' => {'users': [], 'nextCursor': null},
    _ => throw LearningFailure('Unexpected function: $function'),
  };
}

void main() {
  testWidgets('successful admin sign-in stays on the admin console', (
    tester,
  ) async {
    final gateway = _ConsoleGateway();
    final controller = AdminController(gateway: gateway);
    await tester.pumpWidget(
      MaterialApp(home: AdminConsolePage(controller: controller)),
    );

    await tester.enterText(find.byType(TextField).first, 'admin@example.com');
    await tester.enterText(find.byType(TextField).last, 'secret-password');
    await tester.tap(find.text('登录管理台'));
    await tester.pumpAndSettle();

    expect(find.text('退出管理台'), findsOneWidget);
    expect(find.text('登录管理台'), findsNothing);
    expect(find.text('管理台 · admin@example.com'), findsOneWidget);
  });
}
