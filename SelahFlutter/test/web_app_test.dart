import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/domain/selah_enums.dart';
import 'package:selah/web/data/learning_gateway.dart';
import 'package:selah/web/domain/learning_models.dart';
import 'package:selah/web/learning_controller.dart';
import 'package:selah/web/platform/learning_platform.dart';
import 'package:selah/web/ui/web_learning_app.dart';
import 'package:selah/web/ui/plush_companion.dart';
import 'package:selah/web/ui/web_start_action.dart';
import 'package:selah/web/ui/companion_dice_button.dart';
import 'web_controller_test.dart' show FakeGateway;

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
    expect(
      find.textContaining('\u60f3\u8bf4\u70b9\u4ec0\u4e48'),
      findsOneWidget,
    );
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
    expect(
      find.textContaining('\u60f3\u8bf4\u70b9\u4ec0\u4e48'),
      findsOneWidget,
    );

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

  testWidgets('unsigned generation starts anonymously without a login banner', (
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
    await configuredController.generate('今天想早点休息。');

    await tester.pumpWidget(WebLearningApp(controller: configuredController));
    await tester.pumpAndSettle();

    expect(configuredController.hasSession, isTrue);
    expect(find.text('请先登录，便能生成自己的英文和语音。'), findsNothing);
    await configuredController.sync();
    await tester.pumpAndSettle();
  });

  testWidgets(
    'anonymous budget errors stay local without a login call to action',
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
      await configuredController.ensureCloudSession();
      configuredController.errorCode = 'service_budget_protected';
      configuredController.error = '今天的测试预算已用完，请明天再试。';
      configuredController.notifyListeners();

      await tester.pumpWidget(WebLearningApp(controller: configuredController));
      expect(find.text('今天的测试预算已用完，请明天再试。'), findsOneWidget);
      expect(find.text('注册／登录'), findsNothing);
    },
  );

  testWidgets('production anonymous restriction keeps an inline login action', (
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
      ..name = '小芽'
      ..uiLocale = 'zh-Hans';
    await configuredController.ensureCloudSession();
    configuredController.errorCode = 'anonymous_test_ended';
    configuredController.error = '匿名测试已结束。';
    configuredController.notifyListeners();

    await tester.pumpWidget(WebLearningApp(controller: configuredController));
    expect(find.text('注册／登录'), findsOneWidget);
    expect(find.text('请登录'), findsOneWidget);
  });

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
    expect(find.textContaining('填写资料完全自愿'), findsOneWidget);
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
      expect(find.text('例：今日はずっと先延ばしにしていたことを終えました。'), findsOneWidget);
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
        expect(find.textContaining('OpenAI GPT'), findsOneWidget);
        expect(find.text('今天，想说点什么？'), findsOneWidget);
        expect(
          tester.getSize(find.byType(PlushCompanion)).width,
          closeTo(56, 1),
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
    await tester.enterText(find.byType(TextField), '今天想练习一句英文。');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('today input from the formal page is wired to the controller', (
    tester,
  ) async {
    controller.state.preferences.onboarded = true;
    await tester.pumpWidget(WebLearningApp(controller: controller));
    await tester.enterText(find.byType(TextField).first, '刷新后还在的输入');
    await tester.pump(const Duration(milliseconds: 450));
    expect(controller.todayInput, '刷新后还在的输入');
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

  testWidgets('today preparation rejects an empty edited segment', (
    tester,
  ) async {
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

    await tester.enterText(find.byType(TextField).at(1), '');
    final generate = find.widgetWithText(FilledButton, '确认并生成');
    await tester.ensureVisible(generate);
    await tester.tap(generate);
    await tester.pumpAndSettle();

    expect(find.text('请补全每一个分句，再继续生成。'), findsOneWidget);
    expect(controller.state.preparationDraft!.segments.first.sourceText, '第一段');
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
    expect(find.widgetWithText(FilledButton, '暂停'), findsOneWidget);
    await tester.ensureVisible(find.widgetWithText(FilledButton, '暂停'));
    await tester.tap(find.widgetWithText(FilledButton, '暂停'));
    await tester.pumpAndSettle();
    expect(platform.actions, contains('audioPause'));
    expect(controller.playback['state'], 'paused');
    platform.actions.clear();
    await tester.ensureVisible(find.widgetWithText(FilledButton, '播放'));
    await tester.tap(find.widgetWithText(FilledButton, '播放'));
    await tester.pumpAndSettle();
    expect(platform.actions, contains('audioResume'));
    expect(platform.actions, isNot(contains('audioPlay')));
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
      await tester.pump(const Duration(milliseconds: 1500));
    },
  );
}
