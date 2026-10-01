import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/domain/selah_enums.dart';
import 'package:selah/design/selah_colors.dart';
import 'package:selah/web/data/learning_gateway.dart';
import 'package:selah/web/domain/learning_models.dart';
import 'package:selah/web/learning_controller.dart';
import 'package:selah/web/platform/learning_platform.dart';
import 'package:selah/web/ui/web_learning_app.dart';
import 'package:selah/web/ui/plush_companion.dart';
import 'package:selah/web/ui/web_start_action.dart';
import 'package:selah/web/ui/companion_dice_button.dart';
import 'web_controller_test.dart' show CaptureGateway, FakeGateway;

class _FakePlatform implements LearningPlatform {
  Map<String, dynamic>? saved;
  bool failSave = false;
  final actions = <String>[];
  Map<String, dynamic> info = {
    'online': false,
    'storage': true,
    'audio': true,
    'storagePersisted': null,
    'installKind': 'unsupported',
    'installed': false,
    'canInstall': false,
    'updateAvailable': false,
    'buildId': 'dev',
  };

  @override
  Future<Object?> invoke(
    String action, [
    Map<String, Object?> payload = const {},
  ]) async {
    actions.add(action);
    switch (action) {
      case 'load':
        return saved;
      case 'save':
        if (failSave) throw const LearningFailure('本机保存失败，请重试。');
        saved = Map<String, dynamic>.from(payload['snapshot']! as Map);
        return true;
      case 'platformInfo':
        return Map<String, dynamic>.from(info);
      case 'audioStatus':
        return {'state': 'idle', 'positionMs': 0, 'durationMs': 0};
      case 'audioCached':
        return true;
      case 'contentHash':
        return 'a' * 64;
      case 'recordCancel':
      case 'audioStop':
        return true;
      default:
        return null;
    }
  }
}

class _RecordingFakePlatform extends _FakePlatform {
  @override
  Future<Object?> invoke(
    String action, [
    Map<String, Object?> payload = const {},
  ]) async {
    if (action == 'recordStop') {
      return {'base64': 'YQ==', 'mimeType': 'audio/webm', 'durationMs': 1000};
    }
    return super.invoke(action, payload);
  }
}

class _SpokenGateway extends CaptureGateway {
  String transcript = '';
  Object? prepareFailure;
  final functions = <String>[];
  final generationSources = <String>[];

  @override
  Future<String> transcribe(
    Map<String, dynamic> recording,
    String requestId,
  ) async => transcript;

  @override
  Future<Map<String, dynamic>> invoke(
    String function,
    Map<String, dynamic> body, {
    bool get = false,
  }) async {
    functions.add(function);
    if (function == 'sentences-prepare' && prepareFailure != null) {
      throw prepareFailure!;
    }
    if (function == 'sentences-generate') {
      generationSources.add(body['sourceText'] as String);
    }
    return super.invoke(function, body, get: get);
  }
}

Future<LearningController> _todayController(
  _SpokenGateway gateway,
  _RecordingFakePlatform platform,
) async {
  final controller = LearningController(
    gateway: gateway,
    platform: platform,
    seeds: List.generate(6, (index) => _seed(index + 1)),
    polling: false,
  );
  await controller.initialize();
  controller.state.preferences
    ..onboarded = true
    ..uiLocale = 'zh-Hans';
  return controller;
}

Future<void> _recordTranscript(WidgetTester tester) async {
  await _openTodayComposer(tester);
  final record = find.widgetWithText(OutlinedButton, '说出来');
  await tester.ensureVisible(record);
  await tester.tap(record);
  await tester.pumpAndSettle();
  final stop = find.byType(OutlinedButton).first;
  await tester.ensureVisible(stop);
  await tester.tap(stop);
  await tester.pumpAndSettle();
}

Future<void> _openTodayComposer(WidgetTester tester) async {
  if (find.byType(TextField).evaluate().isNotEmpty) return;
  final entry = find.byKey(const ValueKey('today-speak-entry'));
  await tester.ensureVisible(entry);
  await tester.tap(entry);
  await tester.pumpAndSettle();
}

Future<void> _disposeTodayController(
  WidgetTester tester,
  LearningController controller,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await controller.flushLocalWrites();
  controller.dispose();
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
}

class _SignedOutConfiguredGateway extends FakeGateway {
  _SignedOutConfiguredGateway() {
    user = null;
  }
}

