import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/app/selah_app.dart';
import 'package:selah/data/local_database.dart';
import 'package:selah/app/container.dart';
import 'package:selah/features/companion/selah_sprite.dart';

void main() {
  testWidgets('App 可启动并显示 Onboarding 页', (tester) async {
    // 启用系统 Reduce Motion，避免无限循环动画阻塞测试帧。
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue);

    final db = (await tester.runAsync(() => SelahLocalDatabase.open(inMemory: true)))!;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDatabaseProvider.overrideWithValue(db),
        ],
        child: const SelahApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('歡迎來到 Selah'), findsOneWidget);
    expect(find.byType(SelahSprite), findsOneWidget);
    await tester.runAsync(() => db.close());
  });
}
