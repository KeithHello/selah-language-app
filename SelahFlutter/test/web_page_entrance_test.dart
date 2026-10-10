import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/design/selah_lazy_indexed_stack.dart';
import 'package:selah/web/data/learning_gateway.dart';
import 'package:selah/web/domain/learning_models.dart';
import 'package:selah/web/learning_controller.dart';
import 'package:selah/web/platform/learning_platform.dart';
import 'package:selah/web/ui/web_learning_app.dart';

class _EntrancePlatform implements LearningPlatform {
  Map<String, dynamic>? saved;

  @override
  Future<Object?> invoke(
    String action, [
    Map<String, Object?> payload = const {},
  ]) async {
    switch (action) {
      case 'load':
        return saved;
      case 'save':
        saved = Map<String, dynamic>.from(payload['snapshot']! as Map);
        return true;
      case 'platformInfo':
        return const {
          'online': false,
          'storage': true,
          'audio': true,
          'storagePersisted': null,
          'installKind': 'unsupported',
          'installed': false,
          'canInstall': false,
          'updateAvailable': false,
          'buildId': 'test',
        };
      case 'audioStatus':
        return const {'state': 'idle', 'positionMs': 0, 'durationMs': 0};
      case 'audioCached':
        return true;
      case 'contentHash':
        return 'a' * 64;
      default:
        return null;
    }
  }
}

LearnSentence _note(String id, String source, String target) => LearnSentence(
  id: id,
  source: source,
  target: target,
  category: 'work',
  breakdown: const [],
  vocabulary: const [],
);

Future<LearningController> _motionController() async {
  final controller = LearningController(
    gateway: UnconfiguredGateway(),
    platform: _EntrancePlatform(),
    seeds: const [],
    polling: false,
  );
  await controller.initialize();
  controller.state.preferences
    ..onboarded = true
    ..uiLocale = 'zh-Hans'
    ..motionEnabled = true;
  controller.state.sentences
    ..clear()
    ..addAll([
      _note(
        'one',
        'Work late again today.',
        'I have to work late again today.',
      ),
      _note('two', 'See friends this weekend.', 'I want to see my friends.'),
    ]);
  return controller;
}

/// Combined opacity of every fade or opacity widget above [target].
double _visibleOpacity(WidgetTester tester, Finder target) {
  var opacity = 1.0;
  for (final element
      in find
          .ancestor(of: target, matching: find.byType(FadeTransition))
          .evaluate()) {
    opacity *= (element.widget as FadeTransition).opacity.value;
  }
  for (final element
      in find.ancestor(of: target, matching: find.byType(Opacity)).evaluate()) {
    opacity *= (element.widget as Opacity).opacity;
  }
  return opacity;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('only a first visit to a tab plays its entrance', (tester) async {
    final controller = await _motionController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(WebLearningApp(controller: controller));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    double pageFade() => tester
        .widget<FadeTransition>(
          find
              .ancestor(
                of: find.byType(SelahLazyIndexedStack),
                matching: find.byType(FadeTransition),
              )
              .first,
        )
        .opacity
        .value;

    final fades = <String>[];
    for (final tab in [1, 0, 1, 0, 3, 1, 3, 0]) {
      controller.navigate(tab);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      final fading = pageFade() < 0.99;
      final state = fading ? 'fade' : 'still';
      fades.add('$tab:$state');
      await tester.pump(const Duration(seconds: 2));
    }

    expect(fades, [
      '1:fade',
      '0:still',
      '1:still',
      '0:still',
      '3:fade',
      '1:still',
      '3:still',
      '0:still',
    ]);
  });

  testWidgets('notes search and first card appear together', (tester) async {
    final controller = await _motionController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(WebLearningApp(controller: controller));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    controller.navigate(3);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    final search = find
        .descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(TextField),
        )
        .first;
    final card = find
        .byWidgetPredicate(
          (widget) =>
              widget is RichText &&
              widget.text.toPlainText().contains('Work late again today'),
        )
        .first;
    expect(_visibleOpacity(tester, search), 1);
    expect(_visibleOpacity(tester, card), 1);
  });
}
