import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/web/data/learning_gateway.dart';
import 'package:selah/web/learning_controller.dart';
import 'package:selah/web/platform/learning_platform.dart';
import 'package:selah/web/ui/web_learning_app.dart';

class _RecoveryPlatform implements LearningPlatform {
  @override
  Future<Object?> invoke(
    String action, [
    Map<String, Object?> payload = const {},
  ]) async {
    switch (action) {
      case 'platformInfo':
        return {'online': false};
      case 'contentHash':
        return 'a' * 64;
      default:
        return null;
    }
  }
}

class _RecoveryGateway extends UnconfiguredGateway {
  _RecoveryGateway(this.sessionEmail);

  final String? sessionEmail;
  final List<String> updatedPasswords = <String>[];

  @override
  bool get configured => true;

  @override
  String? get userId => sessionEmail == null ? null : 'user-1';

  @override
  String? get email => sessionEmail;

  @override
  Future<void> updatePassword(String newPassword) async {
    updatedPasswords.add(newPassword);
  }
}

void main() {
  testWidgets('recovery link shows the new-password dialog and updates', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final gateway = _RecoveryGateway('user@example.com');
    final controller = LearningController(
      gateway: gateway,
      platform: _RecoveryPlatform(),
      seeds: const [],
      polling: false,
      initialPasswordRecovery: true,
      recoveryEmailHintFromLink: 'user@example.com',
    );
    controller.platformInfo['online'] = false;
    addTearDown(controller.dispose);
    await controller.initialize();

    controller.state.preferences
      ..onboarded = true
      ..uiLocale = 'zh-Hans';
    controller.notifyListeners();

    await tester.pumpWidget(WebLearningApp(controller: controller));
    await tester.pump(const Duration(milliseconds: 350));

    expect(
      find.byKey(const ValueKey('password-recovery-overlay')),
      findsOneWidget,
    );

    final fields = find.descendant(
      of: find.byKey(const ValueKey('password-recovery-overlay')),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.at(0), 'abcdef');
    await tester.enterText(fields.at(1), 'ghijkl');
    await tester.tap(find.byKey(const ValueKey('password-recovery-submit')));
    await tester.pump(const Duration(milliseconds: 350));
    expect(controller.errorCode, 'recovery_mismatch');
    expect(gateway.updatedPasswords, isEmpty);

    await tester.enterText(fields.at(0), '654321');
    await tester.enterText(fields.at(1), '654321');
    await tester.tap(find.byKey(const ValueKey('password-recovery-submit')));
    await tester.pump(const Duration(milliseconds: 350));

    expect(gateway.updatedPasswords, ['654321']);
    expect(controller.passwordResetRequired, isFalse);
    expect(
      find.byKey(const ValueKey('password-recovery-overlay')),
      findsNothing,
    );
    controller.dismissNotice();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
