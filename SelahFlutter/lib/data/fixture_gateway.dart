import '../domain/entities.dart';
import '../domain/repositories.dart';
import '../domain/selah_enums.dart';

/// Fixture 网关：本地模拟现有 Edge Functions 契约。
/// 不访问 Supabase、不产生远端写入、不产生 TTS 费用。
/// 用于测试、预览和离线开发。
class FixtureSelahApiClient implements SelahApiClient {
  FixtureSelahApiClient({this.failNextAudio = false});

  bool failNextAudio;
  int _audioRequests = 0;

  @override
  Future<BootstrapConfig> fetchBootstrap() async {
    return const BootstrapConfig(
      sourceLanguages: ['zh-Hant'],
      targetLanguages: ['en'],
      defaultVoiceProfile: 'gentle-natural',
      voiceProfiles: [
        VoiceProfileConfig(id: 'gentle-natural', label: '溫柔自然', description: '溫暖、自然'),
        VoiceProfileConfig(id: 'clear-slow', label: '清晰慢速', description: '發音清晰、速度較慢'),
        VoiceProfileConfig(id: 'daily-bright', label: '日常輕快', description: '輕快、有活力'),
        VoiceProfileConfig(id: 'elegant-british', label: '優雅英式', description: '柔和、優雅英式'),
      ],
      seedSentencePackVersion: 'v8.2',
      promptVersion: 'p1',
      featureFlags: {'seed_audio_prefetch': true},
    );
  }

  @override
  Future<GeneratedSentenceResult> generateSentence({
    required String sourceText,
    required SourceLanguage sourceLanguage,
    required TargetLanguage targetLanguage,
    SentenceCategory? categoryHint,
  }) async {
    // 模拟服务端翻译：固定样板，保持确定性以便测试。
    final seed = sourceText.trim().isEmpty ? '今天過得怎麼樣？' : sourceText.trim();
    return GeneratedSentenceResult(
      sentenceId: 'fx-${seed.hashCode.abs().toRadixString(16)}',
      zhText: seed,
      enText: _fixtureEnglish(seed),
      category: categoryHint ?? SentenceCategory.life,
      deconstruction: const [
        DeconstructionItem(surfaceText: 'a good day', meaning: '美好的一天', type: 'phrase'),
      ],
      vocabCandidates: const [
        VocabCandidate(surfaceText: 'day', meaningInContext: '一天', helpState: VocabHelpState.new_),
      ],
    );
  }

  @override
  Future<GeneratedAudioResult> generateAudio({
    required String sentenceId,
    required String targetText,
    required VoiceProfile voiceProfile,
    required AudioGenerationReason reason,
  }) async {
    _audioRequests++;
    if (failNextAudio) {
      failNextAudio = false;
      return GeneratedAudioResult(
        status: AudioGenerationStatus.failed,
        voiceProfile: voiceProfile,
        errorCode: 'provider_unavailable',
      );
    }
    final hash = _sha256Hex('$targetText|${voiceProfile.apiValue}');
    return GeneratedAudioResult(
      status: AudioGenerationStatus.ready,
      voiceProfile: voiceProfile,
      manifestId: 'fx-manifest-$sentenceId',
      downloadUrl: 'fixture://audio/$sentenceId/$hash.mp3',
      storagePath: 'seed/$sentenceId/${voiceProfile.apiValue}/$hash.mp3',
      sha256: hash,
      byteSize: 80160,
      durationMs: 3600,
      cacheHit: _audioRequests > 1,
    );
  }

  @override
  Future<String?> audioDownloadUrl({
    required String sentenceId,
    required VoiceProfile voiceProfile,
  }) async {
    return 'fixture://audio/$sentenceId/${voiceProfile.apiValue}.mp3';
  }
}

String _sha256Hex(String input) {
  // 简化哈希：用于 fixture 确定性，不代表密码学用途。
  var h = 0x811c9dc5;
  for (final unit in input.codeUnits) {
    h ^= unit;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return h.toRadixString(16).padLeft(8, '0') * 8;
}

String _fixtureEnglish(String zh) {
  final map = <String, String>{
    '今天過得怎麼樣？': 'How was your day today?',
    '我想學英文': 'I want to learn English.',
    '這個禮拜很忙': 'This week has been very busy.',
    '晚上想吃火鍋': 'I want to eat hot pot tonight.',
    '工作壓力很大': 'Work has been really stressful.',
  };
  return map[zh] ?? 'That is a good thought. Let us put it into English.';
}
