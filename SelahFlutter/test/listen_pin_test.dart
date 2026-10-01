import 'package:flutter_test/flutter_test.dart';
import 'package:selah/web/data/supabase_learning_gateway.dart';
import 'package:selah/web/domain/learning_models.dart';
import 'package:selah/web/learning_controller.dart';

import 'web_controller_test.dart';

Future<LearningController> _controller() async {
  final controller = LearningController(
    gateway: CaptureGateway(),
    platform: MemoryPlatform(),
    seeds: const [],
    polling: false,
  );
  addTearDown(controller.dispose);
  await controller.initialize();
  return controller;
}

LearnSentence _sentence(String source, {bool archived = false}) =>
    LearnSentence(
      id: newId(),
      source: source,
      target: 'English $source',
      archived: archived,
    );

void main() {
  test('newly pinned sentences appear first in the listen order', () async {
    final first = _sentence('第一句');
    final second = _sentence('第二句');
    final third = _sentence('第三句');
    final controller = await _controller();
    controller.state.sentences.addAll([first, second, third]);

    controller.togglePinnedSentence(first.id);
    controller.togglePinnedSentence(third.id);

    expect(
      controller
          .orderedListenSentences(controller.state.sentences)
          .map((sentence) => sentence.id),
      [third.id, first.id, second.id],
    );
  });

  test('unpinning a sentence restores its original relative order', () async {
    final first = _sentence('第一句');
    final second = _sentence('第二句');
    final controller = await _controller();
    controller.state.sentences.addAll([first, second]);

    controller.togglePinnedSentence(second.id);
    expect(
      controller
          .orderedListenSentences(controller.state.sentences)
          .map((sentence) => sentence.id),
      [second.id, first.id],
    );

    controller.togglePinnedSentence(second.id);
    expect(
      controller
          .orderedListenSentences(controller.state.sentences)
          .map((sentence) => sentence.id),
      [first.id, second.id],
    );
  });

  test(
    'pinned ids do not return archived sentences to the listen list',
    () async {
      final visible = _sentence('可见句');
      final archived = _sentence('已归档句', archived: true);
      final controller = await _controller();
      controller.state.sentences.addAll([visible, archived]);
      controller.togglePinnedSentence(archived.id);

      final ordered = controller.orderedListenSentences(
        controller.state.sentences
            .where((sentence) => !sentence.archived)
            .toList(),
      );

      expect(ordered.map((sentence) => sentence.id), [visible.id]);
    },
  );

  test('pinned ids survive snapshot copies and merges', () async {
    final controller = await _controller();
    final sentence = _sentence('句子');
    controller.state.sentences.add(sentence);
    controller.togglePinnedSentence(sentence.id);

    final copy = controller.state.copy();
    final merged = controller.state.merge(copy);

    expect(copy.pinnedSentenceIds, [sentence.id]);
    expect(merged.pinnedSentenceIds, [sentence.id]);
  });

  test('pinned ids are rebased when the snapshot account changes', () async {
    final controller = await _controller();
    final sentence = _sentence('句子');
    controller.state.sentences.add(sentence);
    controller.togglePinnedSentence(sentence.id);

    final changed = controller.state.forAccount(
      '22222222-2222-4222-8222-222222222222',
    );

    expect(changed.pinnedSentenceIds, changed.sentences.map((s) => s.id));
  });

  test('cloud sentence payload contains no pinned field', () {
    final sentence = _sentence('句子');
    final payload = SupabaseLearningGateway.sentenceToCloud(
      sentence,
      'user-id',
    );

    expect(payload.containsKey('pinned'), isFalse);
    expect(payload.containsKey('is_pinned'), isFalse);
  });
}
