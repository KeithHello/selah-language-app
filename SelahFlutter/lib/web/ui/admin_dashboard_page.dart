import 'package:flutter/material.dart';

import '../../design/selah_colors.dart';
import '../../design/selah_spacing.dart';
import '../../design/selah_typography.dart';
import '../admin/admin_controller.dart';
import '../domain/admin_audience.dart';
import '../domain/admin_dashboard.dart';
import '../domain/admin_membership.dart';
import '../domain/learning_models.dart';
import '../l10n/selah_strings.dart';
import 'admin_user_detail.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({
    required this.controller,
    this.uiLocale = defaultUiLocale,
    this.onBack,
    this.onLogin,
    super.key,
  });
  final AdminController controller;
  final String uiLocale;
  final VoidCallback? onBack;
  final VoidCallback? onLogin;
  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: widget.controller.userSearch,
    );
    if (!widget.controller.checked) {
      WidgetsBinding.instance.addPostFrameCallback((_) => load());
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
                if (widget.onLogin != null) ...[
                  const SizedBox(height: SelahSpacing.md),
                  OutlinedButton(
                    onPressed: widget.onLogin,
                    child: Text(s.translateLegacy('登录／注册')),
                  ),
                ],
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
            Row(
              children: [
                if (widget.onBack != null)
                  Padding(
                    padding: const EdgeInsets.only(right: SelahSpacing.sm),
                    child: IconButton(
                      tooltip: '返回设置',
                      onPressed: widget.onBack,
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  ),
                Expanded(
                  child: Text(
                    s.text('admin.title'),
                    style: SelahTypography.displayMedium(),
                  ),
                ),
              ],
            ),
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
            _ServiceControlsCard(
              controller: controller,
              uiLocale: widget.uiLocale,
            ),
            const SizedBox(height: SelahSpacing.lg),
            _UsersCard(
              controller: controller,
              uiLocale: widget.uiLocale,
              searchController: _searchController,
              onOpenUser: (user) async {
                final changed = await showDialog<bool>(
                  context: context,
                  builder: (_) => AdminUserDetailDialog(
                    gateway: controller.gateway,
                    user: user,
                  ),
                );
                if (changed == true) {
                  await controller.loadUsers(search: controller.userSearch);
                }
              },
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
            _AudienceCard(controller: controller, uiLocale: widget.uiLocale),
            const SizedBox(height: SelahSpacing.lg),
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

class _AudienceCard extends StatelessWidget {
  const _AudienceCard({required this.controller, required this.uiLocale});

  final AdminController controller;
  final String uiLocale;

  @override
  Widget build(BuildContext context) {
    String copy(String key) => _adminCopy(uiLocale, key);
    final data = controller.audience;
    return _Card(
      title: copy('audienceTitle'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButton<AdminAudienceDimension>(
                  isExpanded: true,
                  value:
                      controller.audienceDimension ==
                          AdminAudienceDimension.unknown
                      ? AdminAudienceDimension.learningGoal
                      : controller.audienceDimension,
                  items: AdminAudienceDimension.values
                      .where((item) => item != AdminAudienceDimension.unknown)
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(_audienceDimensionLabel(uiLocale, item)),
                        ),
                      )
                      .toList(),
                  onChanged: controller.audienceLoading
                      ? null
                      : (value) {
                          if (value != null) {
                            controller.loadAudience(dimension: value);
                          }
                        },
                ),
              ),
              const SizedBox(width: SelahSpacing.sm),
              OutlinedButton(
                onPressed: controller.audienceLoading
                    ? null
                    : () => controller.loadAudience(),
                child: Text(copy('audienceLoad')),
              ),
            ],
          ),
          if (controller.audienceLoading)
            const Padding(
              padding: EdgeInsets.only(top: SelahSpacing.sm),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if (controller.audienceError != null)
            Padding(
              padding: const EdgeInsets.only(top: SelahSpacing.sm),
              child: Text(
                controller.audienceError!,
                style: SelahTypography.bodySmall(color: SelahColors.danger),
              ),
            ),
          if (data == null &&
              controller.audienceError == null &&
              !controller.audienceLoading)
            Padding(
              padding: const EdgeInsets.only(top: SelahSpacing.sm),
              child: Text(copy('audienceHint')),
            ),
          if (data != null) ...[
            const SizedBox(height: SelahSpacing.md),
            Text(
              '${copy('audienceRegistered')} ${data.registeredCount} · '
              '${copy('audienceCovered')} ${data.profileCoveredCount} · '
              '${copy('audienceUnanswered')} ${data.unansweredCount} · '
              '${copy('audienceRefusal')} ${data.refusalCount} · '
              '${copy('audienceWithdrawn')} ${data.withdrawnCount}',
              style: SelahTypography.bodySmall(
                color: SelahColors.textSecondary,
              ),
            ),
            const SizedBox(height: SelahSpacing.sm),
            ...data.groups.map(
              (group) => _AudienceGroupRow(
                group: group,
                insufficientText: copy('audienceInsufficient'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AudienceGroupRow extends StatelessWidget {
  const _AudienceGroupRow({
    required this.group,
    required this.insufficientText,
  });

  final AdminAudienceGroup group;
  final String insufficientText;

  @override
  Widget build(BuildContext context) {
    final label = group.label.isEmpty ? group.value : group.label;
    final suppressed = group.suppressed || group.sampleSize < 5;
    final detail = suppressed
        ? '$insufficientText（${group.sampleSize}）'
        : '${_ratio(group.day7RetentionNumerator, group.day7RetentionDenominator)} · '
              '${_ratio(group.firstPurchase30dNumerator, group.firstPurchase30dDenominator)}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(detail, style: SelahTypography.bodySmall()),
        ],
      ),
    );
  }
}

String _ratio(int numerator, int denominator) =>
    denominator <= 0 ? '—' : '$numerator/$denominator';

String _audienceDimensionLabel(
  String locale,
  AdminAudienceDimension dimension,
) {
  final labels = locale == 'ja'
      ? const {
          AdminAudienceDimension.learningGoal: '学習目的',
          AdminAudienceDimension.englishLevel: '英語レベル',
          AdminAudienceDimension.ageGroup: '年齢層',
          AdminAudienceDimension.lifeStage: '立場',
          AdminAudienceDimension.gender: '性別',
        }
      : locale == 'zh-Hant'
      ? const {
          AdminAudienceDimension.learningGoal: '學習目標',
          AdminAudienceDimension.englishLevel: '英語程度',
          AdminAudienceDimension.ageGroup: '年齡段',
          AdminAudienceDimension.lifeStage: '身分',
          AdminAudienceDimension.gender: '性別',
        }
      : const {
          AdminAudienceDimension.learningGoal: '学习目标',
          AdminAudienceDimension.englishLevel: '英语自评',
          AdminAudienceDimension.ageGroup: '年龄段',
          AdminAudienceDimension.lifeStage: '身份',
          AdminAudienceDimension.gender: '性别',
        };
  return labels[dimension] ?? '';
}

class _ServiceControlsCard extends StatelessWidget {
  const _ServiceControlsCard({
    required this.controller,
    required this.uiLocale,
  });

  final AdminController controller;
  final String uiLocale;

  Future<void> _toggle(
    BuildContext context, {
    required String key,
    required bool value,
  }) async {
    String copy(String name) => _adminCopy(uiLocale, name);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(copy('confirmTitle')),
        content: Text(
          value ? copy('${key}OnConfirm') : copy('${key}OffConfirm'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(copy('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(copy('confirm')),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final success = await controller.updateControls(
      membershipEnforcementEnabled: key == 'membership' ? value : null,
      trialSignupsEnabled: key == 'trial' ? value : null,
      membershipSalesEnabled: key == 'sales' ? value : null,
      generationEnabled: key == 'generation' ? value : null,
      reason: 'dashboard_${key}_toggle',
    );
    if (!context.mounted || success) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(controller.controlsError ?? copy('updateFailed'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    String copy(String name) => _adminCopy(uiLocale, name);
    final controls = controller.controls;
    final membershipModeEnabled = controls.membershipEnforcementEnabled;
    return _Card(
      title: copy('controlsTitle'),
      child: Column(
        children: [
          _ControlSwitch(
            title: copy('membershipSwitch'),
            subtitle: copy('membershipSwitchDetail'),
            value: controls.membershipEnforcementEnabled,
            enabled: !controller.controlsLoading,
            onChanged: (value) =>
                _toggle(context, key: 'membership', value: value),
          ),
          _ControlSwitch(
            title: copy('trialSwitch'),
            subtitle: copy('trialSwitchDetail'),
            value: controls.trialSignupsEnabled,
            enabled: !controller.controlsLoading && membershipModeEnabled,
            onChanged: (value) => _toggle(context, key: 'trial', value: value),
          ),
          _ControlSwitch(
            title: copy('salesSwitch'),
            subtitle: copy('salesSwitchDetail'),
            value: controls.membershipSalesEnabled,
            enabled: !controller.controlsLoading && membershipModeEnabled,
            onChanged: (value) => _toggle(context, key: 'sales', value: value),
          ),
          _ControlSwitch(
            title: copy('generationSwitch'),
            subtitle: copy('generationSwitchDetail'),
            value: controls.generationEnabled,
            enabled: !controller.controlsLoading,
            onChanged: (value) =>
                _toggle(context, key: 'generation', value: value),
          ),
          if (controller.controlsError != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  controller.controlsError!,
                  style: SelahTypography.bodySmall(color: SelahColors.danger),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              controls.configured
                  ? '${copy('version')} ${controls.version}'
                  : copy('notConfigured'),
              style: SelahTypography.bodySmall(color: SelahColors.textTertiary),
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlSwitch extends StatelessWidget {
  const _ControlSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile.adaptive(
    contentPadding: EdgeInsets.zero,
    title: Text(title),
    subtitle: Text(subtitle),
    value: value,
    onChanged: enabled ? onChanged : null,
  );
}

class _UsersCard extends StatelessWidget {
  const _UsersCard({
    required this.controller,
    required this.uiLocale,
    required this.searchController,
    required this.onOpenUser,
  });

  final AdminController controller;
  final String uiLocale;
  final TextEditingController searchController;
  final Future<void> Function(AdminUserItem user) onOpenUser;

  @override
  Widget build(BuildContext context) {
    String copy(String name) => _adminCopy(uiLocale, name);
    return _Card(
      title: copy('usersTitle'),
      child: Column(
        children: [
          TextField(
            controller: searchController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: copy('usersSearchHint'),
              suffixIcon: IconButton(
                tooltip: copy('search'),
                onPressed: controller.usersLoading
                    ? null
                    : () => controller.loadUsers(
                        search: searchController.text.trim(),
                      ),
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
            ),
            onSubmitted: (value) => controller.loadUsers(search: value.trim()),
          ),
          const SizedBox(height: SelahSpacing.md),
          if (controller.usersLoading)
            const LinearProgressIndicator(minHeight: 2),
          if (controller.usersError != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  controller.usersError!,
                  style: SelahTypography.bodySmall(color: SelahColors.danger),
                ),
              ),
            ),
          if (!controller.usersLoading &&
              controller.usersError == null &&
              controller.users.isEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(copy('usersEmpty')),
              ),
            ),
          ...controller.users.map(
            (user) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: SelahColors.coralSoft,
                child: Text(
                  user.emailMasked.isEmpty
                      ? '?'
                      : user.emailMasked[0].toUpperCase(),
                  style: SelahTypography.labelLarge(color: SelahColors.coral),
                ),
              ),
              title: Text(user.emailMasked),
              subtitle: Text(
                '${user.plan} · ${user.status}${user.expiresAt == null ? '' : ' · ${user.expiresAt!.toLocal().toString().substring(0, 10)}'}',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => onOpenUser(user),
            ),
          ),
          if (controller.usersNextCursor != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: controller.usersLoading
                    ? null
                    : () => controller.loadUsers(
                        search: controller.userSearch,
                        cursor: controller.usersNextCursor,
                      ),
                icon: const Icon(Icons.expand_more_rounded),
                label: Text(copy('nextPage')),
              ),
            ),
        ],
      ),
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

String _adminCopy(String locale, String key) {
  final language = locale == 'ja'
      ? 'ja'
      : locale == 'zh-Hant'
      ? 'zh-Hant'
      : 'zh-Hans';
  return _adminCopies[language]?[key] ?? _adminCopies['zh-Hans']![key]!;
}

const _adminCopies = <String, Map<String, String>>{
  'zh-Hans': {
    'controlsTitle': '服务与会员开关',
    'membershipSwitch': '启用会员限制',
    'membershipSwitchDetail': '关闭时不检查会员额度；打开后所有新增生成都走服务端限额。',
    'trialSwitch': '开放 7 天试用',
    'trialSwitchDetail': '只控制新试用入口，不影响已开始的试用。',
    'salesSwitch': '开放月会员购买',
    'salesSwitchDetail': '只允许创建新的 39.9 元订单，不会直接发放权益。',
    'generationSwitch': '允许新增生成',
    'generationSwitchDetail': '关闭时保留已有内容学习，暂停新的模型与配音调用。',
    'membershipOnConfirm': '打开后，新生成会按会员方案检查额度；请确认预算与数据库迁移已就绪。',
    'membershipOffConfirm': '关闭后将进入公开体验模式，不再执行会员额度限制。',
    'trialOnConfirm': '开放新的 7 天试用入口？试用仍会在第一条个人表达成功后开始。',
    'trialOffConfirm': '关闭新试用入口？已开始的试用和已购权益不受影响。',
    'salesOnConfirm': '开放新的月会员订单？支付核验完成前不会发放会员。',
    'salesOffConfirm': '关闭购买入口？已有订单和有效会员不会被撤销。',
    'generationOnConfirm': '恢复新增生成？系统仍会保留预算与会员限制。',
    'generationOffConfirm': '暂停新增生成？已有内容和草稿仍可使用。',
    'confirmTitle': '确认变更服务开关',
    'cancel': '取消',
    'confirm': '确认',
    'updateFailed': '开关更新失败，请刷新后重试。',
    'version': '配置版本：',
    'notConfigured': '数据库开关尚未配置，目前按安全默认值运行。',
    'usersTitle': '用户与会员',
    'usersSearchHint': '输入用户 ID 或邮箱搜索',
    'search': '搜索',
    'usersEmpty': '没有匹配的用户。',
    'nextPage': '加载下一页',
    'audienceTitle': '用户画像摘要',
    'audienceLoad': '加载摘要',
    'audienceHint': '按单一维度查看已同意研究资料的聚合结果；不显示个人明细。',
    'audienceRegistered': '注册',
    'audienceCovered': '画像覆盖',
    'audienceUnanswered': '未填写',
    'audienceRefusal': '不愿透露',
    'audienceWithdrawn': '已撤回',
    'audienceInsufficient': '样本不足',
  },
  'zh-Hant': {
    'controlsTitle': '服務與會員開關',
    'membershipSwitch': '啟用會員限制',
    'membershipSwitchDetail': '關閉時不檢查會員額度；開啟後所有新增產生都走伺服器限額。',
    'trialSwitch': '開放 7 天試用',
    'trialSwitchDetail': '只控制新試用入口，不影響已開始的試用。',
    'salesSwitch': '開放月會員購買',
    'salesSwitchDetail': '只允許建立新的 39.9 元訂單，不會直接發放權益。',
    'generationSwitch': '允許新增產生',
    'generationSwitchDetail': '關閉時保留已有內容學習，暫停新的模型與配音呼叫。',
    'membershipOnConfirm': '開啟後，新產生會按會員方案檢查額度；請確認預算與資料庫 migration 已就緒。',
    'membershipOffConfirm': '關閉後將進入公開體驗模式，不再執行會員額度限制。',
    'trialOnConfirm': '開放新的 7 天試用入口？試用仍會在第一條個人表達成功後開始。',
    'trialOffConfirm': '關閉新試用入口？已開始的試用和已購權益不受影響。',
    'salesOnConfirm': '開放新的月會員訂單？付款核驗完成前不會發放會員。',
    'salesOffConfirm': '關閉購買入口？已有訂單和有效會員不會被撤銷。',
    'generationOnConfirm': '恢復新增產生？系統仍會保留預算與會員限制。',
    'generationOffConfirm': '暫停新增產生？已有內容和草稿仍可使用。',
    'confirmTitle': '確認變更服務開關',
    'cancel': '取消',
    'confirm': '確認',
    'updateFailed': '開關更新失敗，請重新整理後重試。',
    'version': '設定版本：',
    'notConfigured': '資料庫開關尚未設定，目前按安全預設值執行。',
    'usersTitle': '使用者與會員',
    'usersSearchHint': '輸入使用者 ID 或電子郵件搜尋',
    'search': '搜尋',
    'usersEmpty': '沒有符合的使用者。',
    'nextPage': '載入下一頁',
    'audienceTitle': '使用者畫像摘要',
    'audienceLoad': '載入摘要',
    'audienceHint': '按單一維度查看已同意研究資料的聚合結果；不顯示個人明細。',
    'audienceRegistered': '註冊',
    'audienceCovered': '畫像覆蓋',
    'audienceUnanswered': '未填寫',
    'audienceRefusal': '不願透露',
    'audienceWithdrawn': '已撤回',
    'audienceInsufficient': '樣本不足',
  },
  'ja': {
    'controlsTitle': 'サービスと会員設定',
    'membershipSwitch': '会員制限を有効にする',
    'membershipSwitchDetail': 'オフでは会員上限を確認せず、オンでは全生成をサーバー上限で管理します。',
    'trialSwitch': '7日間トライアルを開く',
    'trialSwitchDetail': '新規トライアルだけを制御し、開始済みの期間には影響しません。',
    'salesSwitch': '月額購入を開く',
    'salesSwitchDetail': '新しい注文を作成できます。支払い確認前に会員権限は付与しません。',
    'generationSwitch': '新しい生成を許可',
    'generationSwitchDetail': 'オフでも保存済みの内容と下書きは利用できます。',
    'membershipOnConfirm': '会員制限を有効にしますか？データベースと予算の準備を確認してください。',
    'membershipOffConfirm': '公開体験モードに戻しますか？会員上限は適用されません。',
    'trialOnConfirm': '新しいトライアルを開きますか？最初の生成成功から開始します。',
    'trialOffConfirm': '新しいトライアルを閉じますか？開始済みの期間には影響しません。',
    'salesOnConfirm': '月額注文を開きますか？支払い確認前に権限は付与しません。',
    'salesOffConfirm': '購入入口を閉じますか？既存注文と会員期間は維持されます。',
    'generationOnConfirm': '新しい生成を再開しますか？予算と会員制限は維持されます。',
    'generationOffConfirm': '新しい生成を一時停止しますか？保存済み内容は利用できます。',
    'confirmTitle': 'サービス設定を変更',
    'cancel': 'キャンセル',
    'confirm': '確認',
    'updateFailed': '設定を更新できませんでした。再読み込みして再試行してください。',
    'version': '設定バージョン：',
    'notConfigured': 'データベース設定が未構成のため、安全な既定値で動作しています。',
    'usersTitle': 'ユーザーと会員',
    'usersSearchHint': 'ユーザー ID またはメールで検索',
    'search': '検索',
    'usersEmpty': '一致するユーザーがいません。',
    'nextPage': '次のページを読み込む',
    'audienceTitle': 'ユーザー調査の概要',
    'audienceLoad': '概要を読み込む',
    'audienceHint': '同意済みの資料を一つの軸で集計します。個人の回答は表示しません。',
    'audienceRegistered': '登録',
    'audienceCovered': '回答あり',
    'audienceUnanswered': '未回答',
    'audienceRefusal': '回答しない',
    'audienceWithdrawn': '撤回済み',
    'audienceInsufficient': 'サンプル不足',
  },
};
