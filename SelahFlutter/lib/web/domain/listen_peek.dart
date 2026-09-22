import 'learning_models.dart';

enum ListenPeekSource { breakdown, vocabulary }

class ListenPeekItem {
  const ListenPeekItem({
    required this.id,
    required this.surface,
    required this.meaning,
    required this.source,
  });

  final String id;
  final String surface;
  final String meaning;
  final ListenPeekSource source;

  @override
  bool operator ==(Object other) =>
      other is ListenPeekItem &&
      other.id == id &&
      other.surface == surface &&
      other.meaning == meaning &&
      other.source == source;

  @override
  int get hashCode => Object.hash(id, surface, meaning, source);
}

class ListenPeekSpan {
  const ListenPeekSpan({
    required this.start,
    required this.end,
    required this.item,
  });

  final int start;
  final int end;
  final ListenPeekItem item;
}

List<ListenPeekItem> listenPeekItems(LearnSentence sentence) {
  final items = <ListenPeekItem>[];
  for (var index = 0; index < sentence.breakdown.length; index++) {
    final item = sentence.breakdown[index];
    final surface = _stringValue(item, const [
      'surfaceText',
      'surface',
      'text',
    ]);
    final meaning = _stringValue(item, const [
      'explanation',
      'meaningInContext',
      'meaning',
    ]);
    if (surface == null || meaning == null) continue;
    items.add(
      ListenPeekItem(
        id: 'b:$index',
        surface: surface,
        meaning: meaning,
        source: ListenPeekSource.breakdown,
      ),
    );
  }
  for (final entry in sentence.vocabulary) {
    final surface = entry.text.trim();
    final meaning = entry.meaning.trim();
    if (surface.isEmpty || meaning.isEmpty) continue;
    items.add(
      ListenPeekItem(
        id: 'v:${entry.id}',
        surface: surface,
        meaning: meaning,
        source: ListenPeekSource.vocabulary,
      ),
    );
  }
  return items;
}

List<ListenPeekSpan> listenPeekSpans(
  String target,
  List<ListenPeekItem> items,
) {
  final normalizedTarget = target.toLowerCase();
  final candidates = <_Candidate>[];
  for (var index = 0; index < items.length; index++) {
    final surface = items[index].surface.trim();
    if (surface.isEmpty) continue;
    final start = normalizedTarget.indexOf(surface.toLowerCase());
    if (start < 0) continue;
    candidates.add(
      _Candidate(
        start: start,
        end: start + surface.length,
        item: items[index],
        order: index,
      ),
    );
  }
  candidates.sort((a, b) {
    final length = (b.end - b.start).compareTo(a.end - a.start);
    if (length != 0) return length;
    final source = _sourcePriority(
      a.item.source,
    ).compareTo(_sourcePriority(b.item.source));
    return source == 0 ? a.order.compareTo(b.order) : source;
  });

  final accepted = <ListenPeekSpan>[];
  for (final candidate in candidates) {
    final overlaps = accepted.any(
      (span) => candidate.start < span.end && span.start < candidate.end,
    );
    if (!overlaps) {
      accepted.add(
        ListenPeekSpan(
          start: candidate.start,
          end: candidate.end,
          item: candidate.item,
        ),
      );
    }
  }
  accepted.sort((a, b) => a.start.compareTo(b.start));
  return accepted;
}

class _Candidate {
  const _Candidate({
    required this.start,
    required this.end,
    required this.item,
    required this.order,
  });

  final int start;
  final int end;
  final ListenPeekItem item;
  final int order;
}

int _sourcePriority(ListenPeekSource source) =>
    source == ListenPeekSource.breakdown ? 0 : 1;

String? _stringValue(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}
