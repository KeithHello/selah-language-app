import 'package:flutter_test/flutter_test.dart';
import 'package:selah/web/domain/learning_models.dart';
import 'package:selah/web/data/supabase_learning_gateway.dart';

void main() {
  test(
    'account import remaps IDs and references deterministically without mixing users',
    () {
      final source = LearningSnapshot.empty();
      final id = newId();
      source.sentences.add(
        LearnSentence(id: id, source: '你好', target: 'Hello.'),
      );
      source.events.add(
        LearnEvent(id: newId(), type: 'listen_completed', sentenceId: id),
      );
      final a = newId(), b = newId();
      final importedA = source.forAccount(a), importedB = source.forAccount(b);
      expect(
        importedA.sentences.single.id,
        source.forAccount(a).sentences.single.id,
      );
      expect(
        importedA.sentences.single.id,
        isNot(importedB.sentences.single.id),
      );
      expect(importedA.events.single.sentenceId, importedA.sentences.single.id);
      expect(
        importedA.forAccount(a).sentences.single.id,
        importedA.sentences.single.id,
      );
      expect(
        importedA.forAccount(b).sentences.single.id,
        importedB.sentences.single.id,
      );
    },
  );
  test(
    'cloud mapping preserves source, review and seed association using existing JSON columns',
    () {
      final original = LearnSentence(
        id: newId(),
        source: '你好',
        target: 'Hello.',
        seedId: 'seed-001',
        origin: 'system_seed',
      );
      original.reviewState = 'quiet';
      original.intervalDays = 30;
      original.vocabulary.add(
        VocabularyEntry(
          id: newId(),
          text: 'hello',
          meaning: '你好',
          state: 'owned',
        ),
      );
      original.breakdown.add({
        'surfaceText': 'Hello',
        'meaning': '你好',
        'type': 'word',
      });
      final row = SupabaseLearningGateway.sentenceToCloud(original, newId());
      final restored = SupabaseLearningGateway.sentenceFromCloud(row, [
        {
          'id': original.vocabulary.single.id,
          'surface_text': 'hello',
          'meaning_in_context': '你好',
          'help_state': 'owned',
          'updated_at': original.updatedAt.toUtc().toIso8601String(),
        },
      ]);
      expect(restored.source, original.source);
      expect(restored.reviewState, 'quiet');
      expect(restored.intervalDays, 30);
      expect(restored.seedId, 'seed-001');
      expect(restored.vocabulary.single.state, 'owned');
    },
  );
  test(
    'remote failures distinguish expired login, quota and provider failure',
    () {
      expect(
        SupabaseLearningGateway.functionFailure(401, {}).code,
        'unauthorized',
      );
      expect(
        SupabaseLearningGateway.functionFailure(429, {
          'error': 'quota_exceeded',
        }).code,
        'quota_exceeded',
      );
      expect(
        SupabaseLearningGateway.functionFailure(
          502,
          'secret provider body',
        ).message,
        isNot(contains('secret')),
      );
    },
  );
}
