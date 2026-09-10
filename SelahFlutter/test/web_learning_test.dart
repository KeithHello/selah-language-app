import 'package:flutter_test/flutter_test.dart';
import 'package:selah/web/domain/learning_models.dart';
import 'package:selah/web/domain/learning_engine.dart';

void main() {
  LearnSentence sentence() =>
      LearnSentence(id: newId(), source: '你好', target: 'Hello.');
  final at = DateTime(2026, 9, 5, 12);
  test('listening advances new sentence and schedules tomorrow', () {
    final s = sentence();
    LearningEngine.listen(s, at);
    expect(s.reviewState, 'learning');
    expect(s.listenedAt, at);
    expect(s.nextReviewAt, DateTime(2026, 9, 6, 12));
  });
  test(
    'recall follows original Swift states and intervals, failure resets',
    () {
      final s = sentence()..reviewState = 'learning';
      LearningEngine.rate(s, 'clear', at);
      expect(s.reviewState, 'familiar');
      expect(s.intervalDays, 3);
      LearningEngine.rate(s, 'clear', at);
      expect(s.reviewState, 'quiet');
      expect(s.intervalDays, 7);
      LearningEngine.rate(s, 'failed', at);
      expect(s.reviewState, 'learning');
      expect(s.lapseCount, 1);
      expect(s.intervalDays, 1);
    },
  );
  test('due excludes new, quiet and future sentences', () {
    final s = sentence()
      ..reviewState = 'learning'
      ..nextReviewAt = at;
    final future = sentence()
      ..reviewState = 'familiar'
      ..nextReviewAt = at.add(const Duration(days: 1));
    expect(LearningEngine.due([s, future, sentence()], at), [s]);
  });
  test('memory unlock is idempotent and comes from actual events', () {
    final state = LearningSnapshot.empty();
    state.preferences.onboarded = true;
    state.sentences.add(sentence());
    state.events.add(
      LearnEvent(
        id: newId(),
        type: 'listen_completed',
        sentenceId: state.sentences.first.id,
      ),
    );
    LearningEngine.unlock(state, at);
    final count = state.memories.length;
    LearningEngine.unlock(state, at);
    expect(state.memories.length, count);
    expect(state.memories.containsKey('first_listen'), isTrue);
    expect(state.memories.containsKey('first_practice'), isFalse);
  });

  test('growth progress uses real stage thresholds and never resets', () {
    LearningSnapshot snapshot(int sessions) {
      final state = LearningSnapshot.empty()
        ..preferences.onboarded = true;
      for (var i = 0; i < sessions; i++) {
        state.events.add(
          LearnEvent(
            id: newId(),
            type: i.isEven ? 'listen_completed' : 'practice_rated',
          ),
        );
      }
      return state;
    }

    expect(LearningEngine.growth(snapshot(0)).stage, 'sprout');
    expect(LearningEngine.growth(snapshot(4)).progress, closeTo(0.8, 0.001));
    expect(LearningEngine.growth(snapshot(5)).stage, 'leaf');
    expect(LearningEngine.growth(snapshot(5)).progress, 0);
    expect(LearningEngine.growth(snapshot(14)).stage, 'leaf');
    expect(LearningEngine.growth(snapshot(15)).stage, 'bud');
    expect(LearningEngine.growth(snapshot(29)).stage, 'bud');
    final bloom = LearningEngine.growth(snapshot(30));
    expect(bloom.stage, 'bloom');
    expect(bloom.progress, 1);
    expect(bloom.nextThreshold, isNull);
    expect(LearningEngine.growth(snapshot(31)).progress, 1);
  });
}
