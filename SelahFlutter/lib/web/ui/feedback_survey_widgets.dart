import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/selah_colors.dart';
import '../../design/selah_spacing.dart';
import '../../design/selah_typography.dart';
import '../domain/adaptive_feedback_survey.dart';
import '../feedback_survey_controller.dart';

class FeedbackSurveyInvite extends StatelessWidget {
  const FeedbackSurveyInvite({
    required this.controller,
    required this.uiLocale,
    required this.onOpen,
    super.key,
  });

  final FeedbackSurveyController controller;
  final String uiLocale;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (!controller.canShowInvite) return const SizedBox.shrink();
        String copy(String key) => _feedbackCopy(uiLocale, key);
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(SelahSpacing.md),
          decoration: BoxDecoration(
            color: SelahColors.sage.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: SelahColors.sage.withValues(alpha: 0.28)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.rate_review_outlined, color: SelahColors.sage),
              const SizedBox(width: SelahSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      copy('inviteTitle'),
                      style: SelahTypography.headlineMedium(),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      copy('inviteBody'),
                      style: SelahTypography.bodySmall(),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilledButton(
                          onPressed: onOpen,
                          child: Text(copy('inviteOpen')),
                        ),
                        TextButton(
                          onPressed: () => unawaited(controller.dismiss()),
                          child: Text(copy('later')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class FeedbackSurveySheet extends StatefulWidget {
  const FeedbackSurveySheet({
    required this.controller,
    required this.uiLocale,
    this.onViewPlans,
    super.key,
  });

  final FeedbackSurveyController controller;
  final String uiLocale;
  final VoidCallback? onViewPlans;

  @override
  State<FeedbackSurveySheet> createState() => _FeedbackSurveySheetState();
}

class _FeedbackSurveySheetState extends State<FeedbackSurveySheet> {
  int? _satisfaction;
  String? _scenario;
  String? _improvement;
  String? _purchaseIntent;
  String? _planInterest;
  String? _error;
  bool _submitting = false;
  bool _submitted = false;
  FeedbackSurveyAnswers? _answers;

  String copy(String key) => _feedbackCopy(widget.uiLocale, key);

  bool get _showsPlanQuestion =>
      _purchaseIntent == 'now' || _purchaseIntent == 'likely';

  bool get _canSubmit =>
      _satisfaction != null &&
      _scenario != null &&
      _improvement != null &&
      _purchaseIntent != null &&
      (!_showsPlanQuestion || _planInterest != null);

  @override
  Widget build(BuildContext context) {
    if (_submitted) return _buildThanks(context);
    final maxHeight = MediaQuery.sizeOf(context).height * .88;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            SelahSpacing.lg,
            SelahSpacing.lg,
            SelahSpacing.lg,
            SelahSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(copy('title'), style: SelahTypography.headlineLarge()),
              const SizedBox(height: 6),
              Text(
                copy('subtitle'),
                style: SelahTypography.bodySmall(
                  color: SelahColors.textSecondary,
                ),
              ),
              const SizedBox(height: SelahSpacing.lg),
              _radioQuestion<int>(
                title: copy('satisfactionQuestion'),
                selected: _satisfaction,
                options: [
                  for (var score = 1; score <= 5; score++)
                    _SurveyOption(score, copy('satisfaction$score')),
                ],
                onSelected: (value) => setState(() {
                  final previousLow =
                      _satisfaction != null && _satisfaction! <= 3;
                  final nextLow = value <= 3;
                  _satisfaction = value;
                  if (previousLow != nextLow) _improvement = null;
                }),
              ),
              const SizedBox(height: SelahSpacing.md),
              _radioQuestion<String>(
                title: copy('scenarioQuestion'),
                selected: _scenario,
                options: [
                  _SurveyOption('daily_conversation', copy('scenarioDaily')),
                  _SurveyOption('work_or_study', copy('scenarioWork')),
                  _SurveyOption('travel', copy('scenarioTravel')),
                  _SurveyOption(
                    'emotional_expression',
                    copy('scenarioEmotion'),
                  ),
                ],
                onSelected: (value) => setState(() => _scenario = value),
              ),
              const SizedBox(height: SelahSpacing.md),
              _radioQuestion<String>(
                title: _satisfaction != null && _satisfaction! <= 3
                    ? copy('blockerQuestion')
                    : copy('valueQuestion'),
                selected: _improvement,
                options: _improvementOptions(),
                onSelected: (value) => setState(() => _improvement = value),
              ),
              const SizedBox(height: SelahSpacing.md),
              _radioQuestion<String>(
                title: copy('purchaseQuestion'),
                selected: _purchaseIntent,
                options: [
                  _SurveyOption('now', copy('purchaseNow')),
                  _SurveyOption('likely', copy('purchaseLikely')),
                  _SurveyOption('not_sure', copy('purchaseNotSure')),
                  _SurveyOption('not_for_me', copy('purchaseNotForMe')),
                ],
                onSelected: (value) => setState(() {
                  _purchaseIntent = value;
                  if (!_showsPlanQuestion) _planInterest = null;
                }),
              ),
              if (_showsPlanQuestion) ...[
                const SizedBox(height: SelahSpacing.md),
                _radioQuestion<String>(
                  title: copy('planQuestion'),
                  selected: _planInterest,
                  options: [
                    _SurveyOption('plus', copy('planPlus')),
                    _SurveyOption('pro', copy('planPro')),
                    _SurveyOption('not_sure', copy('planNotSure')),
                  ],
                  onSelected: (value) => setState(() => _planInterest = value),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: SelahSpacing.sm),
                Text(
                  _error!,
                  style: SelahTypography.bodySmall(color: SelahColors.danger),
                ),
              ],
              const SizedBox(height: SelahSpacing.lg),
              Row(
                children: [
                  TextButton(
                    onPressed: _submitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: Text(copy('cancel')),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: !_canSubmit || _submitting ? null : _submit,
                    child: Text(
                      _submitting ? copy('submitting') : copy('submit'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<_SurveyOption<String>> _improvementOptions() {
    if (_satisfaction != null && _satisfaction! <= 3) {
      return [
        _SurveyOption('simpler_onboarding', copy('improvementOnboarding')),
        _SurveyOption('more_natural_phrasing', copy('improvementPhrasing')),
        _SurveyOption('faster_audio', copy('improvementAudio')),
        _SurveyOption('more_review_guidance', copy('improvementReview')),
      ];
    }
    return [
      _SurveyOption('more_natural_phrasing', copy('valuePhrasing')),
      _SurveyOption('more_review_guidance', copy('valueReview')),
      _SurveyOption('voice_and_listening', copy('valueListening')),
      _SurveyOption('long_text_workflow', copy('valueLongText')),
    ];
  }

  Widget _radioQuestion<T>({
    required String title,
    required T? selected,
    required List<_SurveyOption<T>> options,
    required ValueChanged<T> onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: SelahTypography.headlineMedium()),
        const SizedBox(height: 4),
        RadioGroup<T>(
          groupValue: selected,
          onChanged: (value) {
            if (value != null) onSelected(value);
          },
          child: Column(
            children: options
                .map(
                  (option) => RadioListTile<T>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: option.value,
                    title: Text(option.label),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final answers = FeedbackSurveyAnswers(
      satisfaction: _satisfaction!,
      scenario: _scenario!,
      improvement: _improvement!,
      purchaseIntent: _purchaseIntent!,
      planInterest: _planInterest,
    );
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.controller.submit(answers);
      if (!mounted) return;
      setState(() {
        _answers = answers;
        _submitted = true;
        _submitting = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = error.toString();
      });
    }
  }

  Widget _buildThanks(BuildContext context) {
    final purchase =
        _answers?.purchaseIntent == 'now' ||
        _answers?.purchaseIntent == 'likely';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(SelahSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.favorite_outline,
              color: SelahColors.coral,
              size: 30,
            ),
            const SizedBox(height: SelahSpacing.md),
            Text(copy('thanksTitle'), style: SelahTypography.headlineLarge()),
            const SizedBox(height: 8),
            Text(copy('thanksBody'), style: SelahTypography.bodyMedium()),
            if (purchase) ...[
              const SizedBox(height: SelahSpacing.lg),
              Text(copy('planCta'), style: SelahTypography.headlineMedium()),
              const SizedBox(height: 8),
              Text(
                copy('planCtaBody'),
                style: SelahTypography.bodySmall(
                  color: SelahColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: SelahSpacing.lg),
            Row(
              children: [
                if (purchase && widget.onViewPlans != null)
                  FilledButton(
                    onPressed: () async {
                      await widget.controller.viewPlan(
                        _answers?.planInterest ?? 'not_sure',
                      );
                      if (context.mounted) Navigator.of(context).pop();
                      widget.onViewPlans?.call();
                    },
                    child: Text(copy('viewPlans')),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(copy('done')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SurveyOption<T> {
  const _SurveyOption(this.value, this.label);

  final T value;
  final String label;
}

String _feedbackCopy(String locale, String key) {
  final language = locale == 'ja'
      ? 'ja'
      : locale == 'zh-Hant'
      ? 'zh-Hant'
      : 'zh-Hans';
  return _feedbackCopies[language]?[key] ?? _feedbackCopies['zh-Hans']![key]!;
}

const _feedbackCopies = <String, Map<String, String>>{
  'zh-Hans': {
    'inviteTitle': '用 60 秒，帮我们把真正有用的功能做好',
    'inviteBody': '根据你的实际学习情况回答几题；提交后可以直接看看适合你的会员方案。',
    'inviteOpen': '开始问卷',
    'later': '下次再说',
    'title': '你的学习体验，值得被听见',
    'subtitle': '只有 4～5 题。选项会根据你的回答变化，答案仅用于产品分析。',
    'satisfactionQuestion': '到目前为止，Selah 对你有多大帮助？',
    'satisfaction1': '1 · 几乎没有帮助',
    'satisfaction2': '2 · 帮助不大',
    'satisfaction3': '3 · 有一些帮助',
    'satisfaction4': '4 · 很有帮助',
    'satisfaction5': '5 · 已经融入我的学习',
    'scenarioQuestion': '你最常用 Selah 来处理哪种场景？',
    'scenarioDaily': '日常对话',
    'scenarioWork': '工作或学习',
    'scenarioTravel': '旅行和出行',
    'scenarioEmotion': '表达感受和想法',
    'blockerQuestion': '如果只能改进一件事，哪一项最重要？',
    'valueQuestion': '哪一项价值最值得我们继续投入？',
    'improvementOnboarding': '更容易开始和找到下一步',
    'improvementPhrasing': '英文更自然、更贴近语境',
    'improvementAudio': '配音更快、声线更多',
    'improvementReview': '复习提醒和练习路径更清楚',
    'valuePhrasing': '把真实想法变成自然英文',
    'valueReview': '持续复习并记住自己的表达',
    'valueListening': '反复聆听和开口练习',
    'valueLongText': '一次整理较长内容',
    'purchaseQuestion': '如果这些能力继续变好，你会考虑付费吗？',
    'purchaseNow': '我现在就想了解',
    'purchaseLikely': '如果适合，我很可能会',
    'purchaseNotSure': '我还不确定',
    'purchaseNotForMe': '暂时不会',
    'planQuestion': '你更想先了解哪个方案？',
    'planPlus': 'Plus：日常持续练习',
    'planPro': 'Pro：高频生成、配音和转写',
    'planNotSure': '还不确定，先看看区别',
    'cancel': '取消',
    'submit': '提交反馈',
    'submitting': '提交中…',
    'thanksTitle': '谢谢你，反馈已收到',
    'thanksBody': '我们会把相同选项的反馈放在一起分析，用来决定后续功能和体验。',
    'planCta': '想继续了解会员？',
    'planCtaBody': '先看清楚额度和适用场景，再决定是否购买。',
    'viewPlans': '查看会员方案',
    'done': '完成',
  },
  'zh-Hant': {
    'inviteTitle': '用 60 秒，幫我們把真正有用的功能做好',
    'inviteBody': '根據你的實際學習情況回答幾題；提交後可以直接看看適合你的會員方案。',
    'inviteOpen': '開始問卷',
    'later': '下次再說',
    'title': '你的學習體驗，值得被聽見',
    'subtitle': '只有 4～5 題。選項會根據你的回答變化，答案僅用於產品分析。',
    'satisfactionQuestion': '到目前為止，Selah 對你有多大幫助？',
    'satisfaction1': '1 · 幾乎沒有幫助',
    'satisfaction2': '2 · 幫助不大',
    'satisfaction3': '3 · 有一些幫助',
    'satisfaction4': '4 · 很有幫助',
    'satisfaction5': '5 · 已經融入我的學習',
    'scenarioQuestion': '你最常用 Selah 來處理哪種場景？',
    'scenarioDaily': '日常對話',
    'scenarioWork': '工作或學習',
    'scenarioTravel': '旅行和出行',
    'scenarioEmotion': '表達感受和想法',
    'blockerQuestion': '如果只能改進一件事，哪一項最重要？',
    'valueQuestion': '哪一項價值最值得我們繼續投入？',
    'improvementOnboarding': '更容易開始並找到下一步',
    'improvementPhrasing': '英文更自然、更貼近語境',
    'improvementAudio': '配音更快、聲線更多',
    'improvementReview': '複習提醒和練習路徑更清楚',
    'valuePhrasing': '把真實想法變成自然英文',
    'valueReview': '持續複習並記住自己的表達',
    'valueListening': '反覆聆聽和開口練習',
    'valueLongText': '一次整理較長內容',
    'purchaseQuestion': '如果這些能力繼續變好，你會考慮付費嗎？',
    'purchaseNow': '我現在就想了解',
    'purchaseLikely': '如果適合，我很可能會',
    'purchaseNotSure': '我還不確定',
    'purchaseNotForMe': '暫時不會',
    'planQuestion': '你更想先了解哪個方案？',
    'planPlus': 'Plus：日常持續練習',
    'planPro': 'Pro：高頻產生、配音和轉寫',
    'planNotSure': '還不確定，先看看區別',
    'cancel': '取消',
    'submit': '提交回饋',
    'submitting': '提交中…',
    'thanksTitle': '謝謝你，回饋已收到',
    'thanksBody': '我們會把相同選項的回饋放在一起分析，用來決定後續功能和體驗。',
    'planCta': '想繼續了解會員？',
    'planCtaBody': '先看清楚額度和適用場景，再決定是否購買。',
    'viewPlans': '查看會員方案',
    'done': '完成',
  },
  'ja': {
    'inviteTitle': '60 秒で、もっと役立つ機能を一緒につくる',
    'inviteBody': '実際の学び方について数問だけ教えてください。回答後に、合うメンバープランも確認できます。',
    'inviteOpen': 'アンケートを始める',
    'later': 'また今度',
    'title': 'あなたの学習体験を聞かせてください',
    'subtitle': '4～5問だけです。回答に応じて質問が変わり、回答はプロダクト分析にのみ使います。',
    'satisfactionQuestion': 'ここまで、Selah はどのくらい役立ちましたか？',
    'satisfaction1': '1 · ほとんど役立っていない',
    'satisfaction2': '2 · あまり役立っていない',
    'satisfaction3': '3 · 少し役立っている',
    'satisfaction4': '4 · とても役立っている',
    'satisfaction5': '5 · 学習の一部になっている',
    'scenarioQuestion': 'Selah を最もよく使う場面は？',
    'scenarioDaily': '日常会話',
    'scenarioWork': '仕事や勉強',
    'scenarioTravel': '旅行や外出',
    'scenarioEmotion': '気持ちや考えを伝える',
    'blockerQuestion': '一つだけ改善するとしたら、何が重要ですか？',
    'valueQuestion': '今後も力を入れてほしい価値は？',
    'improvementOnboarding': '始め方と次の一歩をわかりやすく',
    'improvementPhrasing': 'より自然で文脈に合う英語',
    'improvementAudio': '音声を速く、声の種類を増やす',
    'improvementReview': '復習リマインダーと道筋を明確に',
    'valuePhrasing': '本当の考えを自然な英語にする',
    'valueReview': '自分の表現を復習して覚える',
    'valueListening': '繰り返し聞いて声に出す',
    'valueLongText': '長めの内容をまとめて整理する',
    'purchaseQuestion': 'これらがさらに良くなったら、有料プランを検討しますか？',
    'purchaseNow': '今すぐ詳しく知りたい',
    'purchaseLikely': '合えば、たぶん利用したい',
    'purchaseNotSure': 'まだわからない',
    'purchaseNotForMe': '今は考えていない',
    'planQuestion': 'どのプランを先に知りたいですか？',
    'planPlus': 'Plus：日々の継続練習',
    'planPro': 'Pro：高頻度の生成・音声・文字起こし',
    'planNotSure': '違いを見てから決めたい',
    'cancel': 'キャンセル',
    'submit': 'フィードバックを送る',
    'submitting': '送信中…',
    'thanksTitle': 'ありがとうございます。受け付けました',
    'thanksBody': '同じ選択肢の回答をまとめて分析し、今後の機能と体験づくりに活かします。',
    'planCta': 'メンバープランを見ますか？',
    'planCtaBody': '上限と向いている使い方を確認してから、購入を決められます。',
    'viewPlans': 'メンバープランを見る',
    'done': '完了',
  },
};
