import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:selah/web/data/learning_gateway.dart';
import 'package:selah/web/domain/learning_models.dart';
import 'package:selah/web/learning_controller.dart';

import 'web_controller_test.dart';

LearningController _controller([LearningGateway? gateway]) {
  final controller = LearningController(
    gateway: gateway ?? CaptureGateway(),
    platform: MemoryPlatform(),
    seeds: const [],
    polling: false,
  );
  addTearDown(controller.dispose);
  return controller;
}

PreparationDraft _draft(List<PreparationSegment> segments) => PreparationDraft(
  id: newId(),
  sourceText: segments.map((segment) => segment.sourceText).join('\n'),
  segments: segments,
);

void main() {
  test('an empty segment is preserved in the preparation snapshot', () {
    final draft = _draft([
      PreparationSegment(id: newId(), sourceText: ''),
      PreparationSegment(id: newId(), sourceText: '第二段'),
    ]);

    final restored = PreparationDraft.fromJson(draft.toJson());

    expect(restored.segments.first.sourceText, isEmpty);
    expect(restored.segments.last.sourceText, '第二段');
  });

  test('updating a segment to empty keeps the empty draft text', () async {
    final controller = _controller();
    await controller.initialize();
    controller.state.preparationDraft = _draft([
      PreparationSegment(id: newId(), sourceText: '第一段'),
    ]);

    controller.updatePreparationSegment(0, '   ');

    expect(
      controller.state.preparationDraft!.segments.single.sourceText,
      isEmpty,
    );
  });

  test(
    'removing a middle segment keeps neighboring metadata attached',
    () async {
      final controller = _controller();
      await controller.initialize();
      final first = PreparationSegment(id: newId(), sourceText: '第一段');
      final middle = PreparationSegment(id: newId(), sourceText: '第二段');
      final last = PreparationSegment(id: newId(), sourceText: '第三段');
      controller.state.preparationDraft = _draft([first, middle, last]);

      expect(controller.removePreparationSegment(1), isTrue);

      final segments = controller.state.preparationDraft!.segments;
      expect(segments, hasLength(2));
      expect(segments.map((segment) => segment.sourceText), ['第一段', '第三段']);
      expect(segments.map((segment) => segment.id), [first.id, last.id]);
    },
  );

  test('the last segment cannot be removed from the preparation', () async {
    final controller = _controller();
    await controller.initialize();
    final segment = PreparationSegment(id: newId(), sourceText: '唯一一段');
    controller.state.preparationDraft = _draft([segment]);

    expect(controller.removePreparationSegment(0), isFalse);
    expect(controller.state.preparationDraft!.segments, [segment]);
  });

  test('segments cannot be removed while generation is busy', () async {
    final gateway = DelayedGenerateGateway();
    final response = Completer<Map<String, dynamic>>();
    gateway.response = response;
    final controller = _controller(gateway);
    await controller.initialize();
    controller.state.preparationDraft = _draft([
      PreparationSegment(id: newId(), sourceText: '第一段'),
      PreparationSegment(id: newId(), sourceText: '第二段'),
    ]);

    final generating = controller.generate('正在生成的一句。');
    await Future<void>.delayed(Duration.zero);
    expect(controller.busy, isTrue);
    expect(controller.removePreparationSegment(0), isFalse);

    response.complete({
      'targetText': 'A sentence being generated.',
      'category': 'daily_life',
      'model': 'gpt-4o-mini',
      'promptVersion': 'v8.0',
      'sourceLanguage': 'zh-Hant',
      'targetLanguage': 'en',
      'deconstruction': <dynamic>[],
      'vocabulary': <dynamic>[],
    });
    await generating;
  });

  test('batch generation excludes empty segments', () async {
    final gateway = CaptureGateway();
    final controller = _controller(gateway);
    await controller.initialize();
    controller.state.preparationDraft = _draft([
      PreparationSegment(id: newId(), sourceText: '第一段'),
      PreparationSegment(id: newId(), sourceText: ''),
      PreparationSegment(id: newId(), sourceText: '第三段'),
    ]);

    await controller.generatePreparedSegments();

    expect(gateway.batchSegmentTexts, [
      ['第一段', '第三段'],
    ]);
  });
}
