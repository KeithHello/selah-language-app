import 'package:flutter_test/flutter_test.dart';
import 'package:selah/web/data/learning_gateway.dart';
import 'package:selah/web/learning_controller.dart';

import 'web_controller_test.dart' show MemoryPlatform;

class _IdleGateway extends UnconfiguredGateway {}

LearningController _controller() => LearningController(
  gateway: _IdleGateway(),
  platform: MemoryPlatform(),
  polling: false,
  seeds: const [],
);

void main() {
  testWidgets('ordinary notices auto-dismiss after four seconds', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    var notified = 0;
    controller.addListener(() => notified++);

    controller.notice = '偏好已保存。';
    expect(controller.notice, '偏好已保存。');

    await tester.pump(const Duration(seconds: 3));
    expect(controller.notice, isNotNull);

    await tester.pump(const Duration(seconds: 2));
    expect(controller.notice, isNull);
    expect(notified, 1);
  });

  testWidgets('information-dense notices stay visible for eight seconds', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);

    controller.notice = '备份已导出，包含句子、词汇、复习进度和精灵回忆。';

    await tester.pump(const Duration(seconds: 5));
    expect(controller.notice, isNotNull);

    await tester.pump(const Duration(seconds: 4));
    expect(controller.notice, isNull);
  });

  testWidgets('action-required notices stay until replaced or cleared', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);

    controller.notice = '请先通过邮件确认账户，再回来登录。';
    await tester.pump(const Duration(minutes: 1));
    expect(controller.notice, '请先通过邮件确认账户，再回来登录。');

    controller.notice = null;
    expect(controller.notice, isNull);
  });

  testWidgets('replacing a notice resets its auto-dismiss timer', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);

    controller.notice = '偏好已保存。';
    await tester.pump(const Duration(seconds: 3));
    controller.notice = '这句英文已保存，准备好就听一听。';

    await tester.pump(const Duration(seconds: 3));
    expect(controller.notice, '这句英文已保存，准备好就听一听。');

    await tester.pump(const Duration(seconds: 2));
    expect(controller.notice, isNull);
  });

  testWidgets('clearing a notice cancels its timer', (tester) async {
    final controller = _controller();
    addTearDown(controller.dispose);

    controller.notice = '偏好已保存。';
    controller.notice = null;
    await tester.pump(const Duration(seconds: 5));
    expect(controller.notice, isNull);
  });
}
