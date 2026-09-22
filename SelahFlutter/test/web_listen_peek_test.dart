import 'package:flutter_test/flutter_test.dart';
import 'package:selah/web/domain/learning_models.dart';
import 'package:selah/web/domain/listen_peek.dart';

void main() {
  test('builds tappable breakdown items with their native meanings', () {
    final sentence = LearnSentence(
      id: 'listen-1',
      source: '今天又加班到半夜，我真的會謝',
      target: "Pulled another all-nighter at work. I literally can't even.",
      breakdown: const [
        {'surfaceText': 'pulled another all-nighter', 'meaning': '又加班到半夜、又熬夜'},
        {'surfaceText': "I literally can't even", 'meaning': '我真的會謝、我真的不行了'},
      ],
    );

    expect(listenPeekItems(sentence), [
      const ListenPeekItem(
        id: 'b:0',
        surface: 'pulled another all-nighter',
        meaning: '又加班到半夜、又熬夜',
        source: ListenPeekSource.breakdown,
      ),
      const ListenPeekItem(
        id: 'b:1',
        surface: "I literally can't even",
        meaning: '我真的會謝、我真的不行了',
        source: ListenPeekSource.breakdown,
      ),
    ]);
  });

  test(
    'prefers the longest breakdown span over an overlapping vocabulary span',
    () {
      final sentence = LearnSentence(
        id: 'listen-2',
        source: '今天又加班到半夜',
        target: 'Pulled another all-nighter at work.',
        breakdown: const [
          {
            'surfaceText': 'pulled another all-nighter',
            'meaning': '又加班到半夜、又熬夜',
          },
        ],
        vocabulary: [
          VocabularyEntry(
            id: 'all-nighter',
            text: 'all-nighter',
            meaning: '通宵、熬夜加班',
          ),
        ],
      );

      final spans = listenPeekSpans(sentence.target, listenPeekItems(sentence));

      expect(spans, hasLength(1));
      expect(spans.single.item.id, 'b:0');
      expect(
        sentence.target.substring(spans.single.start, spans.single.end),
        'Pulled another all-nighter',
      );
    },
  );

  test('keeps an uncovered vocabulary phrase tappable', () {
    final sentence = LearnSentence(
      id: 'listen-3',
      source: '老板又迟到了',
      target: 'My boss is late again.',
      vocabulary: [VocabularyEntry(id: 'boss', text: 'boss', meaning: '老板')],
    );

    final spans = listenPeekSpans(sentence.target, listenPeekItems(sentence));

    expect(spans, hasLength(1));
    expect(spans.single.item.id, 'v:boss');
    expect(
      sentence.target.substring(spans.single.start, spans.single.end),
      'boss',
    );
  });

  test('ignores incomplete items and matches case insensitively', () {
    final sentence = LearnSentence(
      id: 'listen-4',
      source: '我受不了了',
      target: "I Literally Can't Even.",
      breakdown: const [
        {'surfaceText': "I literally can't even", 'meaning': '我受不了了'},
        {'surfaceText': 'missing meaning'},
      ],
    );

    final items = listenPeekItems(sentence);
    final spans = listenPeekSpans(sentence.target, items);

    expect(items, hasLength(1));
    expect(spans, hasLength(1));
    expect(spans.single.item.id, 'b:0');
  });
}
