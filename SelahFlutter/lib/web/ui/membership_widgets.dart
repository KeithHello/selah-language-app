import 'package:flutter/material.dart';
import '../../design/selah_colors.dart';
import '../../design/selah_spacing.dart';
import '../../design/selah_typography.dart';
import '../domain/membership.dart';
import '../membership_controller.dart';

class MembershipPlansView extends StatelessWidget {
  const MembershipPlansView({
    required this.controller,
    required this.uiLocale,
    this.onStartTrial,
    this.onBuyMonthly,
    this.onBuyPro,
    super.key,
  });

  final MembershipController controller;
  final String uiLocale;
  final VoidCallback? onStartTrial;
  final VoidCallback? onBuyMonthly;
  final VoidCallback? onBuyPro;

  @override
  Widget build(BuildContext context) {
    String copy(String key) => _membershipCopy(uiLocale, key);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(copy('headline'), style: SelahTypography.headlineLarge()),
        const SizedBox(height: SelahSpacing.xs),
        Text(
          copy('subtitle'),
          style: SelahTypography.bodyMedium(color: SelahColors.textSecondary),
        ),
        const SizedBox(height: SelahSpacing.xl),
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 640;
            final children = [
              Expanded(
                flex: isNarrow ? 0 : 1,
                child: _PlanCard(
                  title: copy('trialTitle'),
                  tag: copy('trialTag'),
                  price: copy('free'),
                  subtitle: copy('trialSubtitle'),
                  buttonLabel: copy('trialButton'),
                  footerLabel: copy('trialFooter'),
                  onPressed: onStartTrial,
                  items: [
                    copy('trialSentences'),
                    copy('trialTts'),
                    copy('trialTranscription'),
                    copy('trialPreparation'),
                  ],
                ),
              ),
              SizedBox(
                width: isNarrow ? 0 : SelahSpacing.lg,
                height: isNarrow ? SelahSpacing.lg : 0,
              ),
              Expanded(
                flex: isNarrow ? 0 : 1,
                child: _PlanCard(
                  title: copy('monthlyTitle'),
                  tag: copy('monthlyTag'),
                  price: '¥ 39.9',
                  priceUnit: copy('monthlyUnit'),
                  subtitle: copy('monthlySubtitle'),
                  buttonLabel: controller.summary.paymentProviderConfigured
                      ? copy('monthlyButton')
                      : copy('paymentPlannedButton'),
                  footerLabel: controller.summary.paymentProviderConfigured
                      ? copy('monthlyFooter')
                      : copy('paymentPlannedFooter'),
                  isPrimary: true,
                  onPressed: onBuyMonthly,
                  items: [
                    copy('monthlySentences'),
                    copy('monthlyTts'),
                    copy('monthlyTranscription'),
                    copy('monthlyPreparation'),
                  ],
                ),
              ),
              SizedBox(
                width: isNarrow ? 0 : SelahSpacing.lg,
                height: isNarrow ? SelahSpacing.lg : 0,
              ),
              Expanded(
                flex: isNarrow ? 0 : 1,
                child: _PlanCard(
                  title: copy('proTitle'),
                  tag: copy('proTag'),
                  price:
                      '¥ ${(controller.summary.proPriceFenCny / 100).toStringAsFixed(1)}',
                  priceUnit: copy('monthlyUnit'),
                  subtitle: copy('proSubtitle'),
                  buttonLabel: controller.proSalesAvailable
                      ? copy('proButton')
                      : copy('proPlannedButton'),
                  footerLabel: controller.proSalesAvailable
                      ? copy('proFooter')
                      : copy('proPlannedFooter'),
                  onPressed: onBuyPro,
                  items: [
                    copy('proSentences'),
                    copy('proTts'),
                    copy('proTranscription'),
                    copy('proPreparation'),
                  ],
                ),
              ),
            ];
            return isNarrow
                ? Column(children: children)
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: children,
                  );
          },
        ),
        const SizedBox(height: SelahSpacing.xl),
        Container(
          padding: const EdgeInsets.all(SelahSpacing.md),
          decoration: BoxDecoration(
            color: SelahColors.cardPrimary,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: SelahColors.border),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                size: 20,
                color: SelahColors.coral,
              ),
              const SizedBox(width: SelahSpacing.sm),
              Expanded(
                child: Text(
                  copy('modelDisclosure'),
                  style: SelahTypography.bodySmall(
                    color: SelahColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The server controls whether this product gate is active. Keeping the
/// public free-mode message explicit prevents an offline or unconfigured
/// client from accidentally presenting a fake quota balance.
class MembershipCenter extends StatelessWidget {
  const MembershipCenter({
    required this.controller,
    required this.uiLocale,
    super.key,
  });

  final MembershipController controller;
  final String uiLocale;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        String copy(String key) => _membershipCopy(uiLocale, key);
        if (controller.loading && !controller.checked) {
          return const Center(child: CircularProgressIndicator());
        }
        final summary = controller.summary;
        final children = <Widget>[
          if (controller.error != null)
            _MembershipNotice(
              icon: Icons.info_outline_rounded,
              color: SelahColors.amber,
              text: controller.error!,
            ),
          if (summary.hasActiveEntitlements) ...[
            ActiveMembershipBanner(summary: summary, uiLocale: uiLocale),
            const SizedBox(height: SelahSpacing.lg),
          ],
        ];

        if (!summary.membershipModeEnabled) {
          return const SizedBox.shrink();
        }

        final trialNotice = _trialNotice(summary, copy);
        if (trialNotice != null) {
          children.addAll([
            trialNotice,
            const SizedBox(height: SelahSpacing.lg),
          ]);
        }

        children.add(
          MembershipPlansView(
            controller: controller,
            uiLocale: uiLocale,
            onStartTrial: controller.trialSignupsAvailable
                ? controller.showTrialInfo
                : null,
            onBuyMonthly:
                controller.membershipSalesAvailable &&
                    !controller.checkoutLoading
                ? () => controller.startMonthlyCheckout()
                : null,
            onBuyPro:
                controller.proSalesAvailable && !controller.checkoutLoading
                ? () => controller.startProCheckout(uiLocale: uiLocale)
                : null,
          ),
        );
        if (controller.pendingOrderId != null ||
            controller.pendingClientRequestId != null) {
          children.addAll([
            const SizedBox(height: SelahSpacing.lg),
            _MembershipNotice(
              icon: Icons.receipt_long_outlined,
              color: SelahColors.lavender,
              title: copy('pendingTitle'),
              text: controller.checkoutStatus ?? copy('pendingBody'),
              actionLabel: copy('checkOrder'),
              onAction: controller.checkoutLoading
                  ? null
                  : controller.refreshPendingOrder,
            ),
          ]);
        } else if (controller.checkoutStatus != null) {
          children.addAll([
            const SizedBox(height: SelahSpacing.lg),
            _MembershipNotice(
              icon: Icons.check_circle_outline_rounded,
              color: SelahColors.sage,
              text: controller.checkoutStatus!,
            ),
          ]);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        );
      },
    );
  }
}

