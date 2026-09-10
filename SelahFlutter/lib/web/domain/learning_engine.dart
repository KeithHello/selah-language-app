import 'learning_models.dart';

const memoryTitles = <String, (String, String)>{
  'first_name': ('第一次见面', '你为一颗小种子取了名字。'),
  'first_seed': ('三句小小的开始', '真实生活里的表达，开始在这里生长。'),
  'first_own_sentence': ('自己的第一句话', '你把一个真实想法，变成了英文。'),
  'first_listen': ('听见了新的可能', '你认真听完了第一句英文。'),
  'first_practice': ('试着说出口', '从听懂到开口，你又向前走了一步。'),
  'five_listens': ('耳朵里的小花园', '五次完整聆听，慢慢积累语感。'),
  'ten_practices': ('一点一点变熟悉', '已经完成十次开口练习。'),
  'first_quiet': ('一句话住进了心里', '有一句英文，已经越来越像你自己的话。'),
  'day_7': ('一起走过一周', '七个有学习的日子，不必连续，也值得记住。'),
  'day_30': ('三十个学习的日子', '你的小小坚持，已经长成了一片风景。'),
};

class LearningEngine {
  static void listen(LearnSentence s, DateTime at) {
    s.listenedAt = at;
    s.updatedAt = at;
    if (s.reviewState == 'new') {
      s.reviewState = 'learning';
      s.intervalDays = 1;
      s.nextReviewAt = _days(at, 1);
    }
  }

  static void rate(LearnSentence s, String signal, DateTime at) {
    if (!['clear', 'almost', 'failed'].contains(signal)) {
      throw ArgumentError('未知自评信号。');
    }
    final old = s.reviewState;
    s.intervalDays = signal == 'clear'
        ? switch (old) {
            'learning' => 3,
            'familiar' => 7,
            'quiet' => 30,
            _ => 1,
          }
        : 1;
    s.reviewState = signal == 'clear'
        ? switch (old) {
            'learning' => 'familiar',
            'familiar' || 'quiet' => 'quiet',
            _ => 'learning',
          }
        : 'learning';
    s.lastRecallSignal = signal;
    if (signal == 'failed') s.lapseCount++;
    if (signal == 'clear') s.lapseCount = 0;
    s.nextReviewAt = _days(at, s.intervalDays);
    s.updatedAt = at;
  }

  static DateTime _days(DateTime at, int days) =>
      DateTime(at.year, at.month, at.day + days, at.hour, at.minute, at.second);
  static List<LearnSentence> due(
    Iterable<LearnSentence> sentences,
    DateTime at,
  ) =>
      sentences
          .where(
            (s) =>
                !s.archived &&
                ['learning', 'familiar'].contains(s.reviewState) &&
                !s.nextReviewAt.isAfter(at),
          )
          .toList()
        ..sort((a, b) {
          if (a.reviewState != b.reviewState) {
            return a.reviewState == 'learning' ? -1 : 1;
          }
          return a.nextReviewAt.compareTo(b.nextReviewAt);
        });
  static void unlock(LearningSnapshot state, DateTime at) {
    final listens = state.events
        .where((e) => e.type == 'listen_completed')
        .length;
    final practices = state.events
        .where((e) => e.type == 'practice_rated')
        .length;
    final days = state.events
        .map((e) => '${e.at.year}-${e.at.month}-${e.at.day}')
        .toSet()
        .length;
    final conditions = <String, bool>{
      'first_name': state.preferences.onboarded,
      'first_seed': state.sentences.where((s) => s.seedId != null).length >= 3,
      'first_own_sentence': state.sentences.any(
        (s) => s.origin == 'user_recording',
      ),
      'first_listen': listens >= 1,
      'first_practice': practices >= 1,
      'five_listens': listens >= 5,
      'ten_practices': practices >= 10,
      'first_quiet': state.sentences.any((s) => s.reviewState == 'quiet'),
      'day_7': days >= 7,
      'day_30': days >= 30,
    };
    for (final entry in conditions.entries) {
      if (entry.value) state.memories.putIfAbsent(entry.key, () => at);
    }
  }

  static String stage(LearningSnapshot state) {
    final sessions = state.events
        .where(
          (e) => e.type == 'listen_completed' || e.type == 'practice_rated',
        )
        .length;
    if (sessions >= 30) return 'bloom';
    if (sessions >= 15) return 'bud';
    if (sessions >= 5) return 'leaf';
    return state.preferences.onboarded ? 'sprout' : 'none';
  }

  static GrowthProgress growth(LearningSnapshot state) {
    final sessions = state.events
        .where(
          (e) => e.type == 'listen_completed' || e.type == 'practice_rated',
        )
        .length;
    final thresholds = <String, int>{
      'sprout': 5,
      'leaf': 15,
      'bud': 30,
      'bloom': 30,
    };
    final stage = LearningEngine.stage(state);
    if (stage == 'bloom') {
      return const GrowthProgress(
        stage: 'bloom',
        sessions: 30,
        progress: 1,
        nextThreshold: null,
      );
    }
    final previous = switch (stage) {
      'bud' => 15,
      'leaf' => 5,
      _ => 0,
    };
    final next = thresholds[stage]!;
    final span = next - previous;
    final intoStage = (sessions - previous).clamp(0, span);
    return GrowthProgress(
      stage: stage,
      sessions: sessions,
      progress: span == 0 ? 0 : intoStage / span,
      nextThreshold: next,
    );
  }
}

class GrowthProgress {
  const GrowthProgress({
    required this.stage,
    required this.sessions,
    required this.progress,
    required this.nextThreshold,
  });

  final String stage;
  final int sessions;
  final double progress;
  final int? nextThreshold;
}
