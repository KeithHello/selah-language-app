import 'learning_engine.dart';
import 'learning_models.dart';

enum TodaySuggestionKind { revisit, personal, starter }

class TodaySuggestion {
  const TodaySuggestion(this.sentence, this.kind, {this.needsAdd = false});

  final LearnSentence sentence;
  final TodaySuggestionKind kind;
  final bool needsAdd;
}

class TodaySuggestions {
  const TodaySuggestions._();

  static List<TodaySuggestion> select({
    required Iterable<LearnSentence> sentences,
    required Iterable<LearnSentence> seeds,
    required DateTime now,
  }) {
    final all = sentences.toList();
    final active = all.where((sentence) => !sentence.archived).toList();
    final usedSeedIds = all.map((sentence) => sentence.seedId).toSet();

    final revisits = LearningEngine.due(active, now)
        .where((sentence) => !_sameDay(sentence.listenedAt, now))
        .map(
          (sentence) => TodaySuggestion(sentence, TodaySuggestionKind.revisit),
        )
        .toList();
    final personal =
        active
            .where(
              (sentence) =>
                  sentence.seedId == null && sentence.listenedAt == null,
            )
            .toList()
          ..sort((a, b) {
            final byCreated = b.createdAt.compareTo(a.createdAt);
            return byCreated != 0 ? byCreated : a.id.compareTo(b.id);
          });
    final personalSuggestions = personal
        .map(
          (sentence) => TodaySuggestion(sentence, TodaySuggestionKind.personal),
        )
        .toList();
    final ownedSeeds =
        active
            .where(
              (sentence) =>
                  sentence.seedId != null && sentence.listenedAt == null,
            )
            .toList()
          ..sort((a, b) => a.seedId!.compareTo(b.seedId!));
    final unusedSeeds =
        seeds
            .where(
              (seed) =>
                  seed.seedId != null && !usedSeedIds.contains(seed.seedId),
            )
            .toList()
          ..sort((a, b) => a.seedId!.compareTo(b.seedId!));
    final starters = [
      ..._rotate(ownedSeeds, now).map(
        (sentence) => TodaySuggestion(sentence, TodaySuggestionKind.starter),
      ),
      ..._rotate(unusedSeeds, now).map(
        (sentence) => TodaySuggestion(
          sentence,
          TodaySuggestionKind.starter,
          needsAdd: true,
        ),
      ),
    ];

    final pools = [revisits, personalSuggestions, starters];
    final selected = <TodaySuggestion>[];
    final seen = <String>{};
    void take(TodaySuggestion item) {
      final key = item.sentence.seedId ?? item.sentence.id;
      if (seen.add(key) && selected.length < 3) selected.add(item);
    }

    for (final pool in pools) {
      if (pool.isNotEmpty) take(pool.first);
    }
    for (final pool in pools) {
      for (final item in pool.skip(1)) {
        take(item);
      }
    }
    return selected;
  }

  static bool _sameDay(DateTime? first, DateTime second) {
    if (first == null) return false;
    final local = first.toLocal();
    return local.year == second.year &&
        local.month == second.month &&
        local.day == second.day;
  }

  static List<LearnSentence> _rotate(List<LearnSentence> items, DateTime now) {
    if (items.isEmpty) return items;
    final day = DateTime.utc(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime.utc(2020)).inDays;
    final offset = day % items.length;
    return [...items.skip(offset), ...items.take(offset)];
  }
}
