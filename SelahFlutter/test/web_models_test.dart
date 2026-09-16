import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/web/domain/learning_models.dart';

void main() {
  test(
    'preferences default to Traditional Chinese as the single native language choice',
    () {
      final preferences = LearnPreferences.fromJson({});
      expect(preferences.uiLocale, 'zh-Hant');
      expect(preferences.nativeLanguage, 'zh-Hant');
      expect(preferences.toJson(), isNot(contains('uiLocale')));
      expect(preferences.toJson()['nativeLanguage'], 'zh-Hant');
      expect(preferences.nativeVoice, 'native-gentle');
      expect(preferences.speed, 1.0);
    },
  );

  test('companion rail defaults to hidden and survives snapshot backup', () {
    final preferences = LearnPreferences.fromJson({});
    expect(preferences.companionRailVisible, isFalse);

    preferences.companionRailVisible = true;
    final restored = LearnPreferences.fromJson(preferences.toJson());
    expect(restored.companionRailVisible, isTrue);
  });

  test(
    'cloud snapshot merge keeps the device-local companion rail preference',
    () {
      final local = LearningSnapshot.empty();
      local.preferences
        ..companionRailVisible = true
        ..updatedAt = DateTime(2026, 9, 10);
      final cloud = LearningSnapshot.empty();
      cloud.preferences
        ..companionRailVisible = false
        ..updatedAt = DateTime(2026, 9, 11);

      final merged = local.merge(cloud);

      expect(merged.preferences.companionRailVisible, isTrue);
    },
  );

  test('preferences preserve the three unified native language choices', () {
    final japanese = LearnPreferences.fromJson({'nativeLanguage': 'ja'});
    expect(japanese.uiLocale, 'ja');
    expect(japanese.nativeLanguage, 'ja');

    final simplified = LearnPreferences.fromJson({'nativeLanguage': 'zh-Hans'});
    expect(simplified.uiLocale, 'zh-Hans');
    expect(simplified.nativeLanguage, 'zh-Hans');

    final fallback = LearnPreferences.fromJson({'nativeLanguage': 'en'});
    expect(fallback.uiLocale, 'zh-Hant');
    expect(fallback.nativeLanguage, 'zh-Hant');
  });

  test(
    'legacy separate language fields migrate to one native language choice',
    () {
      final legacySimplified = LearnPreferences.fromJson({
        'uiLocale': 'zh-Hans',
        'nativeLanguage': 'zh',
      });
      expect(legacySimplified.nativeLanguage, 'zh-Hans');
      expect(legacySimplified.uiLocale, 'zh-Hans');

      final legacyJapanese = LearnPreferences.fromJson({
        'uiLocale': 'zh-Hans',
        'nativeLanguage': 'ja',
      });
      expect(legacyJapanese.nativeLanguage, 'ja');
      expect(legacyJapanese.uiLocale, 'ja');

      final legacyInterfaceOnlyJapanese = LearnPreferences.fromJson({
        'uiLocale': 'ja',
      });
      expect(legacyInterfaceOnlyJapanese.nativeLanguage, 'zh-Hant');

      final invalid = LearnPreferences.fromJson({
        'uiLocale': 'en',
        'nativeLanguage': '',
      });
      expect(invalid.nativeLanguage, 'zh-Hant');
    },
  );

  test('language mappings keep English as the learning language', () {
    expect(generationSourceLanguage('zh-Hant'), 'zh-Hant');
    expect(generationSourceLanguage('zh-Hans'), 'zh-Hant');
    expect(generationSourceLanguage('ja'), 'ja');
    expect(transcriptionLanguage('zh-Hant'), 'zh');
    expect(transcriptionLanguage('zh-Hans'), 'zh');
    expect(transcriptionLanguage('ja'), 'ja');
    expect(generationTargetLanguage, 'en');
  });

  test(
    'snapshot merge never overwrites local language choices with a cloud default',
    () {
      final local = LearningSnapshot.empty();
      local.preferences
        ..nativeLanguage = 'ja'
        ..updatedAt = DateTime(2026, 9, 10);
      final cloud = LearningSnapshot.empty();
      cloud.preferences.updatedAt = DateTime(2026, 9, 11);

      final merged = local.merge(cloud);
      expect(merged.preferences.uiLocale, 'ja');
      expect(merged.preferences.nativeLanguage, 'ja');
    },
  );

  test('preference JSON round trip includes language choices', () {
    final preferences = LearnPreferences()..nativeLanguage = 'zh-Hans';
    final restored = LearnPreferences.fromJson(preferences.toJson());
    expect(restored.uiLocale, 'zh-Hans');
    expect(restored.nativeLanguage, 'zh-Hans');
    expect(restored.nativeVoice, 'native-gentle');
    expect(restored.speed, 1.0);
  });

  test('native voice preference round trips independently of English voice', () {
    final preferences = LearnPreferences.fromJson({
      'voice': 'elegant-british',
      'nativeVoice': 'native-calm',
      'speed': 1.0,
    });
    expect(preferences.voice, 'elegant-british');
    expect(preferences.nativeVoice, 'native-calm');
    final restored = LearnPreferences.fromJson(preferences.toJson());
    expect(restored.voice, 'elegant-british');
    expect(restored.nativeVoice, 'native-calm');
  });

  test(
    'cloud snapshot merge keeps the device-local native voice preference',
    () {
      final local = LearningSnapshot.empty();
      local.preferences
        ..nativeVoice = 'native-bright'
        ..updatedAt = DateTime(2026, 9, 10);
      final cloud = LearningSnapshot.empty();
      cloud.preferences
        ..nativeVoice = 'native-gentle'
        ..updatedAt = DateTime(2026, 9, 11);

      final merged = local.merge(cloud);

      expect(merged.preferences.nativeVoice, 'native-bright');
    },
  );

  test('backup rejects duplicate vocabulary and event identifiers', () {
    final snapshot = LearningSnapshot.empty();
    final word = VocabularyEntry(id: newId(), text: 'hello', meaning: '你好');
    snapshot.sentences.add(
      LearnSentence(
        id: newId(),
        source: '你好',
        target: 'Hello.',
        vocabulary: [word, word],
      ),
    );
    expect(
      () => LearningSnapshot.importBackup(jsonEncode(snapshot.toBackup())),
      throwsFormatException,
    );
    snapshot.sentences.single.vocabulary.removeLast();
    final event = LearnEvent(
      id: newId(),
      type: 'listen_completed',
      sentenceId: snapshot.sentences.single.id,
    );
    snapshot.events.addAll([event, event]);
    expect(
      () => LearningSnapshot.importBackup(jsonEncode(snapshot.toBackup())),
      throwsFormatException,
    );
  });
  LearnSentence sample({DateTime? updated}) => LearnSentence(
    id: newId(),
    source: '今天很忙',
    target: 'Today was busy.',
    category: 'work',
    createdAt: DateTime(2026, 9, 5),
    updatedAt: updated ?? DateTime(2026, 9, 5),
  );

  test('backup round trip preserves review, voice and vocabulary', () {
    final state = LearningSnapshot.empty();
    final sentence = sample();
    sentence.reviewState = 'familiar';
    sentence.nextReviewAt = DateTime(2026, 9, 12);
    sentence.vocabulary.add(
      VocabularyEntry(id: newId(), text: 'busy', meaning: '忙碌', state: 'owned'),
    );
    state.sentences.add(sentence);
    state.preferences.voice = 'clear-slow';
    final restored = LearningSnapshot.importBackup(
      jsonEncode(state.toBackup()),
    );
    expect(restored.sentences.single.reviewState, 'familiar');
    expect(restored.sentences.single.vocabulary.single.state, 'owned');
    expect(restored.preferences.voice, 'clear-slow');
  });

  test('backup round trip preserves account-local unsent input', () {
    final state = LearningSnapshot.empty()
      ..todayInput = '今天想说的话'
      ..segmentInputs.addAll(['第一段', '第二段']);
    final restored = LearningSnapshot.importBackup(
      jsonEncode(state.toBackup()),
    );
    expect(restored.todayInput, '今天想说的话');
    expect(restored.segmentInputs, ['第一段', '第二段']);
  });

  test('older backups without local input fields still import', () {
    final data = LearningSnapshot.empty().toBackup()
      ..remove('todayInput')
      ..remove('segmentInputs');
    final restored = LearningSnapshot.importBackup(jsonEncode(data));
    expect(restored.todayInput, isEmpty);
    expect(restored.segmentInputs, isEmpty);
  });

  test(
    'backup rejects more than twenty segment inputs instead of truncating',
    () {
      final data = LearningSnapshot.empty().toBackup();
      data['segmentInputs'] = List.generate(21, (index) => '第 $index 段');
      expect(
        () => LearningSnapshot.importBackup(jsonEncode(data)),
        throwsFormatException,
      );
    },
  );

  test(
    'preparation draft round trip preserves request version and segment status',
    () {
      final state = LearningSnapshot.empty()
        ..preparationDraft = PreparationDraft(
          id: newId(),
          sourceText: '长文输入',
          inputVersion: 7,
          segments: [
            PreparationSegment(
              id: newId(),
              sourceText: '已完成分句',
              status: 'succeeded',
            ),
          ],
        );
      final restored = LearningSnapshot.importBackup(
        jsonEncode(state.toBackup()),
      );
      expect(restored.preparationDraft!.inputVersion, 7);
      expect(restored.preparationDraft!.segments.single.status, 'succeeded');
    },
  );

  test('invalid backup is rejected before existing state can change', () {
    expect(() => LearningSnapshot.importBackup('{'), throwsFormatException);
    expect(
      () =>
          LearningSnapshot.importBackup('{"format":"selah-web","version":99}'),
      throwsFormatException,
    );
    final data = LearningSnapshot.empty().toBackup();
    data['sentences'] = [
      {'id': 'not-a-uuid', 'source': '', 'target': ''},
    ];
    expect(
      () => LearningSnapshot.importBackup(jsonEncode(data)),
      throwsFormatException,
    );
  });

  test(
    'merge is idempotent and keeps newest review without dropping local sentence',
    () {
      final local = LearningSnapshot.empty();
      final first = sample();
      local.sentences.add(first);
      final other = local.copy();
      other.sentences.first.reviewState = 'quiet';
      other.sentences.first.updatedAt = DateTime(2026, 9, 6);
      local.sentences.add(sample());
      final merged = local.merge(other).merge(other);
      expect(merged.sentences, hasLength(2));
      expect(
        merged.sentences.firstWhere((s) => s.id == first.id).reviewState,
        'quiet',
      );
    },
  );

  test('generated contract uses real targetText and vocabulary fields', () {
    final sentence = LearnSentence.generated(
      source: '你好',
      requestId: newId(),
      json: {
        'targetText': 'Hello.',
        'category': 'friends',
        'vocabulary': [
          {
            'surfaceText': 'hello',
            'meaningInContext': '你好',
            'suggestedHelpState': 'new',
          },
        ],
        'deconstruction': [
          {'surfaceText': 'Hello.', 'meaning': '问候', 'type': 'phrase'},
        ],
      },
    );
    expect(sentence.target, 'Hello.');
    expect(sentence.vocabulary.single.meaning, '你好');
    expect(
      () => LearnSentence.generated(
        source: '你好',
        requestId: newId(),
        json: {'translation': 'Hello'},
      ),
      throwsFormatException,
    );
  });

  test('generated sentence round trip preserves known provenance', () {
    final sentence = LearnSentence.generated(
      source: '你好',
      requestId: newId(),
      json: {
        'targetText': 'Hello.',
        'category': 'friends',
        'model': 'gpt-4o-mini',
        'promptVersion': 'v8.0',
        'sourceLanguage': 'zh-Hant',
        'targetLanguage': 'en',
      },
    );
    expect(sentence.generationModel, 'gpt-4o-mini');
    expect(sentence.promptVersion, 'v8.0');
    expect(sentence.sourceLanguage, 'zh-Hant');
    expect(sentence.targetLanguage, 'en');
    expect(sentence.hasKnownGenerationProvenance, isTrue);

    final restored = LearnSentence.fromJson(sentence.toJson());
    expect(restored.generationModel, 'gpt-4o-mini');
    expect(restored.promptVersion, 'v8.0');
    expect(restored.sourceLanguage, 'zh-Hant');
    expect(restored.targetLanguage, 'en');
  });

  test('legacy sentence without provenance stays unknown after import', () {
    final sentence = sample();
    final json = sentence.toJson()..remove('generationModel');
    json.remove('promptVersion');
    json.remove('sourceLanguage');
    json.remove('targetLanguage');
    final restored = LearnSentence.fromJson(json);
    expect(restored.hasKnownGenerationProvenance, isFalse);
    expect(restored.generationModel, isNull);
  });

  test('source reuse normalization only trims and unifies line endings', () {
    expect(normalizeSourceForReuse('  第一行\r\n第二行\r  '), '第一行\n第二行');
    expect(normalizeSourceForReuse('大小写保留。'), '大小写保留。');
  });

  test('generated output rejects more than three vocabulary items', () {
    expect(
      () => LearnSentence.generated(
        source: '你好',
        requestId: newId(),
        json: {
          'targetText': 'Hello.',
          'vocabulary': List.generate(
            4,
            (index) => {
              'surfaceText': 'word$index',
              'meaningInContext': '词义$index',
            },
          ),
        },
      ),
      throwsFormatException,
    );
  });
}
