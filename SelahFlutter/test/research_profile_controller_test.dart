import 'package:flutter_test/flutter_test.dart';
import 'package:selah/web/data/learning_gateway.dart';
import 'package:selah/web/domain/learning_models.dart';
import 'package:selah/web/domain/research_profile.dart';
import 'package:selah/web/research_profile_controller.dart';

class _Gateway implements LearningGateway {
  _Gateway({this.response = const {}, this.failure});

  Map<String, dynamic> response;
  LearningFailure? failure;
  final calls = <({String function, Map<String, dynamic> body, bool get})>[];

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
    calls.add((function: function, body: body, get: get));
    if (body['operation'] == 'offer') {
      return {...response, 'promptState': 'offered', 'canInvite': true};
    }
    if (body['operation'] == 'skip') {
      return {...response, 'promptState': 'skipped', 'canInvite': false};
    }
    if (body['operation'] == 'withdraw') {
      return {
        ...response,
        'profile': {},
        'promptState': 'withdrawn',
        'consentState': 'withdrawn',
        'canInvite': false,
      };
    }
    return response;
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
  test(
    'loads own profile and keeps refusal distinct from an empty answer',
    () async {
      final gateway = _Gateway(
        response: {
          'profile': {
            'learningGoal': 'work',
            'englishLevel': null,
            'ageGroup': 'prefer_not_say',
            'lifeStage': null,
            'gender': null,
            'genderDescription': null,
          },
          'promptState': 'answered',
          'consentState': 'granted',
          'noticeVersion': '2026-09-12-v1',
          'revision': 4,
          'canInvite': false,
        },
      );
      final controller = ResearchProfileController(gateway: gateway);
      await controller.load();

      expect(controller.profile.learningGoal, 'work');
      expect(controller.profile.ageGroup, 'prefer_not_say');
      expect(controller.promptState, ResearchProfilePromptState.answered);
      expect(controller.consentState, ResearchProfileConsentState.granted);
      expect(controller.revision, 4);
      expect(gateway.calls.single.get, true);
      controller.dispose();
    },
  );

  test(
    'offers once after completed learning and allows skip without consent',
    () async {
      final gateway = _Gateway(
        response: {
          'profile': {},
          'promptState': 'unseen',
          'consentState': 'none',
          'canInvite': true,
          'revision': 0,
        },
      );
      final controller = ResearchProfileController(gateway: gateway);
      await controller.load();
      final offered = await controller.maybeOfferAfterLearning();
      expect(offered, true);
      expect(controller.promptState, ResearchProfilePromptState.offered);
      expect(gateway.calls.last.body['operation'], 'offer');

      final skipped = await controller.skip();
      expect(skipped, true);
      expect(controller.promptState, ResearchProfilePromptState.skipped);
      expect(gateway.calls.last.body['operation'], 'skip');
      expect(await controller.maybeOfferAfterLearning(), false);
      controller.dispose();
    },
  );

  test(
    'save requires consent and withdraw clears answers after server confirmation',
    () async {
      final gateway = _Gateway(
        response: {
          'profile': {
            'learningGoal': 'daily',
            'englishLevel': null,
            'ageGroup': null,
            'lifeStage': null,
            'gender': null,
            'genderDescription': null,
          },
          'promptState': 'answered',
          'consentState': 'granted',
          'revision': 2,
        },
      );
      final controller = ResearchProfileController(gateway: gateway);
      await controller.load();
      await expectLater(
        controller.save(
          const ResearchProfile(learningGoal: 'daily'),
          consent: false,
        ),
        throwsA(isA<LearningFailure>()),
      );
      await controller.save(
        const ResearchProfile(learningGoal: 'daily'),
        consent: true,
      );
      expect(controller.profile.learningGoal, 'daily');
      expect(gateway.calls.last.body['noticeVersion'], '2026-09-12-v1');
      expect(gateway.calls.last.body['expectedRevision'], 2);
      await controller.withdraw();
      expect(controller.profile.hasAnyAnswer, false);
      expect(controller.promptState, ResearchProfilePromptState.withdrawn);
      controller.dispose();
    },
  );

  test(
    'load failure keeps the error code for localized UI and clears after success',
    () async {
      final gateway = _Gateway(
        failure: const LearningFailure(
          '研究资料暂时不可用，学习不受影响。',
          code: 'profile_unavailable',
        ),
      );
      final controller = ResearchProfileController(gateway: gateway);
      await controller.load();

      expect(controller.loadError, true);
      expect(controller.errorCode, 'profile_unavailable');
      expect(controller.checked, true);

      gateway.failure = null;
      gateway.response = {
        'profile': {},
        'promptState': 'unseen',
        'consentState': 'none',
        'canInvite': true,
        'revision': 0,
      };
      await controller.load();

      expect(controller.loadError, false);
      expect(controller.errorCode, isNull);
      expect(controller.error, isNull);
      controller.dispose();
    },
  );
}
