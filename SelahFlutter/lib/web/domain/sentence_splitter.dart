/// Splits a spoken source-language transcript into short learning sentences.
///
/// This is deliberately conservative: terminal punctuation and line breaks are
/// boundaries, while commas and connective phrases stay in the same sentence.
/// Very short interjections such as "啊。" are attached to the preceding
/// sentence so they do not become an unusable learning card by themselves.
List<String> splitSourceSentences(String input) {
  final source = input.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
  if (source.isEmpty) return const [];

  final pieces = <String>[];
  for (final line in source.split('\n')) {
    var start = 0;
    for (final match in RegExp(r'[。！？!?]+').allMatches(line)) {
      final end = match.end;
      final piece = line.substring(start, end).trim();
      if (piece.isNotEmpty) pieces.add(piece);
      start = end;
    }
    final remainder = line.substring(start).trim();
    if (remainder.isNotEmpty) pieces.add(remainder);
  }

  final result = <String>[];
  for (final piece in pieces) {
    if (result.isNotEmpty && _isTinyInterjection(piece)) {
      result[result.length - 1] = '${result.last}$piece';
    } else {
      result.add(piece);
    }
  }
  return result;
}

bool _isTinyInterjection(String value) {
  final withoutPunctuation = value
      .replaceFirst(RegExp(r'[。！？!?]+$'), '')
      .trim();
  return withoutPunctuation.length <= 2 &&
      const {
        '啊',
        '哦',
        '嗯',
        '唉',
        '诶',
        '呀',
        '喔',
        '哎',
      }.contains(withoutPunctuation);
}
