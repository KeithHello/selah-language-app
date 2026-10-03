import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/selah_colors.dart';
import '../../design/selah_dialog.dart';
import '../../design/selah_sheet.dart';
import '../../design/selah_motion.dart';
import '../../design/selah_motion_scope.dart';
import '../../design/selah_spacing.dart';
import '../../design/selah_typography.dart';
import '../../design/widgets/selah_card.dart';
import '../domain/membership.dart';
import '../domain/membership_quota_format.dart';
import '../membership_controller.dart';

class MembershipStatusCard extends StatelessWidget {
  const MembershipStatusCard({
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
        final summary = controller.summary;
        final activePeriod =
            summary.isPaidActive ||
            (summary.isTrialActive && summary.trialState == TrialState.active);
        final trialNotice = _trialNoticeFor(summary, uiLocale);
        final firstLoad = controller.loading && !controller.checked;
        final Widget hero;
        if (firstLoad) {
          hero = const _MembershipHeroShell(
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: CircularProgressIndicator(),
              ),
            ),
          );
        } else if (controller.statusError != null) {
          hero = _MembershipHeroShell(
            child: _MembershipNotice(
              text: _membershipCopy(uiLocale, 'statusError'),
              color: SelahColors.amber,
              action: TextButton(
                onPressed: controller.loading
                    ? null
                    : () => unawaited(controller.load()),
                child: Text(_membershipCopy(uiLocale, 'retry')),
              ),
            ),
          );
        } else {
          hero = _MembershipHeroShell(
            child: _buildHeroContent(
              context,
              summary,
              activePeriod,
              trialNotice,
            ),
          );
        }
        if (firstLoad || controller.statusError != null) {
          return hero;
        }
        final usage = summary.usage;
        final items = <Widget>[hero];
        if (activePeriod && usage != null) {
          items.addAll([
            const SizedBox(height: SelahSpacing.xl),
            Text(_usageTitle(summary), style: SelahTypography.headlineSmall()),
            const SizedBox(height: SelahSpacing.md),
            _UsageCardGrid(cards: _buildUsageCards(usage)),
          ]);
        }
        return _MembershipEntrance(children: items);
      },
    );
  }

  Widget _buildHeroContent(
    BuildContext context,
    MembershipSummary summary,
    bool activePeriod,
    Widget? trialNotice,
  ) {
    final periodLine = activePeriod ? _periodLine(summary) : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.workspace_premium_outlined,
              size: 19,
              color: SelahColors.coral,
            ),
            const SizedBox(width: SelahSpacing.sm),
            Expanded(
              child: Text(
                _currentPlanName(summary, uiLocale),
                style: SelahTypography.headlineLarge(),
              ),
            ),
            if (activePeriod)
              SelahTag(
                label: _membershipCopy(uiLocale, 'statusActive'),
                color: SelahColors.sage,
              )
            else if (summary.plan == MembershipPlan.trial &&
                summary.trialState == TrialState.expired)
              SelahTag(
                label: _membershipCopy(uiLocale, 'statusEnded'),
                color: SelahColors.textTertiary,
              ),
          ],
        ),
        if (activePeriod) ...[
          const SizedBox(height: SelahSpacing.xs),
          Wrap(
            spacing: SelahSpacing.md,
            runSpacing: SelahSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (summary.membershipSource != null)
                SelahTag(
                  label: _sourceName(summary.membershipSource!, uiLocale),
                  color: SelahColors.lavender,
                ),
              Text(
                _membershipCopy(uiLocale, 'noAutoRenew'),
                style: SelahTypography.bodySmall(
                  color: SelahColors.textSecondary,
                ),
              ),
            ],
          ),
          if (periodLine != null) ...[
            const SizedBox(height: SelahSpacing.xs),
            periodLine,
          ],
        ],
        if (!summary.membershipModeEnabled) ...[
          const SizedBox(height: SelahSpacing.md),
          _MembershipNotice(
            text: activePeriod
                ? _membershipCopy(uiLocale, 'modeOffNote')
                : _membershipCopy(uiLocale, 'modeOffFreeNote'),
            color: SelahColors.lavender,
          ),
        ],
        if (trialNotice != null) ...[
          const SizedBox(height: SelahSpacing.md),
          trialNotice,
        ],
        if (activePeriod && summary.usage == null) ...[
          const SizedBox(height: SelahSpacing.md),
          _MembershipNotice(
            text: _membershipCopy(uiLocale, 'usageUnavailable'),
            color: SelahColors.amber,
            action: TextButton(
              onPressed: controller.loading
                  ? null
                  : () => unawaited(controller.load()),
              child: Text(_membershipCopy(uiLocale, 'retry')),
            ),
          ),
        ],
        if (summary.futurePeriods.isNotEmpty) ...[
          const SizedBox(height: SelahSpacing.md),
          Text(
            _membershipCopy(uiLocale, 'nextPeriod', {
              'date': _formatMembershipDay(
                summary.futurePeriods.first.startsAt,
              ),
              'plan': _planName(summary.futurePeriods.first.plan, uiLocale),
            }),
            style: SelahTypography.bodySmall(color: SelahColors.textSecondary),
          ),
        ],
        if (summary.membershipModeEnabled) ...[
          const SizedBox(height: SelahSpacing.lg),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: () => _showPlanChangeSheet(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: SelahColors.textPrimary,
                side: const BorderSide(color: SelahColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(_membershipCopy(uiLocale, 'changePlan')),
            ),
          ),
        ],
      ],
    );
  }

  Widget? _periodLine(MembershipSummary summary) {
    final endsAt = summary.periodEndsAt;
    if (endsAt == null) return null;
    final start = summary.periodStartsAt;
    if (start == null) {
      return Text(
        _membershipCopy(uiLocale, 'expiresAt', {
          'date': _formatMembershipDay(endsAt),
        }),
        style: SelahTypography.bodySmall(color: SelahColors.textSecondary),
      );
    }
    final daysLeft = endsAt.difference(DateTime.now()).inDays;
    final range = <String, String>{
      'start': _formatMembershipDay(start),
      'end': _formatMembershipDay(endsAt),
    };
    if (daysLeft <= 0) {
      return Text(
        _membershipCopy(uiLocale, 'periodRangeEnded', range),
        style: SelahTypography.bodySmall(color: SelahColors.textSecondary),
      );
    }
    final ending = daysLeft <= 3;
    return Text(
      _membershipCopy(uiLocale, ending ? 'periodRangeEnding' : 'periodRange', {
        ...range,
        'days': '$daysLeft',
      }),
      style: SelahTypography.bodySmall(
        color: ending ? SelahColors.amber : SelahColors.textSecondary,
      ),
    );
  }

  String _usageTitle(MembershipSummary summary) {
    final start = summary.periodStartsAt;
    final end = summary.periodEndsAt;
    if (start != null && end != null) {
      return _membershipCopy(uiLocale, 'usageTitle', {
        'start': _formatMembershipDay(start),
        'end': _formatMembershipDay(end),
      });
    }
    return _membershipCopy(uiLocale, 'usageTitlePlain');
  }

  List<Widget> _buildUsageCards(MembershipUsage usage) {
    return [
      _usageCard(
        icon: Icons.edit_note_rounded,
        color: SelahColors.coral,
        softColor: SelahColors.coralSoft,
        titleKey: 'sentences',
        helpKey: 'sentencesHelp',
        usage: usage.sentences,
        unit: QuotaUnit.sentences,
      ),
      _usageCard(
        icon: Icons.graphic_eq_rounded,
        color: SelahColors.lavender,
        softColor: SelahColors.lavenderSoft,
        titleKey: 'ttsCharacters',
        helpKey: 'ttsCharactersHelp',
        usage: usage.ttsCharacters,
        unit: QuotaUnit.characters,
      ),
      _usageCard(
        icon: Icons.mic_rounded,
        color: SelahColors.sky,
        softColor: SelahColors.skySoft,
        titleKey: 'transcription',
        helpKey: 'transcriptionHelp',
        usage: usage.transcriptionMs,
        unit: QuotaUnit.transcriptionMs,
      ),
      _usageCard(
        icon: Icons.auto_awesome_rounded,
        color: SelahColors.sage,
        softColor: SelahColors.sageSoft,
        titleKey: 'preparations',
        helpKey: 'preparationsHelp',
        usage: usage.preparations,
        unit: QuotaUnit.preparations,
      ),
    ];
  }

  _UsageCard _usageCard({
    required IconData icon,
    required Color color,
    required Color softColor,
    required String titleKey,
    required String helpKey,
    required MembershipFeatureUsage usage,
    required QuotaUnit unit,
  }) {
    final title = _membershipCopy(uiLocale, titleKey);
    return _UsageCard(
      icon: icon,
      color: color,
      softColor: softColor,
      title: title,
      helpCopy: _membershipCopy(uiLocale, helpKey),
      helpLabel: _membershipCopy(uiLocale, 'quotaHelpLabel', {
        'feature': title,
      }),
      usedLabel: _membershipCopy(uiLocale, 'usedLabel', {
        'value':
            '${formatQuotaAmount(usage.used, unit)} / '
            '${formatQuotaValue(usage.limit, unit, uiLocale)}',
      }),
      remainingLabel: _membershipCopy(uiLocale, 'remainingLabel', {
        'value': formatQuotaValue(usage.remaining, unit, uiLocale),
      }),
      exhaustedLabel: _membershipCopy(uiLocale, 'exhausted'),
      noNewQuotaLabel: _membershipCopy(uiLocale, 'noNewQuota'),
      closeLabel: _membershipCopy(uiLocale, 'close'),
      usage: usage,
      unit: unit,
    );
  }

  void _showPlanChangeSheet(BuildContext context) {
    showSelahSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MembershipPlanChangeSheet(
        controller: controller,
        uiLocale: uiLocale,
      ),
    );
  }
}

