import 'dart:convert';
import '../domain/learning_models.dart';
import '../platform/learning_platform.dart';

class LearningStore {
  LearningStore(this.platform);
  final LearningPlatform platform;
  Future<LearningSnapshot> load(String accountId) async {
    final value = await platform.invoke('load', {'accountId': accountId});
    if (value == null) {
      return LearningSnapshot.empty()..accountScope = accountId;
    }
    return LearningSnapshot.importBackup(jsonEncode(value));
  }

  Future<void> save(String accountId, LearningSnapshot snapshot) async {
    snapshot.accountScope = accountId;
    await platform.invoke('save', {
      'accountId': accountId,
      'snapshot': snapshot.toBackup(),
    });
  }
}
