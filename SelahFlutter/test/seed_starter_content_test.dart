import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:selah/web/domain/learning_models.dart';

void main() {
  test('starter seed bundle contains ten balanced bilingual sentences', () {
        final file = File('../SeedContent/seed-sentences.json');
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final sentences = (json['sentences'] as List).cast<Map<String, dynamic>>();

    expect(sentences, hasLength(10));
    expect(
      sentences.map((sentence) => sentence['id']),
      [
        'seed-001',
        'seed-006',
        'seed-027',
        'seed-012',
        'seed-016',
        'seed-021',
        'seed-004',
        'seed-010',
        'seed-030',
        'seed-020',
      ],
    );
    expect(
      sentences.map((sentence) => sentence['category']),
      ['work', 'friends', 'daily_life', 'vent', 'heartfelt', 'debate', 'work', 'friends', 'daily_life', 'heartfelt'],
    );
    for (final sentence in sentences) {
      expect(sentence['zh_text'], isNotEmpty);
      expect(sentence['ja_text'], isNotEmpty);
      expect(sentence['en_translation'], isNotEmpty);
      expect(sentence['sourceLanguage'], 'zh-Hant');
      expect(sentence['targetLanguage'], 'en');
    }
    final japaneseSeed = LearnSentence.seed({
      ...sentences.firstWhere(
        (sentence) => sentence['id'] == 'seed-006',
      ),
      'source':
          sentences.firstWhere((sentence) => sentence['id'] == 'seed-006')['ja_text'],
      'sourceLanguage': 'ja',
    });
    expect(japaneseSeed.sourceLanguage, 'ja');
    expect(japaneseSeed.source, contains('リンク'));
    expect(japaneseSeed.jaText, contains('リンク'));
    expect(japaneseSeed.toJson()['ja_text'], contains('リンク'));
  });

  test('starter audio manifest has four English voices and both native sources', () {
    final seedFile = File('../SeedContent/seed-sentences.json');
    final seedJson =
        jsonDecode(seedFile.readAsStringSync()) as Map<String, dynamic>;
    final sentences =
        (seedJson['sentences'] as List).cast<Map<String, dynamic>>();
    final file = File('assets/content/seed-audio.json');
    final manifest = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

    final seedIds = sentences
        .map((sentence) => sentence['id'] as String)
        .toList(growable: false);
    for (final seed in seedIds) {
      for (final voice in ['gentle-natural', 'clear-slow', 'daily-bright', 'elegant-british']) {
        expect(manifest['$seed:$voice'], isNotNull, reason: '$seed:$voice');
      }
      expect(manifest['$seed:source:zh-Hant'], isNotNull, reason: '$seed Chinese source');
      expect(manifest['$seed:source:ja'], isNotNull, reason: '$seed Japanese source');
    }

    expect(manifest.keys, hasLength(60));
  });
}
