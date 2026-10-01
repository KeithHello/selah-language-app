import 'package:flutter_test/flutter_test.dart';
import 'package:selah/web/domain/learning_models.dart';
import 'package:selah/web/l10n/selah_strings.dart';
import 'package:selah/web/l10n/selah_ja.dart';
import 'package:selah/web/l10n/selah_zh_hans.dart';
import 'package:selah/web/l10n/selah_zh_hant.dart';

void main() {
  test('all supported locales expose the same application string keys', () {
    expect(
      selahZhHantOverrides.keys.toSet(),
      selahZhHansOverrides.keys.toSet(),
    );
    expect(selahZhHantOverrides.keys.toSet(), selahJaOverrides.keys.toSet());
    final keySets = supportedUiLocales
        .map((locale) => SelahStrings.of(locale).keys.toSet())
        .toList();
    expect(keySets[1], keySets[0]);
    expect(keySets[2], keySets[0]);
  });

  test('navigation and language labels use the requested locale', () {
    expect(SelahStrings.of('zh-Hant').tabListen(), contains('聽'));
    expect(SelahStrings.of('zh-Hans').tabListen(), '聆听');
    expect(SelahStrings.of('ja').tabListen(), 'リスニング');
    expect(SelahStrings.of('zh-Hant').languageTitle(), '語言');
    expect(SelahStrings.of('ja').nativeLanguageLabel(), '母語');
    expect(
      SelahStrings.of('zh-Hant').text('settings.language.comingSoon'),
      '之後準備加入',
    );
    expect(
      SelahStrings.of('zh-Hans').text('settings.language.comingSoon'),
      '之后准备加入',
    );
    expect(
      SelahStrings.of('ja').text('settings.language.comingSoon'),
      '後日追加予定',
    );
  });

  test('native language copy accepts the unified script choices', () {
    final strings = SelahStrings.of('zh-Hant');
    expect(strings.todayInputHint('zh-Hant'), contains('今天'));
    expect(strings.todayInputHint('zh-Hans'), contains('今天'));
    expect(strings.todayInputHint('ja'), contains('今日は'));
    expect(strings.nativeLanguageValue('zh-Hant'), '中文');
    expect(strings.nativeLanguageValue('zh-Hans'), '中文');
    expect(strings.nativeLanguageValue('ja'), '日本語');
    expect(
      strings.todayInputHint('zh-Hant'),
      isNot(strings.todayInputHint('ja')),
    );
  });

  test('unsupported locale falls back to Traditional Chinese', () {
    expect(SelahStrings.of('en').tabSettings(), '設定');
  });

  test('notes controls have localized copy in every supported locale', () {
    expect(SelahStrings.of('zh-Hant').text('notes.featured'), '重點表達');
    expect(SelahStrings.of('zh-Hant').text('notes.listen'), '聽這句');
    expect(SelahStrings.of('zh-Hans').text('notes.expand'), '展开拆解');
    expect(SelahStrings.of('ja').text('notes.practice'), 'この文を練習');
  });

  test('today quick start has welcoming copy in every supported locale', () {
    expect(
      SelahStrings.of('zh-Hant').text('today.quickListen.title'),
      '聽聽生活裡的話',
    );
    expect(SelahStrings.of('zh-Hans').text('today.quickSpeak.title'), '说说今天');
    expect(SelahStrings.of('ja').text('today.quickListen.title'), '暮らしの言葉を聞く');
    for (final locale in supportedUiLocales) {
      final strings = SelahStrings.of(locale);
      for (final key in [
        'today.welcome.title',
        'today.welcome.detail',
        'today.suggestions.title',
        'today.focus.next',
        'today.focus.stop',
      ]) {
        expect(strings.text(key), isNot(key));
      }
    }
  });

  test('listen phrase peek copy is localized in every supported locale', () {
    expect(SelahStrings.of('zh-Hans').text('listen.peekHint'), '点选查看母语');
    expect(SelahStrings.of('zh-Hant').text('listen.peekHint'), '點選查看母語');
    expect(SelahStrings.of('ja').text('listen.peekHint'), 'タップして母語を表示');
  });

  test(
    'onboarding selection copy states a three-sentence minimum in every locale',
    () {
      expect(
        SelahStrings.of(
          'zh-Hans',
        ).message('onboarding.selectedCount', {'count': '6'}),
        '已选 6 句（至少 3 句）',
      );
      expect(
        SelahStrings.of(
          'zh-Hant',
        ).message('onboarding.selectedCount', {'count': '6'}),
        '已選 6 句（至少 3 句）',
      );
      expect(
        SelahStrings.of(
          'ja',
        ).message('onboarding.selectedCount', {'count': '6'}),
        '6文選択済み（最低3文）',
      );
      expect(
        SelahStrings.of('zh-Hans').text('onboarding.selectTitle'),
        contains('三'),
      );
      expect(
        SelahStrings.of('zh-Hant').text('onboarding.selectTitle'),
        contains('三'),
      );
      expect(
        SelahStrings.of('ja').text('onboarding.selectTitle'),
        contains('3'),
      );
    },
  );

  test(
    'onboarding validation failure is localized from the controller message',
    () {
      expect(
        SelahStrings.of('zh-Hant').translateLegacy('请选择至少三句想学的表达。'),
        '請選擇至少三句想學的表達。',
      );
      expect(
        SelahStrings.of('ja').translateLegacy('请选择至少三句想学的表达。'),
        '学びたい表現を3文以上選んでください。',
      );
    },
  );

  test('native voice settings copy exists in every supported locale', () {
    expect(SelahStrings.of('zh-Hans').text('settings.nativeVoice'), '母语声线');
    expect(SelahStrings.of('zh-Hant').text('settings.nativeVoice'), '母語聲線');
    expect(SelahStrings.of('ja').text('settings.nativeVoice'), '母語の声');
    expect(
      SelahStrings.of('zh-Hans').nativeVoiceLabel('native-gentle'),
      '温柔自然',
    );
  });

  test('learning profile section title is localized in every locale', () {
    expect(
      SelahStrings.of('zh-Hans').text('settings.learningProfile.title'),
      '关于你的学习',
    );
    expect(
      SelahStrings.of('zh-Hant').text('settings.learningProfile.title'),
      '關於你的學習',
    );
    expect(
      SelahStrings.of('ja').text('settings.learningProfile.title'),
      'あなたの学習について',
    );
    expect(
      SelahStrings.of('zh-Hant').text('auth.profile.detail'),
      contains('不會影響試用或會員權益'),
    );
    expect(
      SelahStrings.of('ja').text('auth.profile.detail'),
      contains('トライアルや会員権益には影響しません'),
    );
  });

  test(
    'focused listening copy and position interpolation cover all locales',
    () {
      const keys = [
        'listen.library',
        'listen.previous',
        'listen.nextPlay',
        'listen.replay',
        'listen.resume',
        'listen.preparing',
        'listen.currentSentence',
        'listen.lastSentence',
        'listen.nativePrompt',
        'listen.unavailable',
        'listen.keyboardHint',
        'listen.speedTitle',
      ];
      for (final locale in supportedUiLocales) {
        final strings = SelahStrings.of(locale);
        for (final key in keys) {
          expect(strings.text(key), isNot(key), reason: '$locale: $key');
        }
        expect(
          strings.message('listen.position', {'index': '3', 'count': '21'}),
          isNot(contains('{index}')),
          reason: '$locale position index',
        );
        expect(
          strings.message('listen.position', {'index': '3', 'count': '21'}),
          isNot(contains('{count}')),
          reason: '$locale position count',
        );
      }
    },
  );
}
