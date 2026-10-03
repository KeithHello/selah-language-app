import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/web/data/learning_gateway.dart';
import 'package:selah/web/domain/learning_models.dart';
import 'package:selah/web/domain/research_profile.dart';
import 'package:selah/web/research_profile_controller.dart';
import 'package:selah/web/ui/research_profile_widgets.dart';

class _Gateway implements LearningGateway {
  _Gateway({this.failure});

  LearningFailure? failure;

  @override
  bool get configured => true;
  @override
  String? get userId => '11111111-1111-1111-1111-111111111111';
  @override
  String? get email => 'tester@example.com';
  @override
  Stream<String?> get accountChanges => const Stream.empty();
  @override
  Future<Map<String, dynamic>> invoke(
    String function,
    Map<String, dynamic> body, {
    bool get = false,
  }) async {
    if (failure != null) throw failure!;
    return {
      'profile': body['operation'] == 'withdraw' ? {} : body['profile'] ?? {},
      'promptState': body['operation'] == 'skip' ? 'skipped' : 'answered',
      'consentState': body['operation'] == 'save' ? 'granted' : 'none',
      'revision': 1,
    };
  }

  @override
  bool get isAnonymous => false;

  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signUp(
    String email,
    String password, {
    String? emailRedirectTo,
  }) async {}
  @override
  Future<void> resetPassword(String email, {String? emailRedirectTo}) async {}
  @override
  Future<void> updatePassword(String newPassword) async {}
  @override
  Future<void> signOut() async {}
  @override
  Future<LearningSnapshot> synchronize(LearningSnapshot local) async => local;
  @override
  Future<Map<String, dynamic>?> seedAudio(String seedId, String voice) async =>
      null;
  @override
  Future<String> transcribe(
    Map<String, dynamic> recording,
    String requestId,
  ) async => '';
}

void main() {
  testWidgets('profile form leads with learning goal and level', (
    tester,
  ) async {
    final controller = ResearchProfileController(gateway: _Gateway());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResearchProfileForm(
            controller: controller,
            uiLocale: 'zh-Hans',
            initial: const ResearchProfile(),
            showIdentityFields: true,
          ),
        ),
      ),
    );
    expect(find.text('跳过'), findsOneWidget);
    expect(find.textContaining('学习目标与目前的英语感受'), findsOneWidget);
    expect(find.textContaining('不会依据这些资料调整生成内容'), findsOneWidget);
    expect(find.textContaining('点击「保存资料」即表示你自愿提交这些资料'), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.text('学习目标'), findsOneWidget);
    expect(find.text('英语自评'), findsOneWidget);
    expect(find.text('更多背景资料（可选）'), findsOneWidget);
    // Background fields stay collapsed until the user expands them.
    expect(find.text('年龄段'), findsNothing);
    expect(find.text('性别'), findsNothing);
    // Saving is available immediately after the purpose notice; skipping
    // stays available as well.
    final saveButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '保存资料'),
    );
    expect(saveButton.onPressed, isNotNull);
    controller.dispose();
  });

  testWidgets('background section expands and keeps saved selections', (
    tester,
  ) async {
    final controller = ResearchProfileController(gateway: _Gateway());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResearchProfileForm(
            controller: controller,
            uiLocale: 'zh-Hans',
            initial: const ResearchProfile(ageGroup: 'age_25_34'),
            showIdentityFields: true,
          ),
        ),
      ),
    );
    // Existing background answers expand the section automatically.
    expect(find.text('25～34 岁'), findsOneWidget);
    expect(find.text('年龄段'), findsOneWidget);
    expect(find.text('身份'), findsOneWidget);
    expect(find.text('性别'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('save action records an optional profile without a checkbox', (
    tester,
  ) async {
    final controller = ResearchProfileController(gateway: _Gateway());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResearchProfileForm(
            controller: controller,
            uiLocale: 'zh-Hans',
            initial: const ResearchProfile(learningGoal: 'daily'),
            showIdentityFields: true,
          ),
        ),
      ),
    );
    expect(find.byType(Checkbox), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, '保存资料'));
    await tester.pumpAndSettle();
    expect(controller.profile.learningGoal, 'daily');
    expect(controller.consentState, ResearchProfileConsentState.granted);
    controller.dispose();
  });

  testWidgets('load failure shows a localized notice and retry', (
    tester,
  ) async {
    final controller = ResearchProfileController(
      gateway: _Gateway(
        failure: const LearningFailure(
          '研究资料暂时不可用，学习不受影响。',
          code: 'profile_unavailable',
        ),
      ),
    );
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResearchProfileEntry(
            controller: controller,
            uiLocale: 'zh-Hans',
          ),
        ),
      ),
    );
    expect(find.text('这部分目前暂未开放，学习不受影响。'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    controller.dispose();
  });

  testWidgets('load failure notice follows the interface locale', (
    tester,
  ) async {
    final controller = ResearchProfileController(
      gateway: _Gateway(
        failure: const LearningFailure(
          '研究资料暂时不可用，学习不受影响。',
          code: 'profile_unavailable',
        ),
      ),
    );
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResearchProfileEntry(
            controller: controller,
            uiLocale: 'zh-Hant',
          ),
        ),
      ),
    );
    expect(find.text('這部分目前暫未開放，學習不受影響。'), findsOneWidget);
    expect(find.text('重試'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('summary shows saved learning answers and guarded withdraw', (
    tester,
  ) async {
    final controller = ResearchProfileController(gateway: _Gateway());
    controller.profile = const ResearchProfile(learningGoal: 'daily');
    controller.promptState = ResearchProfilePromptState.answered;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResearchProfileSummary(
            controller: controller,
            uiLocale: 'zh-Hans',
          ),
        ),
      ),
    );
    expect(find.text('学习目标：日常交流'), findsOneWidget);
    await tester.tap(find.text('撤回并清除资料'));
    await tester.pumpAndSettle();
    expect(find.text('撤回并清除资料？'), findsOneWidget);
    // Cancel keeps the saved answers.
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('学习目标：日常交流'), findsOneWidget);
    expect(controller.promptState, ResearchProfilePromptState.answered);
    controller.dispose();
  });

  testWidgets('invite card offers an optional settings handoff and skip', (
    tester,
  ) async {
    final controller = ResearchProfileController(gateway: _Gateway());
    controller.canInvite = true;
    controller.promptState = ResearchProfilePromptState.offered;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResearchProfileInvite(
            controller: controller,
            uiLocale: 'zh-Hans',
            onOpen: () {},
          ),
        ),
      ),
    );
    expect(find.text('填写资料'), findsOneWidget);
    expect(find.text('跳过'), findsOneWidget);
    controller.dispose();
  });
}