Widget? _trialNotice(
  MembershipSummary summary,
  String Function(String key) copy,
) {
  return switch (summary.trialState) {
    TrialState.notStarted => _MembershipNotice(
      icon: Icons.hourglass_empty_rounded,
      color: SelahColors.lavender,
      title: copy('trialNotStartedTitle'),
      text: copy('trialNotStartedBody'),
    ),
    TrialState.preparing => _MembershipNotice(
      icon: Icons.pending_actions_rounded,
      color: SelahColors.lavender,
      title: copy('trialPreparingTitle'),
      text: copy('trialPreparingBody'),
    ),
    TrialState.expired => _MembershipNotice(
      icon: Icons.lock_clock_outlined,
      color: SelahColors.amber,
      title: copy('trialExpiredTitle'),
      text: copy('trialExpiredBody'),
    ),
    TrialState.unavailable => _MembershipNotice(
      icon: Icons.warning_amber_rounded,
      color: SelahColors.amber,
      title: copy('trialUnavailableTitle'),
      text: copy('trialUnavailableBody'),
    ),
    TrialState.active => null,
  };
}

class _MembershipNotice extends StatelessWidget {
  const _MembershipNotice({
    required this.icon,
    required this.color,
    required this.text,
    this.title,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final Color color;
  final String text;
  final String? title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SelahSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: SelahSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(title!, style: SelahTypography.headlineMedium()),
                if (title != null) const SizedBox(height: 4),
                Text(text, style: SelahTypography.bodySmall()),
                if (actionLabel != null) ...[
                  const SizedBox(height: 8),
                  TextButton(onPressed: onAction, child: Text(actionLabel!)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.tag,
    required this.price,
    this.priceUnit,
    required this.subtitle,
    required this.buttonLabel,
    required this.footerLabel,
    required this.items,
    this.isPrimary = false,
    this.onPressed,
  });

  final String title;
  final String tag;
  final String price;
  final String? priceUnit;
  final String subtitle;
  final String buttonLabel;
  final String footerLabel;
  final List<String> items;
  final bool isPrimary;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(SelahSpacing.lg),
      decoration: BoxDecoration(
        color: SelahColors.cardPrimary,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPrimary
              ? SelahColors.coral.withValues(alpha: 0.5)
              : SelahColors.border,
          width: isPrimary ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SelahTypography.headlineLarge(),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isPrimary
                        ? SelahColors.coral.withValues(alpha: 0.1)
                        : SelahColors.border.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tag,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: SelahTypography.bodySmall(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: SelahSpacing.md),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 4,
            children: [
              Text(price, style: SelahTypography.displayLarge()),
              if (priceUnit != null) ...[
                Text(
                  priceUnit!,
                  style: SelahTypography.bodySmall(
                    color: SelahColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
          Text(
            subtitle,
            style: SelahTypography.bodySmall(color: SelahColors.textSecondary),
          ),
          const SizedBox(height: SelahSpacing.lg),
          const Divider(),
          const SizedBox(height: SelahSpacing.sm),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.check, size: 16, color: SelahColors.coral),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      softWrap: true,
                      style: SelahTypography.bodyMedium(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: SelahSpacing.xl),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: isPrimary
                ? FilledButton(
                    onPressed: onPressed,
                    style: FilledButton.styleFrom(
                      backgroundColor: SelahColors.coral,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      buttonLabel,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  )
                : OutlinedButton(
                    onPressed: onPressed,
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(buttonLabel),
                  ),
          ),
          const SizedBox(height: SelahSpacing.xs),
          Center(
            child: Text(
              footerLabel,
              style: SelahTypography.bodySmall(
                color: SelahColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ActiveMembershipBanner extends StatelessWidget {
  const ActiveMembershipBanner({
    required this.summary,
    required this.uiLocale,
    this.onViewPlans,
    super.key,
  });

  final MembershipSummary summary;
  final String uiLocale;
  final VoidCallback? onViewPlans;

  @override
  Widget build(BuildContext context) {
    if (!summary.membershipModeEnabled || !summary.hasActiveEntitlements) {
      return const SizedBox.shrink();
    }

    final planName = summary.plan == MembershipPlan.monthly
        ? _membershipCopy(uiLocale, 'monthlyTitle')
        : summary.plan == MembershipPlan.pro
        ? _membershipCopy(uiLocale, 'proTitle')
        : _membershipCopy(uiLocale, 'trialTitle');
    final expiresText = summary.periodEndsAt != null
        ? _formatDate(summary.periodEndsAt!, uiLocale)
        : '';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SelahSpacing.md,
        vertical: SelahSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: SelahColors.cardPrimary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SelahColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.star_outline, size: 18, color: SelahColors.coral),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$planName · ${_membershipCopy(uiLocale, 'expires')} $expiresText',
              style: SelahTypography.bodyMedium(),
            ),
          ),
          const Spacer(),
          if (onViewPlans != null)
            TextButton(
              onPressed: onViewPlans,
              child: Text(_membershipCopy(uiLocale, 'viewPlans')),
            ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime date, String locale) {
  final local = date.toLocal();
  if (locale == 'ja') return '${local.year}/${local.month}/${local.day}';
  return locale == 'zh-Hant'
      ? '${local.year} 年 ${local.month} 月 ${local.day} 日'
      : '${local.year} 年 ${local.month} 月 ${local.day} 日';
}

String _membershipCopy(String locale, String key) {
  final language = locale == 'ja'
      ? 'ja'
      : locale == 'zh-Hant'
      ? 'zh-Hant'
      : 'zh-Hans';
  return _membershipCopies[language]?[key] ??
      _membershipCopies['zh-Hans']![key]!;
}

const _membershipCopies = <String, Map<String, String>>{
  'zh-Hans': {
    'headline': '把想说的话，变成每天的小进步。',
    'subtitle': '先记下一句，再选择适合你的学习方式。',
    'trialTitle': '个人试用',
    'trialTag': '7 天体验',
    'free': '免费',
    'trialSubtitle': '首次个人表达生成成功后开始',
    'trialButton': '开始我的第一句',
    'trialFooter': '每个账户一次，无需付款',
    'trialSentences': '新增个人表达 30 条',
    'trialTts': '新增 AI 配音 3000 字符',
    'trialTranscription': '录音转写 5 分钟',
    'trialPreparation': '长文整理 3 次',
    'monthlyTitle': '月会员',
    'monthlyTag': '持续练习',
    'monthlyUnit': '人民币／月',
    'monthlySubtitle': '每个付费账期，给日常表达留些空间',
    'monthlyButton': '开通月会员',
    'paymentPlannedButton': '支付渠道待接入',
    'monthlyFooter': '主动续购，不自动扣款',
    'paymentPlannedFooter': '真实支付渠道配置完成后开放',
    'monthlySentences': '新增个人表达 300 条',
    'monthlyTts': '新增 AI 配音 30000 字符',
    'monthlyTranscription': '录音转写 60 分钟',
    'monthlyPreparation': '长文整理 30 次',
    'proTitle': 'Pro 会员',
    'proTag': '高频使用',
    'proSubtitle': '给高频生成、配音和转写更多空间',
    'proButton': '开通 Pro',
    'proPlannedButton': '即将开放',
    'proFooter': '主动续购，不自动扣款',
    'proPlannedFooter': '支付渠道与权益核验完成后开放',
    'proSentences': '新增个人表达 900 条',
    'proTts': '新增 AI 配音 90000 字符',
    'proTranscription': '录音转写 180 分钟',
    'proPreparation': '长文整理 90 次',
    'modelDisclosure': '使用 OpenAI GPT 模型生成和整理学习内容，语音由 AI 合成。',
    'freeModeTitle': '当前为公开体验模式',
    'freeModeBody': '会员限制尚未开启。已有内容和示例可以继续学习，开关启用后才会显示购买与试用入口。',
    'trialPreparingTitle': '试用准备中',
    'trialPreparingBody': '已为这次账户请求保留试用额度；首次个人表达成功保存后开始计时。',
    'trialNotStartedTitle': '试用尚未开始',
    'trialNotStartedBody': '7 天试用从第一条个人表达成功并由服务器保存后开始，不会因注册或登录提前计时。',
    'trialExpiredTitle': '试用已结束',
    'trialExpiredBody': '已有内容仍可学习，开通月会员后可继续新增生成。',
    'trialUnavailableTitle': '试用状态暂不可用',
    'trialUnavailableBody': '暂时无法确认权益，请稍后重试；不会把读取失败当作免费额度。',
    'pendingTitle': '订单等待核验',
    'pendingBody': '完成付款后查询原订单，查询期间不会重复创建或重复扣款。',
    'checkOrder': '查询订单状态',
    'expires': '有效至',
    'viewPlans': '查看方案说明',
  },
  'zh-Hant': {
    'headline': '把想說的話，變成每天的小進步。',
    'subtitle': '先記下一句，再選擇適合你的學習方式。',
    'trialTitle': '個人試用',
    'trialTag': '7 天體驗',
    'free': '免費',
    'trialSubtitle': '首次個人表達產生成功後開始',
    'trialButton': '開始我的第一句',
    'trialFooter': '每個帳戶一次，無須付款',
    'trialSentences': '新增個人表達 30 條',
    'trialTts': '新增 AI 配音 3000 字元',
    'trialTranscription': '錄音轉寫 5 分鐘',
    'trialPreparation': '長文整理 3 次',
    'monthlyTitle': '月會員',
    'monthlyTag': '持續練習',
    'monthlyUnit': '人民幣／月',
    'monthlySubtitle': '每個付費帳期，給日常表達留些空間',
    'monthlyButton': '開通月會員',
    'paymentPlannedButton': '支付渠道待接入',
    'monthlyFooter': '主動續購，不自動扣款',
    'paymentPlannedFooter': '真實支付渠道設定完成後開放',
    'monthlySentences': '新增個人表達 300 條',
    'monthlyTts': '新增 AI 配音 30000 字元',
    'monthlyTranscription': '錄音轉寫 60 分鐘',
    'monthlyPreparation': '長文整理 30 次',
    'proTitle': 'Pro 會員',
    'proTag': '高頻使用',
    'proSubtitle': '給高頻產生、配音和轉寫更多空間',
    'proButton': '開通 Pro',
    'proPlannedButton': '即將開放',
    'proFooter': '主動續購，不自動扣款',
    'proPlannedFooter': '支付渠道與權益核驗完成後開放',
    'proSentences': '新增個人表達 900 條',
    'proTts': '新增 AI 配音 90000 字元',
    'proTranscription': '錄音轉寫 180 分鐘',
    'proPreparation': '長文整理 90 次',
    'modelDisclosure': '使用 OpenAI GPT 模型產生與整理學習內容，語音由 AI 合成。',
    'freeModeTitle': '目前為公開體驗模式',
    'freeModeBody': '會員限制尚未開啟。已有內容和範例可以繼續學習，開關啟用後才會顯示購買與試用入口。',
    'trialPreparingTitle': '試用準備中',
    'trialPreparingBody': '已為這次帳戶請求保留試用額度；首次個人表達成功儲存後開始計時。',
    'trialNotStartedTitle': '試用尚未開始',
    'trialNotStartedBody': '7 天試用從第一條個人表達成功並由伺服器儲存後開始，不會因註冊或登入提前計時。',
    'trialExpiredTitle': '試用已結束',
    'trialExpiredBody': '已有內容仍可學習，開通月會員後可繼續新增生成。',
    'trialUnavailableTitle': '試用狀態暫不可用',
    'trialUnavailableBody': '暫時無法確認權益，請稍後重試；不會把讀取失敗當作免費額度。',
    'pendingTitle': '訂單等待核驗',
    'pendingBody': '完成付款後查詢原訂單，查詢期間不會重複建立或重複扣款。',
    'checkOrder': '查詢訂單狀態',
    'expires': '有效至',
    'viewPlans': '查看方案說明',
  },
  'ja': {
    'headline': '思いを、毎日の小さな前進へ。',
    'subtitle': 'まず一文を書いて、自分に合う学び方を選びましょう。',
    'trialTitle': '個人トライアル',
    'trialTag': '7日間',
    'free': '無料',
    'trialSubtitle': '最初の個人表現の生成成功から開始',
    'trialButton': '最初の一文を始める',
    'trialFooter': '1アカウント1回、支払い不要',
    'trialSentences': '個人表現 30 文',
    'trialTts': 'AI音声 3000 文字',
    'trialTranscription': '文字起こし 5 分',
    'trialPreparation': '長文整理 3 回',
    'monthlyTitle': '月額メンバー',
    'monthlyTag': '継続練習',
    'monthlyUnit': '人民元／月',
    'monthlySubtitle': '毎月の学びに、日々の表現の余白を。',
    'monthlyButton': '月額を開く',
    'paymentPlannedButton': '決済チャネル準備中',
    'monthlyFooter': '手動更新、自動請求なし',
    'paymentPlannedFooter': '実際の決済チャネルの設定後に公開',
    'monthlySentences': '個人表現 300 文',
    'monthlyTts': 'AI音声 30000 文字',
    'monthlyTranscription': '文字起こし 60 分',
    'monthlyPreparation': '長文整理 30 回',
    'proTitle': 'Pro メンバー',
    'proTag': '高頻度向け',
    'proSubtitle': '生成・音声・文字起こしをたくさん使う人へ',
    'proButton': 'Pro を開く',
    'proPlannedButton': '近日公開',
    'proFooter': '手動更新、自動請求なし',
    'proPlannedFooter': '決済と権益の確認が整い次第公開',
    'proSentences': '個人表現 900 文',
    'proTts': 'AI音声 90000 文字',
    'proTranscription': '文字起こし 180 分',
    'proPreparation': '長文整理 90 回',
    'modelDisclosure': 'OpenAI GPT モデルで学習内容を生成・整理し、音声は AI 合成です。',
    'freeModeTitle': '現在は公開体験モードです',
    'freeModeBody': '会員制限はまだ有効ではありません。保存済みの内容とサンプルは学習できます。',
    'trialPreparingTitle': 'トライアル準備中',
    'trialPreparingBody': 'アカウントのトライアル枠を確保しました。最初の個人表現が保存された時点から計測します。',
    'trialNotStartedTitle': 'トライアルは未開始です',
    'trialNotStartedBody':
        '7日間は、最初の個人表現が成功してサーバーに保存された時点から始まります。登録やログインでは始まりません。',
    'trialExpiredTitle': 'トライアル終了',
    'trialExpiredBody': '保存済みの内容は学習できます。新しい生成を続けるには月額メンバーを開いてください。',
    'trialUnavailableTitle': 'トライアル状態を確認できません',
    'trialUnavailableBody':
        '権益を確認できませんでした。しばらくしてから再試行してください。読み取り失敗を無料枠として扱いません。',
    'pendingTitle': '注文を確認中',
    'pendingBody': '支払い後に同じ注文を確認します。確認中に重複注文は作成しません。',
    'checkOrder': '注文状況を確認',
    'expires': '有効期限',
    'viewPlans': 'プランを見る',
  },
};
