import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/web/data/learning_gateway.dart';
import 'package:selah/web/domain/learning_models.dart';
import 'package:selah/web/domain/research_profile.dart';
import 'package:selah/web/research_profile_controller.dart';
import 'package:selah/web/ui/research_profile_widgets.dart';

class _Gateway implements LearningGateway {
  @override
  bool get configured => true;
  @override
  String? get userId => '11111111-1111-1111-1111-111111111111';
  @override
  String? get email => 'tester@example.com';
  @override
  Stream<String?> get accountChanges => const Stream.empty();
  @override
  Future<Map<String, dynamic>> invoke(String function, Map<String, dynamic> body, {bool get = false}) async => {
    'profile': body['operation'] == 'withdraw' ? {} : body['profile'] ?? {},
    'promptState': body['operation'] == 'skip' ? 'skipped' : 'answered',
    'consentState': body['operation'] == 'save' ? 'granted' : 'none',
    'revision': 1,
  };
  @override
  bool get isAnonymous => false;

  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signInAnonymously() async {}
  @override
  Future<void> signUp(String email, String password, {String? emailRedirectTo}) async {}
  @override
  Future<void> resetPassword(String email, {String? emailRedirectTo}) async {}
  @override
  Future<void> signOut() async {}
  @override
  Future<LearningSnapshot> synchronize(LearningSnapshot local) async => local;
  @override
  Future<Map<String, dynamic>?> seedAudio(String seedId, String voice) async => null;
  @override
  Future<String> transcribe(Map<String, dynamic> recording, String requestId) async => '';
}

void main() {
  testWidgets('optional profile form exposes skip and consent is not preselected', (tester) async {
    final controller = ResearchProfileController(gateway: _Gateway());
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ResearchProfileForm(
          controller: controller,
          uiLocale: 'zh-Hans',
          initial: const ResearchProfile(),
          showIdentityFields: true,
        ),
      ),
    ));
    expect(find.text('可选资料'), findsOneWidget);
    expect(find.text('跳过'), findsOneWidget);
    expect(find.textContaining('用于用户研究与改进学习体验'), findsOneWidget);
    expect(find.byType(Checkbox), findsOneWidget);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, false);
    expect(find.text('学习目标'), findsOneWidget);
    expect(find.text('性别'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('invite card offers an optional settings handoff and skip', (tester) async {
    final controller = ResearchProfileController(gateway: _Gateway());
    controller.canInvite = true;
    controller.promptState = ResearchProfilePromptState.offered;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ResearchProfileInvite(
          controller: controller,
          uiLocale: 'zh-Hans',
          onOpen: () {},
        ),
      ),
    ));
    expect(find.text('填写资料'), findsOneWidget);
    expect(find.text('跳过'), findsOneWidget);
    controller.dispose();
  });
}
