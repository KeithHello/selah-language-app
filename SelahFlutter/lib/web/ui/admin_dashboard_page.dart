import 'package:flutter/material.dart';

import '../../design/selah_colors.dart';
import '../../design/selah_spacing.dart';
import '../../design/selah_typography.dart';
import '../admin/admin_controller.dart';
import '../domain/admin_dashboard.dart';
import '../domain/learning_models.dart';
import '../l10n/selah_strings.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({
    required this.controller,
    this.uiLocale = defaultUiLocale,
    super.key,
  });
  final AdminController controller;
  final String uiLocale;
  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  @override
  void initState() {
    super.initState();
    if (!widget.controller.checked) {
      WidgetsBinding.instance.addPostFrameCallback((_) => load());
    }
  }

  Future<void> load() => widget.controller.load();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        final s = SelahStrings.of(widget.uiLocale);
        if (controller.loading && !controller.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.error != null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline),
                const SizedBox(height: SelahSpacing.lg),
                Text(controller.error!),
                const SizedBox(height: SelahSpacing.xl),
                OutlinedButton(
                  onPressed: load,
                  child: Text(s.text('admin.retry')),
                ),
              ],
            ),
          );
        }
        final dashboard = controller.data;
        if (dashboard == null) return const SizedBox.shrink();
        final summary = dashboard.summary;
        final api = summary.api;
        String money(num value) =>
            value == 0 ? '—' : 'USD ${value.toStringAsFixed(2)}';
        final metrics = [
          (s.text('admin.activeLearners'), '${summary.activeLearners}', ''),
          (s.text('admin.learningSessions'), '${summary.learningSessions}', ''),
          (
            s.text('admin.effectiveDuration'),
            _durationLabel(summary.effectiveLearningMinutes, s),
            s.text('admin.estimated'),
          ),
          (
            s.text('admin.estimatedCost'),
            money(api.knownEstimatedCostUsd),
            s.text('admin.doNotAdd'),
          ),
          (
            s.text('admin.providerCost'),
            money(api.providerRecordedCostUsd),
            s.text('admin.billingCheck'),
          ),
          (
            s.text('admin.unknownUsage'),
            s.message('admin.count', {'count': '${api.unknownUsageAttempts}'}),
            '',
          ),
        ];
        return ListView(
          padding: const EdgeInsets.all(SelahSpacing.page),
          children: [
            Text(s.text('admin.title'), style: SelahTypography.displayMedium()),
            const SizedBox(height: SelahSpacing.sm),
            Wrap(
              spacing: SelahSpacing.sm,
              children: DateTimeRangePreset.values.map((preset) {
                return ChoiceChip(
                  label: Text(_rangeLabel(preset, s)),
                  selected: controller.rangePreset == preset,
                  onSelected: (_) => controller.setRange(preset),
                );
              }).toList(),
            ),
            const SizedBox(height: SelahSpacing.lg),
            LayoutBuilder(
              builder: (context, constraints) {
                return GridView.count(
                  crossAxisCount: constraints.maxWidth < 700 ? 2 : 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 2.4,
                  crossAxisSpacing: SelahSpacing.lg,
                  mainAxisSpacing: SelahSpacing.lg,
                  children: metrics.map((item) {
                    return Container(
                      padding: const EdgeInsets.all(SelahSpacing.lg),
                      decoration: BoxDecoration(
                        color: SelahColors.cardPrimary,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: SelahColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            item.$1,
                            style: SelahTypography.bodyMedium(
                              color: SelahColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: SelahSpacing.sm),
                          Text(item.$2, style: SelahTypography.displayMedium()),
                          if (item.$3.isNotEmpty)
                            Text(item.$3, style: SelahTypography.bodySmall()),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: SelahSpacing.xl),
            _Card(
              title: s.text('admin.dailyActivity'),
              child: _DailyList(
                items: summary.dailyActivity,
                uiLocale: widget.uiLocale,
              ),
            ),
            const SizedBox(height: SelahSpacing.lg),
            _Card(
              title: s.text('admin.costDistribution'),
              child: _CostList(items: api.byFeature, uiLocale: widget.uiLocale),
            ),
            const SizedBox(height: SelahSpacing.lg),
            _Card(
              title: s.text('admin.featureUsage'),
              child: _FeatureList(
                items: summary.featureUsage,
                uiLocale: widget.uiLocale,
              ),
            ),
            const SizedBox(height: SelahSpacing.lg),
            _Card(
              title: s.text('admin.recentAttempts'),
              child: _AttemptList(
                items: dashboard.attempts,
                uiLocale: widget.uiLocale,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(SelahSpacing.lg),
      decoration: BoxDecoration(
        color: SelahColors.cardPrimary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SelahColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: SelahTypography.headlineLarge()),
          const SizedBox(height: SelahSpacing.lg),
          child,
        ],
      ),
    );
  }
}

class _DailyList extends StatelessWidget {
  const _DailyList({required this.items, required this.uiLocale});
  final List<AdminDailyActivity> items;
  final String uiLocale;
  @override
  Widget build(BuildContext context) {
    final s = SelahStrings.of(uiLocale);
    if (items.isEmpty) return Text(s.text('admin.noRecords'));
    return Column(
      children: items.map((e) {
        return Row(
          children: [
            Expanded(
              child: Text(
                e.date?.toIso8601String().substring(5, 10) ??
                    s.text('admin.date'),
              ),
            ),
            Text(
              s.message('admin.peopleMinutes', {
                'people': '${e.activeLearners}',
                'minutes': '${e.effectiveLearningMinutes.round()}',
              }),
            ),
          ],
        );
      }).toList(),
    );
  }
}

class _CostList extends StatelessWidget {
  const _CostList({required this.items, required this.uiLocale});
  final List<AdminFeatureCost> items;
  final String uiLocale;
  @override
  Widget build(BuildContext context) {
    final s = SelahStrings.of(uiLocale);
    if (items.isEmpty) return Text(s.text('admin.noRecords'));
    return Column(
      children: items.map((e) {
        return Row(
          children: [
            Expanded(child: Text(s.translateLegacy(e.featureLabelText))),
            Text(
              s.message('admin.attemptsCost', {
                'count': '${e.attempts}',
                'cost': e.estimatedCostUsd.toStringAsFixed(2),
              }),
            ),
          ],
        );
      }).toList(),
    );
  }
}

class _FeatureList extends StatelessWidget {
  const _FeatureList({required this.items, required this.uiLocale});
  final List<AdminFeatureCount> items;
  final String uiLocale;
  @override
  Widget build(BuildContext context) {
    final s = SelahStrings.of(uiLocale);
    if (items.isEmpty) return Text(s.text('admin.noRecords'));
    return Column(
      children: items.map((e) {
        return Row(
          children: [
            Expanded(child: Text(s.translateLegacy(e.label))),
            Text(s.message('admin.count', {'count': '${e.count}'})),
          ],
        );
      }).toList(),
    );
  }
}

class _AttemptList extends StatelessWidget {
  const _AttemptList({required this.items, required this.uiLocale});
  final List<AdminAttempt> items;
  final String uiLocale;
  @override
  Widget build(BuildContext context) {
    final s = SelahStrings.of(uiLocale);
    if (items.isEmpty) return Text(s.text('admin.noRecords'));
    return Column(
      children: items.take(8).map((e) {
        return Row(
          children: [
            Expanded(
              child: Text(
                '${s.translateLegacy(e.featureLabelTextValue)} · ${s.translateLegacy(e.statusLabel)}',
              ),
            ),
            Text(
              e.estimatedCostUsd == null
                  ? s.text('admin.unknownCost')
                  : 'USD ${e.estimatedCostUsd!.toStringAsFixed(2)}',
            ),
          ],
        );
      }).toList(),
    );
  }
}

String _rangeLabel(DateTimeRangePreset preset, SelahStrings strings) =>
    switch (preset) {
      DateTimeRangePreset.today => strings.text('admin.today'),
      DateTimeRangePreset.last7Days => strings.text('admin.last7Days'),
      DateTimeRangePreset.last30Days => strings.text('admin.last30Days'),
    };

String _durationLabel(num minutes, SelahStrings strings) {
  final total = minutes.round();
  final hours = total ~/ 60;
  final remainder = total % 60;
  if (strings.locale == 'ja') {
    if (hours == 0) return '$remainder分';
    if (remainder == 0) return '$hours時間';
    return '$hours時間 $remainder分';
  }
  if (hours == 0) {
    return strings.locale == 'zh-Hant' ? '$remainder 分鐘' : '$remainder 分钟';
  }
  if (remainder == 0) {
    return strings.locale == 'zh-Hant' ? '$hours 小時' : '$hours 小时';
  }
  return strings.locale == 'zh-Hant'
      ? '$hours 小時 $remainder 分'
      : '$hours 小时 $remainder 分';
}
