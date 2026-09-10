abstract class LearningPlatform {
  Future<Object?> invoke(
    String action, [
    Map<String, Object?> payload = const {},
  ]);
}
