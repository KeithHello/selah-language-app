import 'package:flutter_test/flutter_test.dart';
import 'package:selah/web/domain/learning_models.dart';
import 'package:selah/web/domain/today_suggestions.dart';

LearnSentence sentence(
  String id, {
  String? seedId,
  String reviewState = 'new',
  DateTime? listenedAt,
  DateTime? nextReviewAt,
  bool archived = false,
}) => LearnSentence(
  id: id,
  source: 'Source $id',
  target: 'Target $id',
  origin: seedId == null ? 'user_recording' : 'system_seed',
  seedId: seedId,
  reviewState: reviewState,
  listenedAt: listenedAt,
  nextReviewAt: nextReviewAt,
  archived: archived,
);

void main() {
  final now = DateTime(2026, 9, 29, 12);
  final yesterday = now.subtract(const Duration(days: 1));

  test(
    'offers due, unheard personal, then starter without duplicate seeds',
    () {
      final due = sentence(
        'due',
        reviewState: 'learning',
        listenedAt: yesterday,
        nextReviewAt: yesterday,
      );
      final own = sentence('own');
      final ownedSeed = sentence('owned-seed', seedId: 'seed-1');
      final suggestions = TodaySuggestions.select(
        sentences: [due, own, ownedSeed],
        seeds: [
          sentence('seed-1', seedId: 'seed-1'),
          sentence('seed-2', seedId: 'seed-2'),
        ],
        now: now,
      );

      expect(suggestions.map((item) => item.kind), [
        TodaySuggestionKind.revisit,
        TodaySuggestionKind.personal,
        TodaySuggestionKind.starter,
      ]);
      expect(suggestions.map((item) => item.sentence.id), [
        'due',
        'own',
        'owned-seed',
      ]);
      expect(suggestions.every((item) => !item.needsAdd), isTrue);
    },
  );

  test('omits already heard today and archived records', () {
    final heardToday = sentence(
      'heard-today',
      reviewState: 'learning',
      listenedAt: now,
      nextReviewAt: yesterday,
    );
    final archived = sentence('archived', archived: true);
    final suggestions = TodaySuggestions.select(
      sentences: [heardToday, archived],
      seeds: [sentence('seed-1', seedId: 'seed-1')],
      now: now,
    );

    expect(suggestions.map((item) => item.sentence.id), ['seed-1']);
    expect(suggestions.single.needsAdd, isTrue);
  });

  test('starter selection is stable during a day and rotates next day', () {
    final seeds = List.generate(
      5,
      (index) => sentence('seed-$index', seedId: 'seed-$index'),
    );
    List<String> ids(DateTime date) => TodaySuggestions.select(
      sentences: const [],
      seeds: seeds,
      now: date,
    ).map((item) => item.sentence.id).toList();

    expect(ids(now), ids(DateTime(2026, 9, 29, 20)));
    expect(ids(now), hasLength(3));
    expect(ids(now), isNot(ids(DateTime(2026, 9, 30, 12))));
  });

  test('returns only available items without blank slots', () {
    expect(
      TodaySuggestions.select(sentences: const [], seeds: const [], now: now),
      isEmpty,
    );
    expect(
      TodaySuggestions.select(
        sentences: const [],
        seeds: [sentence('seed-1', seedId: 'seed-1')],
        now: now,
      ),
      hasLength(1),
    );
  });
}