class _MembershipHeroShell extends StatelessWidget {
  const _MembershipHeroShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      margin: EdgeInsets.zero,
      color: dark ? SelahColors.darkCard : SelahColors.cardPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: dark ? SelahColors.darkBorder : SelahColors.border,
        ),
      ),
      child: Padding(padding: const EdgeInsets.all(17), child: child),
    );
  }
}

class _MembershipEntrance extends StatelessWidget {
  const _MembershipEntrance({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (!MotionScope.of(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < children.length; index++)
          _EntranceItem(
            delay: Duration(milliseconds: 40 * index),
            child: children[index],
          ),
      ],
    );
  }
}

class _EntranceItem extends StatefulWidget {
  const _EntranceItem({required this.delay, required this.child});

  final Duration delay;
  final Widget child;

  @override
  State<_EntranceItem> createState() => _EntranceItemState();
}

class _EntranceItemState extends State<_EntranceItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    final window = SelahMotion.standard + widget.delay;
    _controller = AnimationController(vsync: this, duration: window);
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Interval(
        widget.delay.inMicroseconds / window.inMicroseconds,
        1.0,
        curve: SelahMotion.standardCurve,
      ),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final value = _animation.value;
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - value)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

class _UsageCardGrid extends StatelessWidget {
  const _UsageCardGrid({required this.cards});

  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < cards.length; index++) ...[
                if (index > 0) const SizedBox(height: SelahSpacing.md),
                cards[index],
              ],
            ],
          );
        }
        final rows = <Widget>[];
        for (var index = 0; index < cards.length; index += 2) {
          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: cards[index]),
                if (index + 1 < cards.length) ...[
                  const SizedBox(width: SelahSpacing.md),
                  Expanded(child: cards[index + 1]),
                ],
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < rows.length; index++) ...[
              if (index > 0) const SizedBox(height: SelahSpacing.md),
              rows[index],
            ],
          ],
        );
      },
    );
  }
}

