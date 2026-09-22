import 'package:flutter_test/flutter_test.dart';
import 'package:selah/web/domain/sentence_splitter.dart';

void main() {
  test('splits Chinese sentences and keeps terminal punctuation', () {
    expect(splitSourceSentences('我今天很累。可是我还是来了！你呢？'), [
      '我今天很累。',
      '可是我还是来了！',
      '你呢？',
    ]);
  });

  test('splits English punctuation and line breaks', () {
    expect(splitSourceSentences('I am ready.\nAre you? Yes!'), [
      'I am ready.',
      'Are you?',
      'Yes!',
    ]);
  });

  test(
    'drops blank pieces and joins a tiny fragment to the previous sentence',
    () {
      expect(splitSourceSentences('今天有点累。啊。可是还不错。'), ['今天有点累。啊。', '可是还不错。']);
    },
  );

  test('returns one trimmed sentence when there is no boundary', () {
    expect(splitSourceSentences('  今天想练习一句英文  '), ['今天想练习一句英文']);
  });

  test(
    'returns every sentence so the caller can route over the 20 segment limit',
    () {
      final text = List.generate(21, (index) => '第${index + 1}句。').join();
      expect(splitSourceSentences(text), hasLength(21));
    },
  );
}
