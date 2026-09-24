import '../domain/learning_models.dart';

class LearningFailure implements Exception {
  const LearningFailure(
    this.message, {
    this.code = 'unavailable',
    this.feature,
    this.resetsAt,
    this.currentPeriodEndsAt,
    this.renewalRequired = false,
    this.retryAfterSeconds,
    this.requestId,
  });
  final String message;
  final String code;
  final String? feature;
  final DateTime? resetsAt;
  final DateTime? currentPeriodEndsAt;
  final bool renewalRequired;
  final int? retryAfterSeconds;
  final String? requestId;
  @override
  String toString() => message;
}

abstract class LearningGateway {
  bool get configured;
  String? get userId;
  String? get email;
  bool get isAnonymous;
  Stream<String?> get accountChanges;
  Future<void> signIn(String email, String password);
  Future<void> signUp(String email, String password, {String? emailRedirectTo});
  Future<void> resetPassword(String email, {String? emailRedirectTo});
  Future<void> signOut();
  Future<Map<String, dynamic>> invoke(
    String function,
    Map<String, dynamic> body, {
    bool get = false,
  });
  Future<LearningSnapshot> synchronize(LearningSnapshot local);
  Future<Map<String, dynamic>?> seedAudio(String seedId, String voice);
  Future<String> transcribe(Map<String, dynamic> recording, String requestId);
}

class UnconfiguredGateway implements LearningGateway {
  @override
  bool get configured => false;
  @override
  String? get userId => null;
  @override
  String? get email => null;
  @override
  bool get isAnonymous => false;
  @override
  Stream<String?> get accountChanges => const Stream.empty();
  Never _missing() => throw const LearningFailure(
    '在线服务尚未配置。你可以继续学习已保存的内容。',
    code: 'not_configured',
  );
  @override
  Future<void> signIn(String email, String password) async => _missing();
  @override
  Future<void> signUp(
    String email,
    String password, {
    String? emailRedirectTo,
  }) async => _missing();
  @override
  Future<void> resetPassword(String email, {String? emailRedirectTo}) async =>
      _missing();
  @override
  Future<void> signOut() async {}
  @override
  Future<Map<String, dynamic>> invoke(
    String function,
    Map<String, dynamic> body, {
    bool get = false,
  }) async => _missing();
  @override
  Future<LearningSnapshot> synchronize(LearningSnapshot local) async =>
      _missing();
  @override
  Future<Map<String, dynamic>?> seedAudio(String seedId, String voice) async =>
      _missing();
  @override
  Future<String> transcribe(
    Map<String, dynamic> recording,
    String requestId,
  ) async => _missing();
}
