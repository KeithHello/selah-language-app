import 'learning_models.dart' show LearnSentence;

enum LoopOrder { targetFirst, sourceFirst }

enum LoopTrackRole { target, source }

class LoopOptions {
  const LoopOptions({
    this.order = LoopOrder.targetFirst,
    this.durationMinutes = 30,
  });

  final LoopOrder order;
  final int durationMinutes;

  Map<String, Object?> toJson() => {
    'order': order.name,
    'durationMinutes': durationMinutes,
  };

  factory LoopOptions.fromJson(Map<String, dynamic> json) {
    final orderValue = json['order'] ?? 'targetFirst';
    final minutes = json['durationMinutes'] ?? 30;
    if (orderValue is! String ||
        !const {'targetFirst', 'sourceFirst'}.contains(orderValue) ||
        minutes is! int ||
        minutes < 1 ||
        minutes > 720) {
      throw const FormatException('循环听设置无效。');
    }
    return LoopOptions(
      order: orderValue == 'sourceFirst'
          ? LoopOrder.sourceFirst
          : LoopOrder.targetFirst,
      durationMinutes: minutes,
    );
  }

  LoopOptions copyWith({
    LoopOrder? order,
    int? durationMinutes,
  }) => LoopOptions(
    order: order ?? this.order,
    durationMinutes: durationMinutes ?? this.durationMinutes,
  );
}

int? validateLoopDuration(String value) {
  final text = value.trim();
  if (!RegExp(r'^\d+$').hasMatch(text)) return null;
  final minutes = int.tryParse(text);
  if (minutes == null || minutes < 1 || minutes > 720) return null;
  return minutes;
}

class LoopQueueException implements Exception {
  const LoopQueueException(this.sentenceId, this.reason);

  final String sentenceId;
  final String reason;

  @override
  String toString() => 'LoopQueueException($sentenceId: $reason)';
}

class LoopAudioTrack {
  const LoopAudioTrack({
    required this.sentenceId,
    required this.role,
    required this.language,
    required this.text,
  });

  final String sentenceId;
  final LoopTrackRole role;
  final String language;
  final String text;
}

class LoopQueueItem {
  const LoopQueueItem({
    required this.sentenceId,
    required this.target,
    required this.source,
  });

  final String sentenceId;
  final LoopAudioTrack target;
  final LoopAudioTrack source;
}

List<LoopQueueItem> buildLoopQueue(List<LearnSentence> sentences) {
  final seen = <String>{};
  final result = <LoopQueueItem>[];
  for (final sentence in sentences) {
    if (sentence.archived || !seen.add(sentence.id)) continue;
    final targetText = sentence.target.trim();
    final sourceText = sentence.source.trim();
    if (sourceText.isEmpty) {
      throw LoopQueueException(sentence.id, 'source_text_missing');
    }
    if (targetText.isEmpty) {
      throw LoopQueueException(sentence.id, 'target_text_missing');
    }
    result.add(
      LoopQueueItem(
        sentenceId: sentence.id,
        target: LoopAudioTrack(
          sentenceId: sentence.id,
          role: LoopTrackRole.target,
          language: sentence.targetLanguage ?? 'en',
          text: targetText,
        ),
        source: LoopAudioTrack(
          sentenceId: sentence.id,
          role: LoopTrackRole.source,
          language: sentence.sourceLanguage ?? 'zh-Hant',
          text: sourceText,
        ),
      ),
    );
  }
  return result;
}
