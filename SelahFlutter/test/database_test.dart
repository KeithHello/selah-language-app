import 'package:flutter_test/flutter_test.dart';
import 'package:selah/data/local_database.dart';
import 'package:selah/domain/entities.dart';
import 'package:selah/domain/selah_enums.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('SQLite V3 schema 可建表并保存句子', () async {
    final db = await SelahLocalDatabase.open(inMemory: true);
    final now = DateTime.now();
    await db.insertSentence(
      Sentence(
        id: 's-1',
        zhText: '今天過得怎麼樣？',
        enText: 'How was your day today?',
        category: SentenceCategory.life,
        difficulty: 'intermediate',
        origin: SentenceOrigin.manual,
        createdAt: now,
        updatedAt: now,
      ),
    );
    final fetched = await db.fetchSentence('s-1');
    expect(fetched, isNotNull);
    expect(fetched!.enText, 'How was your day today?');
    expect(await db.sentenceCount(), 1);

    // 偏好默认值
    final pref = await db.fetchPreference();
    expect(pref.voiceProfile, VoiceProfile.gentleNatural);
    await db.close();
  });

  test('音频资产保存与读取', () async {
    final db = await SelahLocalDatabase.open(inMemory: true);
    await db.insertAudioAsset(
      const AudioAsset(
        id: 'a-1',
        sentenceId: 's-1',
        voiceProfile: VoiceProfile.gentleNatural,
        status: AudioGenerationStatus.ready,
        localPath: '/tmp/a.mp3',
      ),
    );
    final assets = await db.fetchAudioForSentence('s-1');
    expect(assets.single.status, AudioGenerationStatus.ready);
    await db.close();
  });
}
