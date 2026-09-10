import 'package:flutter_test/flutter_test.dart';
import 'package:selah/web/domain/learning_models.dart';
import 'package:selah/web/domain/loop_listening.dart';

LearnSentence _sentence(String id, String source, String target) {
  return LearnSentence(id: id, source: source, target: target);
}

void main() {
  group('LoopOptions', () {
    test('defaults to target language first and thirty minutes', () {
      const options = LoopOptions();

      expect(options.order, LoopOrder.targetFirst);
      expect(options.durationMinutes, 30);
      expect(options.toJson(), {
        'order': 'targetFirst',
        'durationMinutes': 30,
      });
    });

    test('reads legacy preferences without loop fields', () {
      final options = LoopOptions.fromJson(const {});

      expect(options.order, LoopOrder.targetFirst);
      expect(options.durationMinutes, 30);
    });

    test('rejects unknown order or duration outside one to seven hundred twenty', () {
      for (final invalid in [
        const {'order': 'random', 'durationMinutes': 30},
        const {'order': 'sourceFirst', 'durationMinutes': 0},
        const {'order': 'sourceFirst', 'durationMinutes': 721},
        const {'order': 'sourceFirst', 'durationMinutes': 1.5},
      ]) {
        expect(() => LoopOptions.fromJson(invalid), throwsFormatException);
      }
    });
  });

  group('validateLoopDuration', () {
    test('accepts integer strings in the supported range', () {
      expect(validateLoopDuration('1'), 1);
      expect(validateLoopDuration(' 45 '), 45);
      expect(validateLoopDuration('720'), 720);
    });

    test('rejects empty, fractional, non-numeric and out-of-range input', () {
      for (final value in ['', '0', '-1', '1.5', '721', '45 分', 'abc']) {
        expect(validateLoopDuration(value), isNull);
      }
    });
  });

  group('buildLoopQueue', () {
    test('keeps sentence order and pairs target and source tracks', () {
      final queue = buildLoopQueue([
        _sentence('a', '中文一', 'First.'),
        _sentence('b', '中文二', 'Second.'),
      ]);

      expect(queue.map((item) => item.sentenceId), ['a', 'b']);
      expect(queue.first.target.text, 'First.');
      expect(queue.first.source.text, '中文一');
      expect(queue.first.target.role, LoopTrackRole.target);
      expect(queue.first.source.role, LoopTrackRole.source);
    });

    test('removes archived and duplicate sentence ids without changing order', () {
      final queue = buildLoopQueue([
        _sentence('a', '一', 'A'),
        _sentence('a', '重复', 'Duplicate'),
        LearnSentence(id: 'b', source: '归档', target: 'Archived', archived: true),
        _sentence('c', '二', 'C'),
      ]);

      expect(queue.map((item) => item.sentenceId), ['a', 'c']);
    });

    test('reports sentences whose bilingual text is missing', () {
      expect(
        () => buildLoopQueue([_sentence('a', '', 'Hello')]),
        throwsA(isA<LoopQueueException>().having((e) => e.sentenceId, 'sentenceId', 'a')),
      );
      expect(
        () => buildLoopQueue([_sentence('b', '你好', ' ')]),
        throwsA(isA<LoopQueueException>()),
      );
    });
  });
}
