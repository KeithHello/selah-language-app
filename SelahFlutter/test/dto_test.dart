import 'package:flutter_test/flutter_test.dart';
import 'package:selah/data/dto.dart';

void main() {
  test('BootstrapConfigDto 解析并映射为实体', () {
    final dto = BootstrapConfigDto.fromJson({
      'sourceLanguages': ['zh-Hant'],
      'targetLanguages': ['en'],
      'defaultVoiceProfile': 'gentle-natural',
      'voiceProfiles': [
        {
          'id': 'gentle-natural',
          'label': '溫柔自然',
          'description': '溫暖、自然',
        },
      ],
      'seedSentencePackVersion': 'v8.2',
      'promptVersion': 'p1',
      'featureFlags': {'seed_audio_prefetch': true},
    });
    final entity = dto.toEntity();
    expect(entity.sourceLanguages, ['zh-Hant']);
    expect(entity.defaultVoiceProfile, 'gentle-natural');
    expect(entity.voiceProfiles.single.label, '溫柔自然');
    expect(entity.featureFlags['seed_audio_prefetch'], isTrue);
  });

  test('GeneratedSentenceDto 解析映射为实体', () {
    final dto = GeneratedSentenceDto.fromJson({
      'sentenceId': 's-1',
      'zhText': '今天過得怎麼樣？',
      'enText': 'How was your day today?',
      'category': 'life',
      'deconstruction': [
        {
          'surfaceText': 'your day',
          'meaning': '你的一天',
          'type': 'phrase',
        },
      ],
      'vocabCandidates': [
        {
          'surfaceText': 'day',
          'meaningInContext': '一天',
          'suggestedHelpState': 'new',
        },
      ],
    });
    final entity = dto.toEntity();
    expect(entity.sentenceId, 's-1');
    expect(entity.enText, 'How was your day today?');
    expect(entity.deconstruction.single.surfaceText, 'your day');
    expect(entity.vocabCandidates.single.surfaceText, 'day');
  });

  test('GeneratedAudioDto 解析映射为实体', () {
    final dto = GeneratedAudioDto.fromJson({
      'status': 'ready',
      'voiceProfile': 'gentle-natural',
      'manifestId': 'm-1',
      'downloadUrl': 'https://example.com/a.mp3',
      'sha256': 'abc',
      'byteSize': 100,
      'durationMs': 3000,
      'cacheHit': true,
    });
    final entity = dto.toEntity();
    expect(entity.isReady, isTrue);
    expect(entity.cacheHit, isTrue);
    expect(entity.byteSize, 100);
  });
}