LearnSentence _seed(int index) => LearnSentence.seed({
  'id': 'seed-${index.toString().padLeft(3, '0')}',
  'zh_text': [
    '今天想早点休息。',
    '我终于把这件事做完了。',
    '周末想和朋友见面。',
    '明天早上要早点出门。',
    '我想把英语练习坚持下去。',
    '今天要记得给朋友回消息。',
  ][index - 1],
  'en_translation': [
    'I want to get some rest early today.',
    'I finally finished this.',
    'I want to see my friends this weekend.',
    'I need to leave early tomorrow morning.',
    'I want to keep up my English practice.',
    'I need to remember to reply to my friend today.',
  ][index - 1],
  'category': [
    'daily_life',
    'work',
    'friends',
    'friends',
    'daily_life',
    'work',
  ][index - 1],
  'deconstruction': const [],
  'vocab_candidates': const [],
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LearningController controller;
  late _FakePlatform platform;

  setUp(() async {
    TestWidgetsFlutterBinding
        .instance
        .platformDispatcher
        .accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: true,
    );
    platform = _FakePlatform();
    controller = LearningController(
      gateway: UnconfiguredGateway(),
      platform: platform,
      seeds: List.generate(6, (index) => _seed(index + 1)),
      polling: false,
    );
    await controller.initialize();
    // Existing interaction coverage predates the locale rollout and keeps
    // its Simplified Chinese finders explicit. The product default itself is
    // exercised by web_models_test and the locale-specific tests.
    controller.state.preferences.uiLocale = 'zh-Hans';
  });

  tearDown(() {
    controller.dispose();
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearAccessibilityFeaturesTestValue();
  });

  testWidgets('onboarding requires a name and at least three seeds', (
    tester,
  ) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );

    await tester.pumpWidget(WebLearningApp(controller: controller));
    expect(find.text('先让 Selah 认识你'), findsOneWidget);
    expect(find.text('第 1 步：给精灵取名字'), findsOneWidget);
    expect(find.text('必填'), findsOneWidget);
    expect(find.text('这是你要陪伴的精灵名字，之后会一直显示在学习空间里。'), findsOneWidget);

    final nameField = find.byType(TextField).first;
    final initialName = tester.widget<TextField>(nameField).controller!.text;
    expect(initialName, isNotEmpty);
    expect(find.byType(CompanionDiceButton), findsOneWidget);

    // Roll a new name with the dice button
    await tester.tap(find.byType(CompanionDiceButton));
    await tester.pump();
    final rolledName = tester.widget<TextField>(nameField).controller!.text;
    expect(rolledName, isNotEmpty);

    // If the name is cleared, attempting to start requires entering a name
    await tester.enterText(nameField, '');
    await tester.pump();

    await tester.tap(
      find.descendant(
        of: find.byType(WebStartAction),
        matching: find.byType(FilledButton),
      ),
    );
    await tester.pump();
    expect(find.text('请先输入精灵名字。'), findsOneWidget);

    await tester.enterText(nameField, '小芽');
    for (final sentence in [
      '今天想早点休息。',
      '我终于把这件事做完了。',
      '周末想和朋友见面。',
      '明天早上要早点出门。',
      '我想把英语练习坚持下去。',
      '今天要记得给朋友回消息。',
    ]) {
      await tester.ensureVisible(find.text(sentence));
      await tester.tap(find.text(sentence));
    }
    await tester.pump();
    expect(find.text('已选 6 句（至少 3 句）'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(WebStartAction),
        matching: find.byType(FilledButton),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      for (var i = 0; i < 20 && controller.busy; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      controller.state.preferences.onboarded,
      isTrue,
      reason:
          'error=${controller.error}, notice=${controller.notice}, busy=${controller.busy}, saved=${platform.saved}',
    );
    expect(controller.state.sentences, hasLength(6));
    expect(find.text('今天也辛苦了'), findsOneWidget);
    expect(
      tester
          .widget<PlushCompanion>(find.byType(PlushCompanion).first)
          .decorationStage,
      DecorationStage.sprout,
    );
    expect(platform.saved, isNotNull);
  });

  testWidgets(
    'floating start remains reachable and reacts to name edits last',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(WebLearningApp(controller: controller));
      await tester.tap(find.text('推荐 3 句'));
      await tester.pumpAndSettle();
      final action = find.descendant(
        of: find.byType(WebStartAction),
        matching: find.byType(FilledButton),
      );
      expect(tester.widget<FilledButton>(action).onPressed, isNotNull);
      await tester.enterText(find.byType(TextField).first, '小芽');
      await tester.pump();
      expect(tester.widget<FilledButton>(action).onPressed, isNotNull);
      final before = tester.getCenter(action);
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -550),
      );
      await tester.pumpAndSettle();
      expect(tester.getCenter(action), before);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('onboarding fits narrow and former overflow breakpoint widths', (
    tester,
  ) async {
    for (final width in [320.0, 820.0, 900.0, 960.0]) {
      await tester.binding.setSurfaceSize(Size(width, 844));
      await tester.pumpWidget(WebLearningApp(controller: controller));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'width=$width');
      expect(
        tester
            .widget<PlushCompanion>(find.byType(PlushCompanion))
            .decorationStage,
        DecorationStage.none,
        reason: 'The first meeting precedes sprouting, width=$width',
      );
      final button = tester.getRect(find.byType(WebStartAction));
      expect(button.right, lessThanOrEqualTo(width));
      expect(button.bottom, lessThanOrEqualTo(844));
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('start failure stays visible beside the floating action', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    platform.failSave = true;
    await tester.pumpWidget(WebLearningApp(controller: controller));
    await tester.enterText(find.byType(TextField).first, '小芽');
    await tester.tap(find.text('推荐 3 句'));
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: find.byType(WebStartAction),
        matching: find.byType(FilledButton),
      ),
    );
    await tester.runAsync(() async {
      for (var i = 0; i < 20 && controller.busy; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pumpAndSettle();
    expect(controller.state.preferences.onboarded, false);
    final failure = find.text('本机保存失败，请重试。');
    expect(failure, findsOneWidget);
    expect(
      tester.getRect(failure).bottom,
      lessThan(tester.getRect(find.byType(WebStartAction)).top),
    );
    expect(tester.getRect(failure).top, greaterThanOrEqualTo(0));
  });

  testWidgets('mobile navigation exposes every learning area', (tester) async {
    controller.state.preferences
      ..onboarded = true
      ..name = '小芽';
    controller.state.sentences.add(_seed(1));
    controller.notifyListeners();

    await tester.pumpWidget(WebLearningApp(controller: controller));
    expect(find.text('今天也辛苦了'), findsOneWidget);

    await tester.tap(find.text('聆听'));
    await tester.pumpAndSettle();
    expect(find.text('给耳朵一点时间'), findsOneWidget);

    await tester.tap(find.text('练习'));
    await tester.pumpAndSettle();
    expect(find.text('练习会在合适的时候回来'), findsOneWidget);

    await tester.tap(find.text('笔记'));
    await tester.pumpAndSettle();
    expect(find.text('把学过的留下来'), findsOneWidget);

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(find.text('设置'), findsWidgets);
  });

  testWidgets(
    'companion rail is hidden by default and appears only after enabling it',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1440, 912));
      controller.state.preferences
        ..onboarded = true
        ..name = '小芽';
      controller.navigate(1);
      await tester.pumpWidget(WebLearningApp(controller: controller));
      await tester.pumpAndSettle();

      expect(find.text('陪伴角落'), findsNothing);

      controller.navigate(4);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('显示陪伴角落'));
      await tester.tap(find.text('显示陪伴角落'));
      await tester.runAsync(() async {
        for (var i = 0; i < 20 && controller.busy; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(controller.state.preferences.companionRailVisible, isTrue);
      expect(find.text('陪伴角落'), findsOneWidget);
      // Let the auto-dismiss notice timer fire before the test ends.
      await tester.pump(const Duration(seconds: 4));
    },
  );

  testWidgets(
    'settings hides membership and admin while retaining local account status',
    (tester) async {
      controller.state.preferences
        ..onboarded = true
        ..uiLocale = 'zh-Hans';
      controller.navigate(4);
      await tester.pumpWidget(WebLearningApp(controller: controller));
      await tester.pumpAndSettle();

      expect(find.text('管理台'), findsNothing);
      expect(find.text('打开管理台'), findsNothing);
      expect(find.text('会员与方案'), findsNothing);
      expect(find.text('当前为公开体验模式'), findsNothing);
      expect(find.text('登录／注册'), findsNothing);
      expect(find.textContaining('云端配置'), findsOneWidget);
    },
  );

  testWidgets(
    'configured local build keeps login available without membership section',
    (tester) async {
      final gateway = _SignedOutConfiguredGateway()..fail = false;
      platform.info['online'] = true;
      final configuredController = LearningController(
        gateway: gateway,
        platform: platform,
        seeds: List.generate(6, (index) => _seed(index + 1)),
        polling: false,
      );
      addTearDown(configuredController.dispose);
      await configuredController.initialize();
      configuredController.state.preferences
        ..onboarded = true
        ..uiLocale = 'zh-Hans';
      configuredController.navigate(4);

      await tester.pumpWidget(WebLearningApp(controller: configuredController));
      await tester.pumpAndSettle();

      expect(find.text('登录／注册'), findsOneWidget);
      expect(find.text('管理台'), findsNothing);
      expect(find.text('会员与方案'), findsNothing);
      expect(find.text('当前为公开体验模式'), findsNothing);
    },
  );

  testWidgets('admin deep link asks for login before loading dashboard', (
    tester,
  ) async {
    final gateway = _SignedOutConfiguredGateway();
    final configuredController = LearningController(
      gateway: gateway,
      platform: platform,
      seeds: List.generate(6, (index) => _seed(index + 1)),
      polling: false,
    );
    addTearDown(configuredController.dispose);
    await configuredController.initialize();
    configuredController.state.preferences
      ..onboarded = true
      ..uiLocale = 'zh-Hans';
    configuredController.navigate(5);

    await tester.pumpWidget(WebLearningApp(controller: configuredController));
    await tester.pumpAndSettle();

    expect(find.text('Selah 管理台'), findsOneWidget);
    expect(find.text('请先登录管理员账号。'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '登录／注册'), findsOneWidget);
  });

  testWidgets(
    'unsigned generation prompts registration and preserves local access',
    (tester) async {
      final gateway = _SignedOutConfiguredGateway()..fail = false;
      platform.info['online'] = true;
      final configuredController = LearningController(
        gateway: gateway,
        platform: platform,
        seeds: List.generate(6, (index) => _seed(index + 1)),
        polling: false,
      );
      addTearDown(configuredController.dispose);
      await configuredController.initialize();
      configuredController.state.preferences
        ..onboarded = true
        ..uiLocale = 'zh-Hans';
      await configuredController.generate('今天想早点休息。');

      await tester.pumpWidget(WebLearningApp(controller: configuredController));
      await tester.pumpAndSettle();

      expect(configuredController.hasSession, isFalse);
      expect(configuredController.errorCode, 'login_required');
      expect(find.text('注册／登录'), findsOneWidget);
      expect(find.text('请先登录，便能生成自己的英文和语音。'), findsOneWidget);
      await configuredController.sync();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'non-auth generation errors do not replace their own message with a login action',
    (tester) async {
      final gateway = _SignedOutConfiguredGateway()..fail = false;
      platform.info['online'] = true;
      final configuredController = LearningController(
        gateway: gateway,
        platform: platform,
        seeds: List.generate(6, (index) => _seed(index + 1)),
        polling: false,
      );
      addTearDown(configuredController.dispose);
      await configuredController.initialize();
      configuredController.state.preferences
        ..onboarded = true
        ..name = '小芽';
      configuredController.errorCode = 'service_budget_protected';
      configuredController.error = '今天的测试预算已用完，请明天再试。';
      configuredController.notifyListeners();

      await tester.pumpWidget(WebLearningApp(controller: configuredController));
      expect(find.text('今天的测试预算已用完，请明天再试。'), findsOneWidget);
      expect(find.text('注册／登录'), findsNothing);
    },
  );

  testWidgets(
    'registered-account requirement offers inline registration and login',
    (tester) async {
      final gateway = _SignedOutConfiguredGateway()..fail = false;
      platform.info['online'] = true;
      final configuredController = LearningController(
        gateway: gateway,
        platform: platform,
        seeds: List.generate(6, (index) => _seed(index + 1)),
        polling: false,
      );
      addTearDown(configuredController.dispose);
      await configuredController.initialize();
      configuredController.state.preferences
        ..onboarded = true
        ..name = '小芽'
        ..uiLocale = 'zh-Hans';
      configuredController.errorCode = 'login_required';
      configuredController.error = '请先登录，便能生成自己的英文和语音。';
      configuredController.notifyListeners();

      await tester.pumpWidget(WebLearningApp(controller: configuredController));
      expect(find.text('注册／登录'), findsOneWidget);
      expect(find.text('请登录'), findsOneWidget);
    },
  );

  testWidgets('registration dialog offers optional age and gender fields', (
    tester,
  ) async {
    final gateway = _SignedOutConfiguredGateway()..fail = false;
    platform.info['online'] = true;
    final configuredController = LearningController(
      gateway: gateway,
      platform: platform,
      seeds: List.generate(6, (index) => _seed(index + 1)),
      polling: false,
    );
    addTearDown(configuredController.dispose);
    await configuredController.initialize();
    configuredController.state.preferences
      ..onboarded = true
      ..uiLocale = 'zh-Hans';
    configuredController.navigate(4);

    await tester.pumpWidget(WebLearningApp(controller: configuredController));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('登录／注册'));
    await tester.tap(find.text('登录／注册'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('创建新账户'));
    await tester.pumpAndSettle();

    expect(find.text('注册时可选资料'), findsOneWidget);
    expect(find.text('年龄段'), findsOneWidget);
    expect(find.text('性别'), findsOneWidget);
    expect(find.textContaining('这些背景资料完全自愿'), findsOneWidget);
  });

  testWidgets('settings expose a native voice picker', (tester) async {
    controller.state.preferences
      ..onboarded = true
      ..uiLocale = 'zh-Hans';
    controller.navigate(4);
    await tester.pumpWidget(WebLearningApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('英文声线'), findsOneWidget);
    expect(find.text('母语声线'), findsOneWidget);
    expect(find.textContaining('循环听会按这个声线生成母语配音'), findsOneWidget);
  });

  testWidgets('settings expose five speed presets and custom speed', (
    tester,
  ) async {
    controller.state.preferences
      ..onboarded = true
      ..uiLocale = 'zh-Hans';
    controller.navigate(4);
    await tester.pumpWidget(WebLearningApp(controller: controller));
    await tester.pumpAndSettle();

    for (final label in ['0.5x', '0.75x', '1x', '1.25x', '1.5x']) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.ensureVisible(find.widgetWithText(OutlinedButton, '自定义'));
    await tester.tap(find.widgetWithText(OutlinedButton, '自定义'));
    await tester.pumpAndSettle();
    expect(find.text('自定义语速'), findsOneWidget);
    expect(find.textContaining('可调节 0.5x～2.0x'), findsOneWidget);
    await tester.tap(find.text('取消'));
  });

  testWidgets(
    'one native language choice controls the interface and input language',
    (tester) async {
      controller.state.preferences
        ..onboarded = true
        ..nativeLanguage = 'zh-Hant';
      controller.navigate(4);
      await tester.pumpWidget(WebLearningApp(controller: controller));
      await tester.pumpAndSettle();

      expect(find.text('設定'), findsWidgets);
      expect(find.text('母語'), findsOneWidget);
      expect(find.text('學習語言'), findsOneWidget);
      expect(find.text('介面語言'), findsNothing);
      expect(find.text('繁體中文'), findsOneWidget);
      expect(find.text('簡體中文'), findsOneWidget);
      expect(find.text('日本語'), findsWidgets);
      expect(find.text('英語'), findsOneWidget);
      expect(find.text('之後準備加入'), findsOneWidget);

      final enabledEnglish = find.byWidgetPredicate((widget) {
        if (widget is! ChoiceChip || widget.label is! Text) return false;
        final label = widget.label as Text;
        return label.data == '英語' &&
            widget.selected &&
            widget.onSelected != null;
      });
      expect(enabledEnglish, findsOneWidget);

      final disabledJapanese = find.byWidgetPredicate((widget) {
        if (widget is! ChoiceChip || widget.label is! Text) return false;
        final label = widget.label as Text;
        return label.data == '日本語' && widget.onSelected == null;
      });
      expect(disabledJapanese, findsOneWidget);

      await tester.tap(find.text('簡體中文'));
      await tester.pump();
      await tester.runAsync(() async {
        for (var i = 0; i < 20 && controller.busy; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      });
      await tester.pump();
      expect(controller.nativeLanguage, 'zh-Hans');
      expect(controller.uiLocale, 'zh-Hans');
      expect(find.text('设置'), findsWidgets);
      expect(find.text('界面语言'), findsNothing);

      final nativeJapanese = find.byWidgetPredicate((widget) {
        if (widget is! ChoiceChip || widget.label is! Text) return false;
        final label = widget.label as Text;
        return label.data == '日本語' && widget.onSelected != null;
      });
      await tester.tap(nativeJapanese);
      await tester.pump();
      await tester.runAsync(() async {
        for (var i = 0; i < 20 && controller.busy; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      });
      await tester.pump();
      expect(controller.nativeLanguage, 'ja');
      expect(controller.uiLocale, 'ja');
      expect(find.text('表示言語'), findsNothing);

      controller.navigate(0);
      await tester.pumpAndSettle();
      await _openTodayComposer(tester);
      expect(find.text('例：今日はずっと先延ばしにしていたことを終えました。'), findsOneWidget);
      // Let the auto-dismiss notice timer fire before the test ends.
      await tester.pump(const Duration(seconds: 4));
    },
  );

  testWidgets(
    'settings renders protected and installed device states as read only',
    (tester) async {
      controller.state.preferences
        ..onboarded = true
        ..uiLocale = 'zh-Hant';
      controller.platformInfo = {
        ...platform.info,
        'storagePersisted': true,
        'installKind': 'installed',
        'installed': true,
        'canInstall': false,
        'updateAvailable': false,
        'buildId': 'build-42',
      };
      controller.navigate(4);
      await tester.pumpWidget(WebLearningApp(controller: controller));
      await tester.pumpAndSettle();

      expect(find.text('本機儲存已受保護'), findsOneWidget);
      expect(find.text('申請保護'), findsNothing);
      expect(find.text('已加入主畫面'), findsOneWidget);
      expect(find.text('加入主畫面'), findsNothing);
      expect(find.text('更新到新版本'), findsNothing);
      expect(find.text('build-42'), findsOneWidget);
    },
  );

  testWidgets(
    'settings exposes an update action and blocks it during recording',
    (tester) async {
      controller.state.preferences
        ..onboarded = true
        ..uiLocale = 'zh-Hant';
      controller.platformInfo = {
        ...platform.info,
        'storagePersisted': false,
        'installKind': 'prompt',
        'canInstall': true,
        'updateAvailable': true,
        'buildId': 'build-43',
      };
      controller.recording = true;
      controller.navigate(4);
      await tester.pumpWidget(WebLearningApp(controller: controller));
      await tester.pumpAndSettle();

      final update = find.widgetWithText(OutlinedButton, '更新到新版本');
      expect(update, findsOneWidget);
      expect(tester.widget<OutlinedButton>(update).onPressed, isNull);
    },
  );

  testWidgets(
    'today keeps the compact greeting and companion usable across widths',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      controller.state.preferences.onboarded = true;
      for (final width in [390.0, 759.0, 1440.0]) {
        await tester.binding.setSurfaceSize(Size(width, 912));
        await tester.pumpWidget(WebLearningApp(controller: controller));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(PlushCompanion), findsOneWidget);
        expect(find.text('今天也辛苦了'), findsOneWidget);
        expect(
          tester.getSize(find.byType(PlushCompanion)).width,
          greaterThanOrEqualTo(56),
        );
      }
    },
  );

  testWidgets('today fits 320px with large text and an input draft', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 900));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    controller.state.preferences.onboarded = true;
    await tester.pumpWidget(WebLearningApp(controller: controller));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await _openTodayComposer(tester);
    await tester.enterText(find.byType(TextField), '今天想练习一句英文。');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'today previews a due sentence and an unheard personal sentence',
    (tester) async {
      controller.state.preferences.onboarded = true;
      controller.state.sentences.addAll([
        LearnSentence(
          id: 'today-due',
          source: '需要再聽一次的句子。',
          target: 'A sentence to revisit.',
          reviewState: 'learning',
          listenedAt: DateTime.now().subtract(const Duration(days: 2)),
          nextReviewAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
        LearnSentence(
          id: 'today-own',
          source: '我剛記下的生活表達。',
          target: 'A thought from my day.',
        ),
      ]);
      await tester.pumpWidget(WebLearningApp(controller: controller));
      await tester.pumpAndSettle();

      expect(find.text('需要再聽一次的句子。'), findsWidgets);
      expect(find.text('我剛記下的生活表達。'), findsWidgets);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.startsWith(
                'today-suggestion-',
              ),
        ),
        findsNWidgets(3),
      );
    },
  );

  testWidgets(
    'today listen entry opens the selected lesson before the picker',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      controller.state.preferences.onboarded = true;
      final due = LearnSentence(
        id: 'today-quick-due',
        source: '先從這句回聽。',
        target: 'Let me revisit this sentence.',
        reviewState: 'learning',
        listenedAt: DateTime.now().subtract(const Duration(days: 2)),
        nextReviewAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      controller.state.sentences.add(due);
      await tester.pumpWidget(WebLearningApp(controller: controller));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('today-listen-entry')));
      await tester.pumpAndSettle();

      expect(controller.tab, 1);
      expect(controller.activeSentence?.id, due.id);
      expect(
        find.byKey(const ValueKey('today-focused-lesson')),
        findsOneWidget,
      );
      expect(find.text('先從這句回聽。'), findsOneWidget);
      expect(find.text('看英文答案'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('listen-sentence-picker')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'today recent expression opens its pinned listen position without playing',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      controller.state.preferences.onboarded = true;
      final now = DateTime.now();
      final sentences = [
        LearnSentence(
          id: 'recent-old',
          source: '较早记录的一句。',
          target: 'An older sentence.',
          createdAt: now.subtract(const Duration(days: 3)),
        ),
        LearnSentence(
          id: 'recent-target',
          source: '这句最近表达应该直接定位。',
          target: 'This recent expression should open directly.',
          createdAt: now.subtract(const Duration(days: 2)),
        ),
        LearnSentence(
          id: 'recent-newest',
          source: '最新记录的一句。',
          target: 'The newest sentence.',
          createdAt: now.subtract(const Duration(days: 1)),
        ),
      ];
      controller.state.sentences.addAll(sentences);
      controller.state.pinnedSentenceIds.add('recent-old');
      platform.actions.clear();
      await tester.pumpWidget(WebLearningApp(controller: controller));
      await tester.pumpAndSettle();

      final recent = find.byKey(const ValueKey('today-recent-recent-target'));
      await tester.ensureVisible(recent);
      await tester.tap(recent);
      await tester.pumpAndSettle();

      final selectedIndex = controller.listenSentences.indexWhere(
        (sentence) => sentence.id == 'recent-target',
      );
      expect(controller.tab, 1);
      expect(controller.activeSentence?.id, 'recent-target');
      expect(controller.todayLessonFocus, isFalse);
      expect(find.byKey(const ValueKey('today-focused-lesson')), findsNothing);
      expect(find.text('看英文答案'), findsOneWidget);
      expect(
        find.text(
          '第 ${selectedIndex + 1} 句／共 ${controller.listenSentences.length} 句',
        ),
        findsOneWidget,
      );
      expect(platform.actions, isNot(contains('audioPlay')));
    },
  );

  testWidgets('reopening the active recent expression hides its answer', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    controller.state.preferences.onboarded = true;
    final sentence = LearnSentence(
      id: 'recent-repeat',
      source: '重复打开时收起答案。',
      target: List.filled(80, 'Hide the answer when reopened.').join(' '),
    );
    controller.state.sentences.add(sentence);
    await tester.pumpWidget(WebLearningApp(controller: controller));
    await tester.pumpAndSettle();

    final recent = find.byKey(const ValueKey('today-recent-recent-repeat'));
    await tester.ensureVisible(recent);
    await tester.tap(recent);
    await tester.pumpAndSettle();
    await tester.tap(find.text('看英文答案'));
    await tester.pumpAndSettle();
    expect(find.text(sentence.target), findsOneWidget);

    final scrollable = find.descendant(
      of: find.byKey(const ValueKey('listen-content-scroll')),
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(scrollable.first).position;
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(position.pixels, greaterThan(0));

    controller.navigate(0);
    await tester.pumpAndSettle();
    final reopened = find.byKey(const ValueKey('today-recent-recent-repeat'));
    await tester.ensureVisible(reopened);
    await tester.tap(reopened);
    await tester.pumpAndSettle();

    expect(find.text('看英文答案'), findsOneWidget);
    expect(find.text(sentence.target), findsNothing);
    expect(tester.state<ScrollableState>(scrollable.first).position.pixels, 0);
  });

  testWidgets(
    'guest starts a bundled lesson and can continue after listening',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      controller.state.preferences.onboarded = true;
      await tester.pumpWidget(WebLearningApp(controller: controller));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('today-listen-entry')));
      await tester.pump();
      await tester.runAsync(() async {
        for (var i = 0; i < 50 && controller.busy; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      });
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.state.sentences, hasLength(1));
      expect(controller.activeSentence?.seedId, isNotNull);
      expect(find.text(controller.activeSentence!.target), findsNothing);
      expect(find.text('再听一句'), findsNothing);

      final first = controller.activeSentence!;
      first.listenedAt = DateTime.now();
      controller.notifyListeners();
      await tester.pump();
      expect(find.text('再听一句'), findsOneWidget);
      await tester.ensureVisible(find.text('再听一句'));
      await tester.tap(find.text('再听一句'));
      await tester.pump();
      await tester.runAsync(() async {
        for (var i = 0; i < 50 && controller.busy; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      });
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.activeSentence?.id, isNot(first.id));
      expect(controller.todayLessonFocus, isTrue);
    },
  );

  testWidgets('a sentence preview opens that exact lesson', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    controller.state.preferences.onboarded = true;
    final personal = LearnSentence(
      id: 'preview-personal',
      source: '我想学这句自己的话。',
      target: 'I want to learn this thought of mine.',
    );
    controller.state.sentences.add(personal);
    await tester.pumpWidget(WebLearningApp(controller: controller));
    await tester.pumpAndSettle();

    final preview = find.byKey(
      const ValueKey('today-suggestion-preview-personal'),
    );
    await tester.ensureVisible(preview);
    await tester.tap(preview);
    await tester.pumpAndSettle();
    expect(controller.activeSentence?.id, personal.id);
    expect(controller.todayLessonFocus, isTrue);
    expect(find.text(personal.target), findsNothing);
  });

  testWidgets('today speak entry focuses the saved draft without recording', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    controller.state.preferences.onboarded = true;
    controller.updateTodayInput('還想繼續寫的句子。');
    await tester.pumpWidget(WebLearningApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('today-speak-entry')));
    await tester.pumpAndSettle();

    expect(controller.todayInput, '還想繼續寫的句子。');
    expect(find.byType(TextField).first, findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byType(TextField).first)
          .focusNode
          ?.hasFocus,
      isTrue,
    );
    expect(platform.actions, isNot(contains('recordStart')));
  });

  testWidgets('today input from the formal page is wired to the controller', (
    tester,
  ) async {
    controller.state.preferences.onboarded = true;
    await tester.pumpWidget(WebLearningApp(controller: controller));
    await _openTodayComposer(tester);
    await tester.enterText(find.byType(TextField).first, '刷新后还在的输入');
    await tester.pump(const Duration(milliseconds: 450));
    expect(controller.todayInput, '刷新后还在的输入');
  });

  testWidgets(
    'spoken transcript is polished for confirmation before generation',
    (tester) async {
      final gateway = _SpokenGateway()
        ..fail = false
        ..transcript = '嗯，我最近去游泳了嘛。';
      gateway.prepareResult = [
        {
          'segmentId': newId(),
          'orderIndex': 0,
          'originalText': '嗯，我最近去游泳了嘛。',
          'sourceText': '我最近去游泳了。',
          'removedText': ['嗯', '嘛'],
          'selected': true,
        },
      ];
      final recordingPlatform = _RecordingFakePlatform()..info['online'] = true;
      final spokenController = await _todayController(
        gateway,
        recordingPlatform,
      );
      await tester.pumpWidget(WebLearningApp(controller: spokenController));
      await tester.pumpAndSettle();

      await _recordTranscript(tester);
      await tester.tap(find.widgetWithText(FilledButton, '生成英文'));
      await tester.pumpAndSettle();

      expect(gateway.prepareCalls, 1);
      expect(gateway.batchCalls, 0);
      expect(spokenController.state.sentences, isEmpty);
      expect(spokenController.preparationDraft!.segments.single.removedText, [
        '嗯',
        '嘛',
      ]);
      expect(
        spokenController.preparationDraft!.segments.single.polishedText,
        '我最近去游泳了。',
      );
      expect(find.text('确认要练习的话'), findsOneWidget);
      expect(find.text('去掉了：嗯、嘛'), findsOneWidget);
      expect(find.text('用原话'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        '嗯，我最近去游泳了嘛。',
      );

      final useOriginal = find.widgetWithText(TextButton, '用原话');
      await tester.ensureVisible(useOriginal);
      await tester.tap(useOriginal);
      await tester.pumpAndSettle();
      final confirm = find.widgetWithText(FilledButton, '确认并生成');
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(gateway.batchCalls, 0);
      expect(gateway.generationSources, ['嗯，我最近去游泳了嘛。']);
      await _disposeTodayController(tester, spokenController);
    },
  );

  testWidgets('clean spoken transcript skips preparation', (tester) async {
    final gateway = _SpokenGateway()
      ..fail = false
      ..transcript = '今天终于把拖了很久的事情做完了。';
    final recordingPlatform = _RecordingFakePlatform()..info['online'] = true;
    final spokenController = await _todayController(gateway, recordingPlatform);
    await tester.pumpWidget(WebLearningApp(controller: spokenController));
    await tester.pumpAndSettle();

    await _recordTranscript(tester);
    await tester.tap(find.widgetWithText(FilledButton, '生成英文'));
    await tester.pumpAndSettle();

    expect(gateway.prepareCalls, 0);
    expect(gateway.generationSources, ['今天终于把拖了很久的事情做完了。']);
    await _disposeTodayController(tester, spokenController);
  });

  testWidgets('long clean speech keeps the long-text preparation copy', (
    tester,
  ) async {
    final transcript = List.filled(60, '今天我想记录一下这件事情').join();
    final gateway = _SpokenGateway()
      ..fail = false
      ..transcript = transcript
      ..prepareResult = [
        {
          'segmentId': newId(),
          'orderIndex': 0,
          'originalText': transcript.substring(0, 300),
          'sourceText': transcript.substring(0, 300),
          'removedText': <String>[],
          'selected': true,
        },
        {
          'segmentId': newId(),
          'orderIndex': 1,
          'originalText': transcript.substring(300),
          'sourceText': transcript.substring(300),
          'removedText': <String>[],
          'selected': true,
        },
      ];
    final recordingPlatform = _RecordingFakePlatform()..info['online'] = true;
    final spokenController = await _todayController(gateway, recordingPlatform);
    await tester.pumpWidget(WebLearningApp(controller: spokenController));
    await tester.pumpAndSettle();

    await _recordTranscript(tester);
    await tester.tap(find.widgetWithText(FilledButton, '整理长文'));
    await tester.pumpAndSettle();

    expect(gateway.prepareCalls, 1);
    expect(find.text('先整理成几句'), findsOneWidget);
    expect(find.text('确认要练习的话'), findsNothing);
    await _disposeTodayController(tester, spokenController);
  });

  testWidgets('punctuation-only polish generates the original without a card', (
    tester,
  ) async {
    const transcript = '嗯，今天想运动，感觉不错。';
    final gateway = _SpokenGateway()
      ..fail = false
      ..transcript = transcript;
    gateway.prepareResult = [
      {
        'segmentId': newId(),
        'orderIndex': 0,
        'originalText': transcript,
        'sourceText': '嗯,今天想运动,感觉不错.',
        'removedText': [],
        'selected': true,
      },
    ];
    final recordingPlatform = _RecordingFakePlatform()..info['online'] = true;
    final spokenController = await _todayController(gateway, recordingPlatform);
    await tester.pumpWidget(WebLearningApp(controller: spokenController));
    await tester.pumpAndSettle();

    await _recordTranscript(tester);
    await tester.tap(find.widgetWithText(FilledButton, '生成英文'));
    await tester.pumpAndSettle();

    expect(gateway.prepareCalls, 1);
    expect(spokenController.preparationDraft, isNull);
    expect(gateway.generationSources, [transcript]);
    expect(find.text('确认要练习的话'), findsNothing);
    await _disposeTodayController(tester, spokenController);
  });

  testWidgets('preparation failure continues with the original transcript', (
    tester,
  ) async {
    const transcript = '嗯，我今天终于做完了。';
    final gateway = _SpokenGateway()
      ..fail = false
      ..transcript = transcript
      ..prepareFailure = const LearningFailure(
        '整理额度暂时不可用',
        code: 'rate_limited',
      );
    final recordingPlatform = _RecordingFakePlatform()..info['online'] = true;
    final spokenController = await _todayController(gateway, recordingPlatform);
    await tester.pumpWidget(WebLearningApp(controller: spokenController));
    await tester.pumpAndSettle();

    await _recordTranscript(tester);
    await tester.tap(find.widgetWithText(FilledButton, '生成英文'));
    await tester.pumpAndSettle();

    expect(gateway.generationSources, [transcript]);
    expect(spokenController.error, isNull);
    expect(spokenController.notice, '这次没先整理，已按原话继续。');
    await _disposeTodayController(tester, spokenController);
  });

  testWidgets('editing during speech preparation never generates stale text', (
    tester,
  ) async {
    final gateway = _SpokenGateway()
      ..fail = false
      ..transcript = '嗯，我今天终于做完了。'
      ..prepareResponse = Completer();
    final recordingPlatform = _RecordingFakePlatform()..info['online'] = true;
    final spokenController = await _todayController(gateway, recordingPlatform);
    await tester.pumpWidget(WebLearningApp(controller: spokenController));
    await tester.pumpAndSettle();

    await _recordTranscript(tester);
    await tester.tap(find.widgetWithText(FilledButton, '生成英文'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, '后来改写的新内容');
    await tester.pump();
    gateway.prepareResponse!.complete({
      'segments': [
        {
          'segmentId': newId(),
          'orderIndex': 0,
          'originalText': '嗯，我今天终于做完了。',
          'sourceText': '我今天终于做完了。',
          'removedText': ['嗯'],
          'selected': true,
        },
      ],
    });
    await tester.pumpAndSettle();

    expect(gateway.generationSources, isEmpty);
    expect(gateway.batchCalls, 0);
    expect(spokenController.todayInput, '后来改写的新内容');
    await _disposeTodayController(tester, spokenController);
  });

  testWidgets(
    'today preparation editor refreshes text when segment count stays the same',
    (tester) async {
      controller.state.preferences.onboarded = true;
      controller.state.preparationDraft = PreparationDraft(
        id: newId(),
        sourceText: '长文',
        segments: [
          PreparationSegment(id: newId(), sourceText: '第一段'),
          PreparationSegment(id: newId(), sourceText: '第二段'),
        ],
      );
      controller.notifyListeners();
      await tester.pumpWidget(WebLearningApp(controller: controller));
      await tester.pumpAndSettle();
      var fields = find.byType(TextField);
      expect(fields, findsNWidgets(3));
      expect(tester.widget<TextField>(fields.at(1)).controller!.text, '第一段');

      controller.state.preparationDraft!.segments.first.sourceText = '更新后的第一段';
      controller.notifyListeners();
      await tester.pumpAndSettle();
      fields = find.byType(TextField);
      expect(
        tester.widget<TextField>(fields.at(1)).controller!.text,
        '更新后的第一段',
      );
    },
  );

  testWidgets('today preparation removes a segment and can undo it', (
    tester,
  ) async {
    controller.state.preferences.onboarded = true;
    controller.state.preparationDraft = PreparationDraft(
      id: newId(),
      sourceText: '长文',
      segments: [
        PreparationSegment(id: newId(), sourceText: '第一段'),
        PreparationSegment(id: newId(), sourceText: '第二段'),
        PreparationSegment(id: newId(), sourceText: '第三段'),
      ],
    );
    controller.notifyListeners();
    await tester.pumpWidget(WebLearningApp(controller: controller));
    await tester.pumpAndSettle();

    final remove = find.byTooltip('不练习这句').first;
    await tester.ensureVisible(remove);
    await tester.tap(remove);
    await tester.pumpAndSettle();

    expect(
      controller.state.preparationDraft!.segments.map((s) => s.sourceText),
      ['第二段', '第三段'],
    );
    expect(find.text('第一段'), findsNothing);

    await tester.tap(find.widgetWithText(TextButton, '撤销'));
    await tester.pumpAndSettle();
    expect(
      controller.state.preparationDraft!.segments.map((s) => s.sourceText),
      ['第一段', '第二段', '第三段'],
    );
  });

  testWidgets('today preparation skips empty segments during generation', (
    tester,
  ) async {
    final gateway = CaptureGateway();
    final local = LearningController(
      gateway: gateway,
      platform: platform,
      seeds: List.generate(3, (index) => _seed(index + 1)),
      polling: false,
    );
    addTearDown(local.dispose);
    platform.info['online'] = true;
    await local.initialize();
    local.state.preferences
      ..onboarded = true
      ..uiLocale = 'zh-Hans';
    local.state.preparationDraft = PreparationDraft(
      id: newId(),
      sourceText: '长文',
      segments: [
        PreparationSegment(id: newId(), sourceText: '第一段'),
        PreparationSegment(id: newId(), sourceText: ''),
        PreparationSegment(id: newId(), sourceText: '第三段'),
      ],
    );
    await tester.pumpWidget(WebLearningApp(controller: local));
    await tester.pumpAndSettle();

    final generate = find.widgetWithText(FilledButton, '确认并生成');
    await tester.ensureVisible(generate);
    await tester.tap(generate);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(
      local.error,
      isNull,
      reason:
          'error=${local.error}; '
          'draft=${local.preparationDraft?.segments.length}; '
          'busy=${local.busy}',
    );
    expect(find.text('请补全每一个分句，再继续生成。'), findsNothing);
    expect(gateway.batchSegmentTexts, [
      ['第一段', '第三段'],
    ]);
    // Let the auto-dismiss notice timer fire before the test ends.
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('today preparation uses single generation for one kept segment', (
    tester,
  ) async {
    final gateway = CaptureGateway()..fail = false;
    final local = LearningController(
      gateway: gateway,
      platform: platform,
      seeds: List.generate(2, (index) => _seed(index + 1)),
      polling: false,
    );
    addTearDown(local.dispose);
    platform.info['online'] = true;
    await local.initialize();
    local.state.preferences
      ..onboarded = true
      ..uiLocale = 'zh-Hans';
    local.state.preparationDraft = PreparationDraft(
      id: newId(),
      sourceText: '长文',
      segments: [
        PreparationSegment(id: newId(), sourceText: '唯一一段'),
        PreparationSegment(id: newId(), sourceText: ''),
      ],
    );
    await tester.pumpWidget(WebLearningApp(controller: local));
    await tester.pumpAndSettle();

    final generate = find.widgetWithText(FilledButton, '确认并生成');
    await tester.ensureVisible(generate);
    await tester.tap(generate);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(
      local.error,
      isNull,
      reason:
          'error=${local.error}; '
          'draft=${local.preparationDraft?.segments.length}; '
          'busy=${local.busy}',
    );
    expect(gateway.batchCalls, 0);
    expect(gateway.requests, hasLength(1));
    // Let the auto-dismiss notice timer fire before the test ends.
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('today last segment button cancels preparation', (tester) async {
    controller.state.preferences.onboarded = true;
    controller.state.preparationDraft = PreparationDraft(
      id: newId(),
      sourceText: '长文',
      segments: [PreparationSegment(id: newId(), sourceText: '唯一一段')],
    );
    await tester.pumpWidget(WebLearningApp(controller: controller));
    await tester.pumpAndSettle();

    final cancel = find.byTooltip('取消整理');
    await tester.ensureVisible(cancel);
    await tester.tap(cancel);
    await tester.pumpAndSettle();
    expect(controller.preparationDraft, isNull);
  });

  testWidgets(
    'companion rail hides memories while the feature is unavailable',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      controller.state.preferences.onboarded = true;
      controller.state.memories.addAll({
        'first_name': DateTime.now(),
        'first_seed': DateTime.now(),
        'first_listen': DateTime.now(),
      });
      controller.navigate(1);
      await tester.pumpWidget(WebLearningApp(controller: controller));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('成长回忆'), findsNothing);
      expect(find.text('查看全部回忆'), findsNothing);
    },
  );

  testWidgets('notes page hides the growth memories entry card', (
    tester,
  ) async {
    controller.state.preferences.onboarded = true;
    controller.state.memories.addAll({
      'first_name': DateTime.now(),
      'first_seed': DateTime.now(),
    });
    controller.navigate(3);
    await tester.pumpWidget(WebLearningApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('成长回忆'), findsNothing);
    expect(find.text('打开回忆册'), findsNothing);
  });

  testWidgets('formal notes entry shows full sentences and routes actions', (
    tester,
  ) async {
    controller.state.preferences.onboarded = true;
    controller.state.sentences
      ..clear()
      ..addAll([
        LearnSentence(
          id: 'formal-one',
          source: '老板又在开空头支票。',
          target: 'My boss is making empty promises again.',
          category: 'work',
          vocabulary: [
            VocabularyEntry(
              id: 'formal-vocab',
              text: 'empty promises',
              meaning: '不会兑现的承诺',
            ),
          ],
        ),
        LearnSentence(
          id: 'formal-two',
          source: '今天又要加班到很晚。',
          target: 'I have to work late again today.',
          category: 'work',
        ),
      ]);
    controller.navigate(3);
    await tester.pumpWidget(WebLearningApp(controller: controller));
    await tester.pumpAndSettle();

    expect(
      tester
          .widgetList<RichText>(find.byType(RichText))
          .any(
            (richText) =>
                richText.text.toPlainText().replaceAll(
                  '\uFFFC',
                  'empty promises',
                ) ==
                'My boss is making empty promises again.',
          ),
      isTrue,
    );
    expect(find.text('I have to work late again today.'), findsOneWidget);
    expect(find.text('选一句查看详情'), findsNothing);
    expect(find.text('Boss is making empty promises again. ...'), findsNothing);
    await tester.tap(find.text('听这句').first);
    await tester.pumpAndSettle();
    expect(controller.tab, 1);
    expect(controller.activeSentence?.id, 'formal-one');
  });

  testWidgets('listen playback button pauses and resumes the selected audio', (
    tester,
  ) async {
    controller.state.preferences.onboarded = true;
    controller.state.sentences.add(_seed(1));
    await controller.play(controller.state.sentences.single);
    controller.navigate(1);
    await tester.pumpWidget(WebLearningApp(controller: controller));
    await tester.pumpAndSettle();
    final playbackButton = find.byKey(const ValueKey('listen-playback'));
    expect(
      find.descendant(of: playbackButton, matching: find.text('暂停')),
      findsOneWidget,
    );
    await tester.ensureVisible(playbackButton);
    await tester.tap(playbackButton);
    await tester.pumpAndSettle();
    expect(platform.actions, contains('audioPause'));
    expect(controller.playback['state'], 'paused');
    platform.actions.clear();
    expect(
      find.descendant(of: playbackButton, matching: find.text('继续播放')),
      findsOneWidget,
    );
    await tester.tap(playbackButton);
    await tester.pumpAndSettle();
    expect(platform.actions, contains('audioResume'));
    expect(platform.actions, isNot(contains('audioPlay')));
  });

  testWidgets('listen pin moves a sentence first and shows the purple state', (
    tester,
  ) async {
    controller.state.preferences.onboarded = true;
    final first = LearnSentence(
      id: newId(),
      source: '第一句',
      target: 'First sentence.',
    );
    final second = LearnSentence(
      id: newId(),
      source: '第二句',
      target: 'Second sentence.',
    );
    controller.state.sentences.addAll([first, second]);
    controller.navigate(1);
    await controller.selectListenSentence(first.id);
    await tester.pumpWidget(WebLearningApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('listen-library-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('listen-pin-${second.id}')));
    await tester.pumpAndSettle();

    final pinnedRow = find.byKey(ValueKey('listen-sentence-row-${second.id}'));
    final firstRow = find.byKey(ValueKey('listen-sentence-row-${first.id}'));
    expect(
      tester.getTopLeft(pinnedRow).dy,
      lessThan(tester.getTopLeft(firstRow).dy),
    );
    final unpin = find.byKey(ValueKey('listen-pin-${second.id}'));
    final unpinIcon = tester.widget<IconButton>(unpin).icon as Icon;
    expect(unpinIcon.color, SelahColors.lavender);

    await tester.tap(pinnedRow);
    await tester.pumpAndSettle();
    expect(controller.activeSentence?.id, second.id);
    expect(find.text('已置顶'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('listen-library-button')),
    );
    await tester.tap(find.byKey(const ValueKey('listen-library-button')));
    await tester.pumpAndSettle();
    final selectedUnpin = find.byKey(ValueKey('listen-pin-${second.id}'));
    await tester.tap(selectedUnpin);
    await tester.pumpAndSettle();
    expect(find.text('已置顶'), findsNothing);
  });

  testWidgets('switching sentences does not reuse another audio progress', (
    tester,
  ) async {
    controller.state.preferences.onboarded = true;
    final first = _seed(1);
    final second = _seed(2);
    controller.state.sentences.addAll([first, second]);
    await controller.play(first);
    controller.playback.addAll({'positionMs': 4000, 'durationMs': 12000});
    controller.navigate(1);
    await tester.pumpWidget(WebLearningApp(controller: controller));
    await tester.pumpAndSettle();
    expect(find.text('0:04'), findsOneWidget);
    expect(find.text('0:12'), findsOneWidget);
    expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNotNull);

    controller.selectSentence(second);
    await tester.pumpAndSettle();
    expect(find.text('0:04'), findsNothing);
    expect(find.text('0:12'), findsNothing);
    expect(find.text('0:00'), findsNWidgets(2));
    expect(tester.widget<Slider>(find.byType(Slider)).value, 0);
    expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNull);

    controller.selectSentence(first);
    await tester.pumpAndSettle();
    expect(find.text('0:04'), findsOneWidget);
    expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNotNull);
  });

  testWidgets('tab navigation preserves an unfinished expression', (
    tester,
  ) async {
    controller.state.preferences.onboarded = true;
    await tester.pumpWidget(WebLearningApp(controller: controller));
    await _openTodayComposer(tester);
    await tester.enterText(find.byType(TextField).first, '今天想记录还没说完的事');
    await tester.tap(find.text('笔记'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('今天'));
    await tester.pumpAndSettle();
    expect(find.text('今天想记录还没说完的事'), findsOneWidget);
  });

  testWidgets(
    'practice rates the first due sentence without a manual selection',
    (tester) async {
      controller.state.preferences
        ..onboarded = true
        ..name = '小芽';
      final due = _seed(1)
        ..reviewState = 'learning'
        ..nextReviewAt = DateTime.now().subtract(const Duration(minutes: 1));
      controller.state.sentences.add(due);
      controller.notifyListeners();

      await tester.pumpWidget(WebLearningApp(controller: controller));
      await tester.tap(find.text('练习'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('揭示答案'));
      await tester.pump();
      await tester.ensureVisible(find.text('很顺'));
      await tester.tap(find.text('很顺'));
      await tester.pump();
      await tester.ensureVisible(find.text('完成并保存'));
      await tester.tap(find.text('完成并保存'));
      await tester.runAsync(() async {
        for (var i = 0; i < 20 && controller.busy; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      });
      await tester.pump(const Duration(milliseconds: 100));

      expect(controller.error, isNull);
      expect(controller.state.sentences.single.reviewState, 'familiar');
      // Let the companion cue and auto-dismiss notice timers fire.
      await tester.pump(const Duration(seconds: 4));
    },
  );
}