class _UsageCard extends StatelessWidget {
  const _UsageCard({
    required this.icon,
    required this.color,
    required this.softColor,
    required this.title,
    required this.helpCopy,
    required this.helpLabel,
    required this.usedLabel,
    required this.remainingLabel,
    required this.exhaustedLabel,
    required this.noNewQuotaLabel,
    required this.closeLabel,
    required this.usage,
    required this.unit,
  });

  final IconData icon;
  final Color color;
  final Color softColor;
  final String title;
  final String helpCopy;
  final String helpLabel;
  final String usedLabel;
  final String remainingLabel;
  final String exhaustedLabel;
  final String noNewQuotaLabel;
  final String closeLabel;
  final MembershipFeatureUsage usage;
  final QuotaUnit unit;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final exhausted = usage.limit > 0 && usage.remaining <= 0;
    final ratio = usage.limit > 0
        ? (usage.used / usage.limit).clamp(0.0, 1.0).toDouble()
        : 0.0;
    final fill = exhausted
        ? SelahColors.coral
        : ratio >= 0.8
        ? SelahColors.amber
        : SelahColors.sage;
    final amountStyle = SelahTypography.bodySmall(
      color: SelahColors.textSecondary,
    ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    final stateStyle = amountStyle.copyWith(
      color: exhausted ? SelahColors.textTertiary : SelahColors.textSecondary,
    );
    return Card(
      margin: EdgeInsets.zero,
      color: dark ? SelahColors.darkCard : SelahColors.cardPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SelahCornerRadius.md),
        side: BorderSide(
          color: dark ? SelahColors.darkBorder : SelahColors.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(SelahSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: dark ? color.withValues(alpha: 0.16) : softColor,
                    borderRadius: BorderRadius.circular(SelahCornerRadius.sm),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(title, style: SelahTypography.bodyMedium()),
                ),
                _QuotaHelpButton(
                  label: helpLabel,
                  title: title,
                  helpCopy: helpCopy,
                  closeLabel: closeLabel,
                ),
              ],
            ),
            if (usage.limit > 0) ...[
              const SizedBox(height: 10),
              _UsageProgressBar(
                barKey: ValueKey<String>('quota-bar-${unit.name}'),
                ratio: ratio,
                fill: fill,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: Text(usedLabel, style: amountStyle)),
                  const SizedBox(width: SelahSpacing.sm),
                  Text(
                    exhausted ? exhaustedLabel : remainingLabel,
                    textAlign: TextAlign.end,
                    style: stateStyle,
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 10),
              Text(
                noNewQuotaLabel,
                style: SelahTypography.bodySmall(
                  color: SelahColors.textTertiary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _UsageProgressBar extends StatelessWidget {
  const _UsageProgressBar({
    required this.barKey,
    required this.ratio,
    required this.fill,
  });

  final Key barKey;
  final double ratio;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final track = dark ? SelahColors.darkBorder : SelahColors.borderLight;
    Widget bar(double value) {
      return Container(
        height: 6,
        decoration: BoxDecoration(
          color: track,
          borderRadius: BorderRadius.circular(SelahCornerRadius.pill),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: value,
            child: Container(
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(SelahCornerRadius.pill),
              ),
            ),
          ),
        ),
      );
    }

    return Semantics(
      key: barKey,
      value: '${(ratio * 100).round()}%',
      child: !MotionScope.of(context)
          ? bar(ratio)
          : TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: ratio),
              duration: SelahMotion.standard,
              curve: SelahMotion.standardCurve,
              builder: (context, value, _) => bar(value),
            ),
    );
  }
}

class _QuotaHelpButton extends StatelessWidget {
  const _QuotaHelpButton({
    required this.label,
    required this.title,
    required this.helpCopy,
    required this.closeLabel,
  });

  final String label;
  final String title;
  final String helpCopy;
  final String closeLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: IconButton(
        onPressed: () => _showHelp(context),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(
          minWidth: SelahSpacing.minTouchTarget,
          minHeight: SelahSpacing.minTouchTarget,
        ),
        icon: const Icon(
          Icons.help_outline_rounded,
          size: 20,
          color: SelahColors.textTertiary,
        ),
      ),
    );
  }

  void _showHelp(BuildContext context) {
    showSelahDialog<void>(
      context: context,
      builder: (dialogContext) => _QuotaHelpDialog(
        title: title,
        body: helpCopy,
        closeLabel: closeLabel,
      ),
    );
  }
}

class _QuotaHelpDialog extends StatelessWidget {
  const _QuotaHelpDialog({
    required this.title,
    required this.body,
    required this.closeLabel,
  });

  final String title;
  final String body;
  final String closeLabel;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: _PopIn(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          padding: const EdgeInsets.all(SelahSpacing.xl),
          decoration: BoxDecoration(
            color: dark ? SelahColors.darkCard : SelahColors.cardPrimary,
            borderRadius: BorderRadius.circular(SelahCornerRadius.lg),
            border: Border.all(
              color: dark ? SelahColors.darkBorder : SelahColors.border,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: SelahTypography.headlineSmall()),
              const SizedBox(height: 10),
              Text(
                body,
                style: SelahTypography.bodyMedium(
                  color: SelahColors.textSecondary,
                ).copyWith(height: 1.6),
              ),
              const SizedBox(height: SelahSpacing.lg),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(closeLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PopIn extends StatelessWidget {
  const _PopIn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!MotionScope.of(context)) {
      return child;
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: SelahMotion.quick,
      curve: SelahMotion.bounceCurve,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0).toDouble(),
          child: Transform.scale(scale: 0.95 + 0.05 * value, child: child),
        );
      },
      child: child,
    );
  }
}

