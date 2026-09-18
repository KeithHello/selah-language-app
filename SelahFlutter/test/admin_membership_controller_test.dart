import 'package:flutter_test/flutter_test.dart';
import 'package:selah/web/admin/admin_controller.dart';
import 'package:selah/web/data/learning_gateway.dart';
import 'package:selah/web/domain/admin_audience.dart';
import 'package:selah/web/domain/admin_membership.dart';
import 'package:selah/web/domain/learning_models.dart';

class _AdminGateway implements LearningGateway {
  final calls = <String>[];
  final requestBodies = <Map<String, dynamic>>[];
  @override
  bool get configured => true;
  @override
  String? get userId => '11111111-1111-1111-1111-111111111111';
  @override
  String? get email => 'admin@example.com';
  @override
  Stream<String?> get accountChanges => const Stream.empty();

  @override
  Future<Map<String, dynamic>> invoke(
    String function,
    Map<String, dynamic> body, {
    bool get = false,
  }) async {
    calls.add(function);
    requestBodies.add(Map<String, dynamic>.from(body));
    if (function == 'admin-summary') {
      if (body['view'] == 'audience') {
        return {
          'audience': {
            'dimension': body['dimension'],
            'registeredCount': 20,
            'profileCoveredCount': 12,
            'unansweredCount': 5,
            'refusalCount': 2,
            'withdrawnCount': 1,
            'dataStatus': 'ready',
            'groups': [],
          },
        };
      }
      return {
        'summary': {
          'activeLearners': 1,
          'learningSessions': 1,
          'effectiveLearningMinutes': 2,
          'featureUsage': [],
          'dailyActivity': [],
          'api': {},
        },
        'attempts': [],
      };
    }
    if (function == 'admin-service-controls') {
      final update = body['action'] == 'update';
      return {
        'version': '2026-09-12-v1',
        'configured': true,
        'membershipEnforcementEnabled': update
            ? body['membershipEnforcementEnabled'] ?? false
            : false,
        'trialSignupsEnabled': false,
        'membershipSalesEnabled': false,
        'generationEnabled': true,
        'anonymousTestModeEnabled': update
            ? body['anonymousTestModeEnabled'] ?? false
            : false,
      };
    }
    if (function == 'admin-users') {
      return {
        'users': [
          {
            'userId': '22222222-2222-2222-2222-222222222222',
            'emailMasked': 'u***@example.com',
            'plan': 'free',
            'status': 'none',
            'createdAt': '2026-09-12T00:00:00Z',
          },
        ],
      };
    }
    throw const LearningFailure('unexpected function');
  }

  @override
  bool get isAnonymous => false;

  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signInAnonymously() async {}
  @override
  Future<void> signUp(
    String email,
    String password, {
    String? emailRedirectTo,
  }) async {}
  @override
  Future<void> resetPassword(String email, {String? emailRedirectTo}) async {}
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
    'loads controls and masked user list alongside dashboard summary',
    () async {
      final gateway = _AdminGateway();
      final controller = AdminController(gateway: gateway);
      await controller.load();

      expect(controller.hasData, isTrue);
      expect(controller.controls.configured, isTrue);
      expect(controller.controls.membershipEnforcementEnabled, isFalse);
      expect(controller.users.single.emailMasked, 'u***@example.com');
      expect(
        gateway.calls,
        containsAll(<String>[
          'admin-summary',
          'admin-service-controls',
          'admin-users',
        ]),
      );
      controller.dispose();
    },
  );

  test(
    'loads audience aggregates through the admin summary function',
    () async {
      final controller = AdminController(gateway: _AdminGateway());
      await controller.loadAudience(dimension: AdminAudienceDimension.ageGroup);
      expect(controller.audience?.dimension, AdminAudienceDimension.ageGroup);
      expect(controller.audience?.profileCoveredCount, 12);
      expect(controller.audienceError, isNull);
      controller.dispose();
    },
  );

  test('updates the anonymous test switch with its own service flag', () async {
    final gateway = _AdminGateway();
    final controller = AdminController(gateway: gateway);
    addTearDown(controller.dispose);
    await controller.load();

    final success = await controller.updateControls(
      anonymousTestModeEnabled: true,
      reason: 'dashboard_anonymousTest_toggle',
    );

    expect(success, isTrue);
    expect(controller.controls.anonymousTestModeEnabled, isTrue);
  });

  test('derives production as the safe fallback for mixed service flags', () {
    const controls = AdminServiceControls(
      configured: true,
      anonymousTestModeEnabled: true,
      membershipEnforcementEnabled: true,
    );
    expect(controls.productMode, ProductMode.production);
    expect(controls.productModeNeedsNormalization, isTrue);
    expect(
      const AdminServiceControls(
        configured: true,
        anonymousTestModeEnabled: true,
        membershipEnforcementEnabled: false,
        generationEnabled: true,
      ).productModeNeedsNormalization,
      isFalse,
    );
    expect(
      const AdminServiceControls(
        configured: true,
        anonymousTestModeEnabled: false,
        membershipEnforcementEnabled: true,
        generationEnabled: true,
      ).productModeNeedsNormalization,
      isFalse,
    );
  });

  test('sets test mode as one coherent service configuration', () async {
    final gateway = _AdminGateway();
    final controller = AdminController(gateway: gateway);
    addTearDown(controller.dispose);
    await controller.load();

    final success = await controller.setProductMode(
      ProductMode.test,
      reason: 'dashboard_product_mode_toggle',
    );

    expect(success, isTrue);
    final request = gateway.requestBodies.last;
    expect(request['anonymousTestModeEnabled'], isTrue);
    expect(request['membershipEnforcementEnabled'], isFalse);
    expect(request['generationEnabled'], isTrue);
  });
}
