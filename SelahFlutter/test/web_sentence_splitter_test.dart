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

  test('detects speech disfluencies without flagging clean expressions', () {
    expect(
      shouldPolishSpokenSource('呢最近我去游泳了嘛，然后觉得嘛，好一段时间没游。嗯，这样对身体比较好。'),
      isTrue,
    );
    expect(shouldPolishSpokenSource('今天终于把拖了很久的事情做完了。'), isFalse);
    expect(shouldPolishSpokenSource('你呢？'), isFalse);
    expect(
      shouldPolishSpokenSource('えーと、今日は散歩します。', nativeLanguage: 'ja'),
      isTrue,
    );
    expect(
      shouldPolishSpokenSource('今日は散歩します。', nativeLanguage: 'ja'),
      isFalse,
    );
  });

  test(
    'requires confirmation for wording changes but ignores punctuation width',
    () {
      expect(polishRequiresConfirmation('今天想运动，感觉不错。', '今天想運動,感覺不錯.'), isTrue);
      expect(polishRequiresConfirmation('今天想运动，感觉不错。', '今天想运动,感觉不错.'), isFalse);
    },
  );

  test(
    'returns every sentence so the caller can route over the 20 segment limit',
    () {
      final text = List.generate(21, (index) => '第${index + 1}句。').join();
      expect(splitSourceSentences(text), hasLength(21));
    },
  );
}