class _UsageRows extends StatelessWidget {
  const _UsageRows({
    required this.usage,
    required this.uiLocale,
    required this.title,
    required this.exhaustedLabel,
    this.preview = false,
  });

  final MembershipUsage usage;
  final String uiLocale;
  final String title;
  final String exhaustedLabel;
  final bool preview;

  @override
  Widget build(BuildContext context) {
    final rows = [
      (
        _membershipCopy(uiLocale, 'sentences'),
        usage.sentences,
        QuotaUnit.sentences,
      ),
      (
        _membershipCopy(uiLocale, 'ttsCharacters'),
        usage.ttsCharacters,
        QuotaUnit.characters,
      ),
      (
        _membershipCopy(uiLocale, 'transcription'),
        usage.transcriptionMs,
        QuotaUnit.transcriptionMs,
      ),
      (
        _membershipCopy(uiLocale, 'preparations'),
        usage.preparations,
        QuotaUnit.preparations,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: SelahTypography.headlineSmall()),
        const SizedBox(height: SelahSpacing.xs),
        for (var index = 0; index < rows.length; index++) ...[
          if (index > 0)
            const Divider(height: 17, color: SelahColors.borderLight),
          Row(
            children: [
              Expanded(
                child: Text(
                  rows[index].$1,
                  style: SelahTypography.bodyMedium(
                    color: SelahColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: SelahSpacing.md),
              Text(
                rows[index].$2.remaining == 0
                    ? preview
                          ? _membershipCopy(uiLocale, 'noNewQuota')
                          : exhaustedLabel
                    : formatQuotaValue(
                        rows[index].$2.remaining,
                        rows[index].$3,
                        uiLocale,
                      ),
                textAlign: TextAlign.end,
                style: SelahTypography.bodyMedium().copyWith(
                  color: rows[index].$2.remaining == 0
                      ? SelahColors.textTertiary
                      : null,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _MembershipPlanChangeSheet extends StatefulWidget {
  const _MembershipPlanChangeSheet({
    required this.controller,
    required this.uiLocale,
  });

  final MembershipController controller;
  final String uiLocale;

  @override
  State<_MembershipPlanChangeSheet> createState() =>
      _MembershipPlanChangeSheetState();
}

class _MembershipPlanChangeSheetState
    extends State<_MembershipPlanChangeSheet> {
  MembershipController get controller => widget.controller;
  String get uiLocale => widget.uiLocale;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(controller.loadPlanPreview());
    });
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;
    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 560, maxHeight: maxHeight),
          child: Material(
            color: SelahColors.cardPrimary,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            clipBehavior: Clip.antiAlias,
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                final summary = controller.summary;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _membershipCopy(uiLocale, 'changePlan'),
                                  style: SelahTypography.headlineLarge(),
                                ),
                                const SizedBox(height: SelahSpacing.xs),
                                Text(
                                  _membershipCopy(uiLocale, 'currentPlan', {
                                    'plan': _currentPlanName(summary, uiLocale),
                                  }),
                                  style: SelahTypography.bodySmall(
                                    color: SelahColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            tooltip: _membershipCopy(uiLocale, 'close'),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: SelahColors.borderLight),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(SelahSpacing.lg),
                        child: _previewBody(),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _previewBody() {
    if (controller.planPreviewLoading) {
      return const SizedBox(
        height: 180,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (controller.planPreviewFailed) {
      return _MembershipNotice(
        text: _membershipCopy(uiLocale, 'previewError'),
        color: SelahColors.amber,
        action: TextButton(
          onPressed: () => unawaited(controller.loadPlanPreview()),
          child: Text(_membershipCopy(uiLocale, 'retry')),
        ),
      );
    }
    if (controller.planQuotes.isEmpty) {
      return _MembershipNotice(
        text: _membershipCopy(uiLocale, 'noAvailableActions'),
        color: SelahColors.lavender,
      );
    }

    final futurePeriods = controller.planQuotes
        .map((quote) => quote.futurePeriods)
        .firstWhere((periods) => periods.isNotEmpty, orElse: () => const []);
    final hasUnchangedFuturePeriods = controller.planQuotes.any(
      (quote) => quote.warnings.contains('future_periods_unchanged'),
    );
    final hasTrialWarning = controller.planQuotes.any(
      (quote) => quote.warnings.contains('trial_remainder_dropped'),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final quote in controller.planQuotes) ...[
          _QuoteCard(quote: quote, controller: controller, uiLocale: uiLocale),
          const SizedBox(height: SelahSpacing.md),
        ],
        if (hasTrialWarning)
          _MembershipNotice(
            text: _membershipCopy(uiLocale, 'trialRemainderDropped'),
            color: SelahColors.lavender,
          ),
        if (futurePeriods.isNotEmpty) ...[
          if (hasTrialWarning) const SizedBox(height: SelahSpacing.md),
          Text(
            _membershipCopy(uiLocale, 'futurePeriods'),
            style: SelahTypography.headlineSmall(),
          ),
          const SizedBox(height: SelahSpacing.xs),
          for (final period in futurePeriods)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: SelahSpacing.xs),
              child: Text(
                '${_planName(period.plan, uiLocale)} · '
                '${_sourceName(period.source, uiLocale)} · '
                '${_formatMembershipDate(period.startsAt, uiLocale)}—'
                '${_formatMembershipDate(period.endsAt, uiLocale)}',
                style: SelahTypography.bodySmall(
                  color: SelahColors.textSecondary,
                ),
              ),
            ),
        ],
        if (hasUnchangedFuturePeriods) ...[
          const SizedBox(height: SelahSpacing.sm),
          Text(
            _membershipCopy(uiLocale, 'futureUnchanged'),
            style: SelahTypography.bodySmall(color: SelahColors.textSecondary),
          ),
        ],
        if (controller.checkoutStatus != null) ...[
          const SizedBox(height: SelahSpacing.md),
          _MembershipNotice(
            text: controller.checkoutStatus!,
            color: SelahColors.sage,
          ),
        ],
        if (controller.error != null) ...[
          const SizedBox(height: SelahSpacing.md),
          _MembershipNotice(text: controller.error!, color: SelahColors.amber),
        ],
      ],
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({
    required this.quote,
    required this.controller,
    required this.uiLocale,
  });

  final MembershipPlanQuote quote;
  final MembershipController controller;
  final String uiLocale;

  @override
  Widget build(BuildContext context) {
    final label = _actionLabel(quote.action, uiLocale);
    final monthlyAction =
        quote.action == 'buy_monthly' || quote.action == 'extend_monthly';
    final canBuyMonthly =
        monthlyAction &&
        quote.unavailableReason == null &&
        controller.membershipSalesAvailable &&
        quote.chargeFenCny != null &&
        quote.effectiveAt != null &&
        !controller.checkoutLoading;
    final reason = _unavailableReason(quote, controller, uiLocale);
    final validPreview =
        quote.chargeFenCny != null && quote.effectiveAt != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SelahSpacing.md),
      decoration: BoxDecoration(
        color: SelahColors.cardPrimary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SelahColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: SelahTypography.headlineMedium()),
          const SizedBox(height: SelahSpacing.xs),
          if (quote.chargeFenCny != null)
            Text(
              '${_membershipCopy(uiLocale, 'amountDue')}  '
              '${_formatCny(quote.chargeFenCny!)}',
              style: SelahTypography.headlineLarge(color: SelahColors.coral),
            ),
          if (quote.effectiveAt != null) ...[
            const SizedBox(height: SelahSpacing.xs),
            Text(
              _membershipCopy(uiLocale, 'effectiveAt', {
                'date': _formatMembershipDate(quote.effectiveAt!, uiLocale),
              }),
              style: SelahTypography.bodySmall(
                color: SelahColors.textSecondary,
              ),
            ),
          ],
          if (quote.usageAfter != null) ...[
            const SizedBox(height: SelahSpacing.md),
            _UsageRows(
              usage: quote.usageAfter!,
              uiLocale: uiLocale,
              title: _membershipCopy(
                uiLocale,
                quote.action == 'upgrade_pro_now'
                    ? 'postUpgradeRemaining'
                    : 'newPeriodQuota',
              ),
              exhaustedLabel: _membershipCopy(uiLocale, 'noNewQuota'),
              preview: true,
            ),
          ],
          if (quote.warnings.contains('feature_remaining_zero')) ...[
            const SizedBox(height: SelahSpacing.sm),
            Text(
              _membershipCopy(uiLocale, 'someQuotaUnchanged'),
              style: SelahTypography.bodySmall(
                color: SelahColors.textSecondary,
              ),
            ),
          ],
          if (reason != null) ...[
            const SizedBox(height: SelahSpacing.sm),
            Text(
              reason,
              style: SelahTypography.bodySmall(color: SelahColors.amber),
            ),
          ],
          const SizedBox(height: SelahSpacing.md),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: canBuyMonthly
                  ? () => unawaited(controller.startMonthlyCheckout())
                  : null,
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                controller.checkoutLoading && monthlyAction
                    ? _membershipCopy(uiLocale, 'processing')
                    : label,
              ),
            ),
          ),
          if (!validPreview)
            Padding(
              padding: const EdgeInsets.only(top: SelahSpacing.xs),
              child: Text(
                _membershipCopy(uiLocale, 'previewIncomplete'),
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

class _MembershipNotice extends StatelessWidget {
  const _MembershipNotice({
    required this.text,
    required this.color,
    this.action,
    this.title,
  });

  final String text;
  final Color color;
  final Widget? action;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SelahSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 19, color: color),
          const SizedBox(width: SelahSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(title!, style: SelahTypography.headlineSmall()),
                  const SizedBox(height: SelahSpacing.xs),
                ],
                Text(text, style: SelahTypography.bodySmall()),
                if (action != null) ...[
                  const SizedBox(height: SelahSpacing.xs),
                  action!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget? _trialNotice(TrialState state, String locale) => switch (state) {
  TrialState.notStarted => _MembershipNotice(
    text: _membershipCopy(locale, 'trialNotStartedBody'),
    color: SelahColors.lavender,
    title: _membershipCopy(locale, 'trialNotStartedTitle'),
  ),
  TrialState.preparing => _MembershipNotice(
    text: _membershipCopy(locale, 'trialPreparingBody'),
    color: SelahColors.lavender,
    title: _membershipCopy(locale, 'trialPreparingTitle'),
  ),
  TrialState.expired => _MembershipNotice(
    text: _membershipCopy(locale, 'trialExpiredBody'),
    color: SelahColors.amber,
    title: _membershipCopy(locale, 'trialExpiredTitle'),
  ),
  TrialState.unavailable => _MembershipNotice(
    text: _membershipCopy(locale, 'trialUnavailableBody'),
    color: SelahColors.amber,
    title: _membershipCopy(locale, 'trialUnavailableTitle'),
  ),
  TrialState.active => null,
};

Widget? _trialNoticeFor(MembershipSummary summary, String locale) {
  if (summary.plan == MembershipPlan.trial) {
    return _trialNotice(summary.trialState, locale);
  }
  if (summary.plan == MembershipPlan.free &&
      !summary.hasActiveEntitlements &&
      summary.membershipModeEnabled &&
      summary.trialSignupsEnabled &&
      summary.trialState == TrialState.notStarted) {
    return _trialNotice(TrialState.notStarted, locale);
  }
  return null;
}

String _planName(MembershipPlan plan, String locale) => switch (plan) {
  MembershipPlan.free => _membershipCopy(locale, 'notEnrolled'),
  MembershipPlan.trial => _membershipCopy(locale, 'trialTitle'),
  MembershipPlan.monthly => _membershipCopy(locale, 'monthlyTitle'),
  MembershipPlan.pro => _membershipCopy(locale, 'proTitle'),
};

String _currentPlanName(MembershipSummary summary, String locale) {
  if (summary.isPaidActive ||
      (summary.isTrialActive && summary.trialState == TrialState.active)) {
    return _planName(summary.plan, locale);
  }
  if (summary.plan == MembershipPlan.trial &&
      (summary.trialState == TrialState.preparing ||
          summary.trialState == TrialState.notStarted)) {
    return _membershipCopy(locale, 'trialTitle');
  }
  if (summary.plan == MembershipPlan.trial &&
      summary.trialState == TrialState.expired) {
    return _membershipCopy(locale, 'trialExpiredTitle');
  }
  return _membershipCopy(locale, 'notEnrolled');
}

String _sourceName(MembershipSource source, String locale) => switch (source) {
  MembershipSource.paid => _membershipCopy(locale, 'sourcePaid'),
  MembershipSource.grant => _membershipCopy(locale, 'sourceGrant'),
  MembershipSource.compensation => _membershipCopy(
    locale,
    'sourceCompensation',
  ),
  MembershipSource.systemTrial => _membershipCopy(locale, 'sourceTrial'),
};

String _actionLabel(String action, String locale) => switch (action) {
  'upgrade_pro_now' => _membershipCopy(locale, 'upgradePro'),
  'schedule_pro' => _membershipCopy(locale, 'schedulePro'),
  'buy_monthly' => _membershipCopy(locale, 'buyMonthly'),
  'buy_pro' => _membershipCopy(locale, 'buyPro'),
  'extend_monthly' => _membershipCopy(locale, 'extendMonthly'),
  'extend_pro' => _membershipCopy(locale, 'extendPro'),
  _ => _membershipCopy(locale, 'unavailableAction'),
};

String? _unavailableReason(
  MembershipPlanQuote quote,
  MembershipController controller,
  String locale,
) {
  final reason = quote.unavailableReason;
  if (reason == 'sales_disabled' ||
      (reason == null &&
          (quote.action == 'buy_monthly' || quote.action == 'extend_monthly') &&
          !controller.summary.membershipSalesEnabled)) {
    return _membershipCopy(locale, 'salesDisabled');
  }
  if (reason == 'payment_not_configured' ||
      (reason == null &&
          (quote.action == 'buy_monthly' || quote.action == 'extend_monthly') &&
          !controller.summary.paymentProviderConfigured)) {
    return _membershipCopy(locale, 'paymentUnavailable');
  }
  if (reason == 'pro_sales_disabled' ||
      (reason == null &&
          quote.action != 'buy_monthly' &&
          quote.action != 'extend_monthly')) {
    return _membershipCopy(locale, 'proUnavailable');
  }
  if (reason != null) return _membershipCopy(locale, 'previewIncomplete');
  return null;
}

String _formatCny(int fen) => '¥ ${(fen / 100).toStringAsFixed(2)}';

String _formatMembershipDay(DateTime date) {
  final local = date.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return [local.year.toString(), month, day].join('/');
}

String _formatMembershipDate(DateTime date, String locale) {
  final local = date.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  if (locale == 'ja') {
    return '${local.year}/$month/$day $hour:$minute';
  }
  return '${local.year}年$month月$day日 $hour:$minute';
}

String _membershipCopy(
  String locale,
  String key, [
  Map<String, String> arguments = const {},
]) {
  final language = locale == 'ja'
      ? 'ja'
      : locale == 'zh-Hant'
      ? 'zh-Hant'
      : 'zh-Hans';
  var result =
      _membershipCopies[language]![key] ??
      _membershipCopies['zh-Hans']![key] ??
      key;
  for (final entry in arguments.entries) {
    result = result.replaceAll('{${entry.key}}', entry.value);
  }
  return result;
}

const _membershipCopies = <String, Map<String, String>>{
  'zh-Hans': {
    'notEnrolled': '未开通',
    'trialTitle': '个人试用',
    'trialNotStartedTitle': '试用尚未开始',
    'trialPreparingTitle': '试用准备中',
    'trialExpiredTitle': '试用已结束',
    'trialUnavailableTitle': '试用状态暂不可用',
    'monthlyTitle': '月会员',
    'proTitle': 'Pro 会员',
    'sourcePaid': '付费',
    'sourceGrant': '赠送',
    'sourceCompensation': '补偿',
    'sourceTrial': '试用',
    'expiresAt': '有效至 {date}',
    'noAutoRenew': '到期后不会自动扣款',
    'statusActive': '有效',
    'statusEnded': '已结束',
    'usageTitle': '本期用量（{start} – {end}）',
    'usageTitlePlain': '本期用量',
    'periodRange': '本期 {start} – {end} · 还剩 {days} 天',
    'periodRangeEnding': '本期 {start} – {end} · 只剩 {days} 天',
    'periodRangeEnded': '本期 {start} – {end} · 已结束',
    'usedLabel': '已用 {value}',
    'remainingLabel': '剩 {value}',
    'sentencesHelp': '写下今天的母语句子，生成对应的英语学习内容；每成功生成一条，计一次。',
    'ttsCharactersHelp': '为英语和母语句子合成语音；按新增配音的字符数计。',
    'transcriptionHelp': '把「说出来」的录音转成文字；按录音时长计。',
    'preparationsHelp': '超过直接生成长度的长文，先自动分段整理再逐段生成；每整理一次计一次。',
    'quotaHelpLabel': '了解{feature}的计量方式',
    'sentences': '个人表达',
    'ttsCharacters': '新增 AI 配音',
    'transcription': '录音转写',
    'preparations': '长文整理',
    'exhausted': '本账期已用完',
    'noNewQuota': '本项本账期没有新增额度',
    'changePlan': '更改方案',
    'nextPeriod': '下期 {plan} · {date} 开始',
    'statusError': '会员状态暂时无法读取，请稍后重试。',
    'usageUnavailable': '额度信息暂时无法读取，请稍后重试。',
    'modeOffNote': '会员额度限制尚未对所有用户开启，当前不会按额度限制你的学习。',
    'modeOffFreeNote': '当前未开通会员，学习不受限制。',
    'previewError': '方案预览暂时无法读取，请稍后重试。',
    'retry': '重试',
    'close': '关闭',
    'currentPlan': '当前：{plan}',
    'noAvailableActions': '当前没有可更改的方案。',
    'upgradePro': '升级到 Pro',
    'schedulePro': '购买下一个 Pro 账期',
    'buyMonthly': '开通月会员',
    'buyPro': '开通 Pro',
    'extendMonthly': '再购买一个月会员',
    'extendPro': '再购买一个月 Pro',
    'unavailableAction': '暂不可用的方案',
    'amountDue': '应付金额',
    'effectiveAt': '生效时间：{date}',
    'postUpgradeRemaining': '升级后本账期剩余',
    'newPeriodQuota': '新账期额度',
    'someQuotaUnchanged': '部分项目本账期没有新增额度。',
    'previewIncomplete': '当前无法确认此方案，请稍后重试。',
    'salesDisabled': '会员购买暂未开放，请稍后再试。',
    'paymentUnavailable': '支付渠道尚未配置，暂未开放。',
    'proUnavailable': 'Pro 购买尚未开放。',
    'processing': '正在处理…',
    'trialRemainderDropped': '付款核实后付费账期立即开始，试用剩余额度不结转。',
    'futurePeriods': '已排期账期',
    'futureUnchanged': '其后已排期的账期保持原样。',
    'trialNotStartedBody': '7 天试用从第一条个人表达成功并由服务器保存后开始，不会因注册或登录提前计时。',
    'trialPreparingBody': '已为这次账户请求保留试用额度；首次个人表达成功保存后开始计时。',
    'trialExpiredBody': '已有内容仍可学习，开通月会员后可继续新增生成。',
    'trialUnavailableBody': '暂时无法确认权益，请稍后重试；不会把读取失败当作免费额度。',
  },
  'zh-Hant': {
    'notEnrolled': '未開通',
    'trialTitle': '個人試用',
    'trialNotStartedTitle': '試用尚未開始',
    'trialPreparingTitle': '試用準備中',
    'trialExpiredTitle': '試用已結束',
    'trialUnavailableTitle': '試用狀態暫不可用',
    'monthlyTitle': '月會員',
    'proTitle': 'Pro 會員',
    'sourcePaid': '付費',
    'sourceGrant': '贈送',
    'sourceCompensation': '補償',
    'sourceTrial': '試用',
    'expiresAt': '有效至 {date}',
    'noAutoRenew': '到期後不會自動扣款',
    'statusActive': '有效',
    'statusEnded': '已結束',
    'usageTitle': '本期用量（{start} – {end}）',
    'usageTitlePlain': '本期用量',
    'periodRange': '本期 {start} – {end} · 還剩 {days} 天',
    'periodRangeEnding': '本期 {start} – {end} · 只剩 {days} 天',
    'periodRangeEnded': '本期 {start} – {end} · 已結束',
    'usedLabel': '已用 {value}',
    'remainingLabel': '剩 {value}',
    'sentencesHelp': '寫下今天的母語句子，產生對應的英語學習內容；每成功產生一條，計一次。',
    'ttsCharactersHelp': '為英語和母語句子合成語音；按新增配音的字元數計。',
    'transcriptionHelp': '把「說出來」的錄音轉成文字；按錄音時長計。',
    'preparationsHelp': '超過直接產生長度的長文，先自動分段整理再逐段產生；每整理一次計一次。',
    'quotaHelpLabel': '瞭解{feature}的計量方式',
    'sentences': '個人表達',
    'ttsCharacters': '新增 AI 配音',
    'transcription': '錄音轉寫',
    'preparations': '長文整理',
    'exhausted': '本帳期已用完',
    'noNewQuota': '本項本帳期沒有新增額度',
    'changePlan': '更改方案',
    'nextPeriod': '下期 {plan} · {date} 開始',
    'statusError': '會員狀態暫時無法讀取，請稍後重試。',
    'usageUnavailable': '額度資訊暫時無法讀取，請稍後重試。',
    'modeOffNote': '會員額度限制尚未對所有使用者開啟，目前不會按額度限制你的學習。',
    'modeOffFreeNote': '目前未開通會員，學習不受限制。',
    'previewError': '方案預覽暫時無法讀取，請稍後重試。',
    'retry': '重試',
    'close': '關閉',
    'currentPlan': '目前：{plan}',
    'noAvailableActions': '目前沒有可更改的方案。',
    'upgradePro': '升級到 Pro',
    'schedulePro': '購買下一個 Pro 帳期',
    'buyMonthly': '開通月會員',
    'buyPro': '開通 Pro',
    'extendMonthly': '再購買一個月會員',
    'extendPro': '再購買一個月 Pro',
    'unavailableAction': '暫不可用的方案',
    'amountDue': '應付金額',
    'effectiveAt': '生效時間：{date}',
    'postUpgradeRemaining': '升級後本帳期剩餘',
    'newPeriodQuota': '新帳期額度',
    'someQuotaUnchanged': '部分項目本帳期沒有新增額度。',
    'previewIncomplete': '目前無法確認此方案，請稍後重試。',
    'salesDisabled': '會員購買暫未開放，請稍後再試。',
    'paymentUnavailable': '支付渠道尚未設定，暫未開放。',
    'proUnavailable': 'Pro 購買尚未開放。',
    'processing': '正在處理…',
    'trialRemainderDropped': '付款核實後付費帳期立即開始，試用剩餘額度不結轉。',
    'futurePeriods': '已排期帳期',
    'futureUnchanged': '其後已排期的帳期保持原樣。',
    'trialNotStartedBody': '7 天試用從第一條個人表達成功並由伺服器儲存後開始，不會因註冊或登入提前計時。',
    'trialPreparingBody': '已為這次帳戶請求保留試用額度；首次個人表達成功儲存後開始計時。',
    'trialExpiredBody': '已有內容仍可學習，開通月會員後可繼續新增生成。',
    'trialUnavailableBody': '暫時無法確認權益，請稍後重試；不會把讀取失敗當作免費額度。',
  },
  'ja': {
    'notEnrolled': '未加入',
    'trialTitle': '個人トライアル',
    'trialNotStartedTitle': 'トライアルは未開始です',
    'trialPreparingTitle': 'トライアル準備中',
    'trialExpiredTitle': 'トライアル終了',
    'trialUnavailableTitle': 'トライアル状態を確認できません',
    'monthlyTitle': '月額メンバー',
    'proTitle': 'Pro メンバー',
    'sourcePaid': '購入',
    'sourceGrant': '付与',
    'sourceCompensation': '補償',
    'sourceTrial': 'トライアル',
    'expiresAt': '有効期限：{date}',
    'noAutoRenew': '期限後に自動請求されません',
    'statusActive': '有効',
    'statusEnded': '終了',
    'usageTitle': '今期の使用量（{start} – {end}）',
    'usageTitlePlain': '今期の使用量',
    'periodRange': '今期 {start} – {end} · 残り {days} 日',
    'periodRangeEnding': '今期 {start} – {end} · 残りわずか {days} 日',
    'periodRangeEnded': '今期 {start} – {end} · 終了',
    'usedLabel': '使用 {value}',
    'remainingLabel': '残り {value}',
    'sentencesHelp': '今日の母語の文を書くと、対応する英語学習コンテンツを生成します。生成 1 件ごとにカウントします。',
    'ttsCharactersHelp': '英語と母語の文の音声を合成します。新規音声の文字数でカウントします。',
    'transcriptionHelp': '話した録音を文字に起こします。録音時間でカウントします。',
    'preparationsHelp': '直接生成できる長さを超える長文は、先に分割して整理してから生成します。整理 1 回ごとにカウントします。',
    'quotaHelpLabel': '{feature}の計算方法を確認',
    'sentences': '個人表現',
    'ttsCharacters': 'AI音声',
    'transcription': '文字起こし',
    'preparations': '長文整理',
    'exhausted': '今期は使い切りました',
    'noNewQuota': '今期この項目の追加枠はありません',
    'changePlan': 'プランを変更',
    'nextPeriod': '次の期間：{plan} · {date} 開始',
    'statusError': 'メンバー状態を読み込めません。しばらくしてから再試行してください。',
    'usageUnavailable': '利用量の情報を読み込めません。しばらくしてからもう一度お試しください。',
    'modeOffNote': 'メンバーの枠制限はまだ全ユーザーに有効になっていません。現在は枠の制限なく学習できます。',
    'modeOffFreeNote': 'メンバーは未加入です。学習は制限されません。',
    'previewError': 'プランを確認できません。しばらくしてから再試行してください。',
    'retry': '再試行',
    'close': '閉じる',
    'currentPlan': '現在：{plan}',
    'noAvailableActions': '現在変更できるプランはありません。',
    'upgradePro': 'Pro にアップグレード',
    'schedulePro': '次期 Pro を購入',
    'buyMonthly': '月額メンバーに加入',
    'buyPro': 'Pro に加入',
    'extendMonthly': '月額メンバーをもう1か月購入',
    'extendPro': 'Pro をもう1か月購入',
    'unavailableAction': '利用できないプラン',
    'amountDue': 'お支払い額',
    'effectiveAt': '適用日時：{date}',
    'postUpgradeRemaining': 'アップグレード後の今期残り',
    'newPeriodQuota': '新しい期間の枠',
    'someQuotaUnchanged': '今期、一部の項目に追加枠はありません。',
    'previewIncomplete': 'このプランを確認できません。後でもう一度お試しください。',
    'salesDisabled': 'メンバー購入は現在利用できません。後でもう一度お試しください。',
    'paymentUnavailable': '決済チャネルはまだ設定されていません。',
    'proUnavailable': 'Pro の購入はまだ利用できません。',
    'processing': '処理中…',
    'trialRemainderDropped': '支払い確認後に有料期間が始まり、トライアルの残り枠は引き継がれません。',
    'futurePeriods': '予定済みの期間',
    'futureUnchanged': 'その後に予定された期間は変更されません。',
    'trialNotStartedBody':
        '7日間のトライアルは、最初の個人表現が成功してサーバーに保存された時点から始まります。登録やログインでは始まりません。',
    'trialPreparingBody': 'このアカウントのトライアル枠を確保しました。最初の個人表現が保存された時点から計測します。',
    'trialExpiredBody': '保存済みの内容は学習できます。月額メンバーに加入すると新しい生成を続けられます。',
    'trialUnavailableBody': '権益を確認できませんでした。後でもう一度お試しください。読み込み失敗を無料枠として扱いません。',
  },
};
