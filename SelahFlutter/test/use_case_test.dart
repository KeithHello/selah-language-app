import 'package:flutter_test/flutter_test.dart';
import 'package:selah/data/fixture_gateway.dart';
import 'package:selah/data/local_database.dart';
import 'package:selah/data/repository_impl.dart';
import 'package:selah/domain/entities.dart';
import 'package:selah/domain/selah_enums.dart';
import 'package:selah/domain/use_cases.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SelahLocalDatabase db;

  setUp(() async {
    db = await SelahLocalDatabase.open(inMemory: true);
  });

  tearDown(() async {
    await db.close();
  });

  test('生成句子用例：保存句子、词汇与事件', () async {
    final useCase = GenerateSentenceUseCase(
      api: FixtureSelahApiClient(),
      sentences: SqliteSentenceRepository(db),
      vocab: SqliteVocabRepository(db),
      events: SqliteLearningEventRepository(db),
    );

    final sentence = await useCase.execute(sourceText: '今天過得怎麼樣？');

    expect(sentence.enText, isNotEmpty);
    expect(sentence.zhText, '今天過得怎麼樣？');
    expect(await db.sentenceCount(), 1);

    final vocab = await db.fetchVocabForSentence(sentence.id);
    expect(vocab, isNotEmpty);

    final events = await db.fetchRecentEvents();
    expect(events.single.type, LearningEventType.sentenceCreated);
  });

  test('生成音频用例：失败时建立重试任务', () async {
    final now = DateTime.now();
    final sentence = Sentence(
      id: 's-1',
      zhText: '測試',
      enText: 'A test sentence.',
      category: SentenceCategory.life,
      difficulty: 'intermediate',
      origin: SentenceOrigin.manual,
      createdAt: now,
    );
    await db.insertSentence(sentence);

    final useCase = GenerateAudioUseCase(
      api: FixtureSelahApiClient(failNextAudio: true),
      assets: SqliteAudioAssetRepository(db),
      jobs: SqliteGenerationJobRepository(db),
    );

    final asset = await useCase.execute(
      sentence: sentence,
      voiceProfile: VoiceProfile.gentleNatural,
    );

    expect(asset.status, AudioGenerationStatus.failed);
    final jobs = await db.fetchPendingJobs(now: now);
    expect(jobs, isNotEmpty);
    expect(jobs.single.sentenceId, 's-1');
  });

  test('Listen 用例：下载并记录事件', () async {
    final now = DateTime.now();
    final sentence = Sentence(
      id: 's-2',
      zhText: '測試',
      enText: 'Listen me.',
      category: SentenceCategory.life,
      difficulty: 'intermediate',
      origin: SentenceOrigin.manual,
      createdAt: now,
    );
    await db.insertSentence(sentence);

    var downloads = 0;
    final useCase = ListenUseCase(
      api: FixtureSelahApiClient(),
      assets: SqliteAudioAssetRepository(db),
      events: SqliteLearningEventRepository(db),
      downloader: (id, url, sha) async {
        downloads++;
        expect(url, startsWith('fixture://'));
      },
    );

    final asset = await useCase.execute(
      sentence: sentence,
      voiceProfile: VoiceProfile.gentleNatural,
    );

    expect(asset.status, AudioGenerationStatus.ready);
    expect(downloads, 1);
    final events = await db.fetchRecentEvents(type: LearningEventType.listenCompleted.apiValue);
    expect(events, isNotEmpty);
  });
}
