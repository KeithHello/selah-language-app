import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../design/selah_colors.dart';
import '../../design/selah_spacing.dart';
import '../../design/selah_motion.dart';
import '../../design/selah_theme.dart';
import '../../design/selah_typography.dart';
import '../../domain/selah_enums.dart';
import '../domain/learning_engine.dart';
import '../domain/learning_models.dart';
import '../learning_controller.dart';
import '../l10n/selah_strings.dart';
import 'membership_widgets.dart';
import 'research_profile_widgets.dart';
import 'feedback_survey_widgets.dart';
import 'admin_dashboard_page.dart';
import 'loop_listening_panel.dart';
import 'plush_companion.dart';
import 'web_start_action.dart';

String _contextUiLocale(BuildContext context) {
  final locale = Localizations.maybeLocaleOf(context);
  if (locale?.languageCode == 'ja') return 'ja';
  if (locale?.scriptCode == 'Hans') return 'zh-Hans';
  return defaultUiLocale;
}

/// The app owns its product copy and intentionally does not add the
/// `flutter_localizations` dependency just for three system locales. These
/// delegates keep Material and Cupertino controls functional while their
/// surrounding labels come from [SelahStrings].
class _SelahMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _SelahMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      SynchronousFuture<MaterialLocalizations>(
        const DefaultMaterialLocalizations(),
      );

  @override
  bool shouldReload(_SelahMaterialLocalizationsDelegate old) => false;
}

class _SelahCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const _SelahCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      SynchronousFuture<CupertinoLocalizations>(
        const DefaultCupertinoLocalizations(),
      );

  @override
  bool shouldReload(_SelahCupertinoLocalizationsDelegate old) => false;
}

// Temporary product gate: retain memory data and syncing, but hide UI entry points.
const _growthMemoriesUiEnabled = false;

/// The Web client shell.  The controller owns all product state and side
/// effects; this widget only renders that state and awaits every action.
class WebLearningApp extends StatefulWidget {
  const WebLearningApp({super.key, required this.controller});

  final LearningController controller;

  @override
  State<WebLearningApp> createState() => _WebLearningAppState();
}

class _WebLearningAppState extends State<WebLearningApp> {
  bool _initializing = false;
  bool _deepLinkApplied = false;

  @override
  void initState() {
    super.initState();
    if (!widget.controller.initialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _applyDeepLink());
    }
  }

  Future<void> _initialize() async {
    if (_initializing || widget.controller.initialized) return;
    _initializing = true;
    try {
      await widget.controller.initialize();
      _applyDeepLink();
    } finally {
      _initializing = false;
    }
  }

  void _applyDeepLink() {
    if (_deepLinkApplied || !mounted || !widget.controller.initialized) return;
    if (Uri.base.fragment == '/admin' &&
        widget.controller.state.preferences.onboarded) {
      _deepLinkApplied = true;
      widget.controller.navigate(5);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final strings = widget.controller.strings;
        final theme = SelahTheme.light();
        final locale = _materialLocale(widget.controller.uiLocale);
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Selah',
          locale: locale,
          localizationsDelegates: const [
            _SelahMaterialLocalizationsDelegate(),
            _SelahCupertinoLocalizationsDelegate(),
          ],
          supportedLocales: const [
            Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
            Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
            Locale('ja'),
          ],
          localeListResolutionCallback: (_, _) => locale,
          theme: theme.copyWith(
            textTheme: theme.textTheme.apply(
              fontFamily: 'Plus Jakarta Sans',
              fontFamilyFallback: const ['Noto Sans SC'],
            ),
            primaryTextTheme: theme.primaryTextTheme.apply(
              fontFamily: 'Plus Jakarta Sans',
              fontFamilyFallback: const ['Noto Sans SC'],
            ),
          ),
          home: _WebRoot(controller: widget.controller, strings: strings),
        );
      },
    );
  }

  static Locale _materialLocale(String value) => switch (value) {
    'zh-Hans' => const Locale.fromSubtags(
      languageCode: 'zh',
      scriptCode: 'Hans',
    ),
    'ja' => const Locale('ja'),
    _ => const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  };
}

class _WebRoot extends StatelessWidget {
  const _WebRoot({required this.controller, required this.strings});

  final LearningController controller;
  final SelahStrings strings;

  @override
  Widget build(BuildContext context) {
    if (!controller.initialized) {
      return _LoadingView(error: controller.error, strings: strings);
    }
    if (!controller.state.preferences.onboarded) {
      return _OnboardingPage(controller: controller);
    }
    return _WebShell(controller: controller);
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView({this.error, required this.strings});

  final String? error;
  final SelahStrings strings;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(SelahSpacing.page),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _BrandMark(size: 60),
                const SizedBox(height: SelahSpacing.lg),
                Text(
                  strings.text('app.loading.title'),
                  style: SelahTypography.headlineLarge(),
                ),
                const SizedBox(height: SelahSpacing.sm),
                Text(
                  error ?? strings.text('app.loading.detail'),
                  textAlign: TextAlign.center,
                  style: SelahTypography.bodyMedium(),
                ),
                const SizedBox(height: SelahSpacing.xl),
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WebShell extends StatelessWidget {
  const _WebShell({required this.controller});

  final LearningController controller;

  static List<_TabSpec> _tabs(SelahStrings strings) => [
    _TabSpec('Today', strings.tabToday(), Icons.wb_sunny_outlined),
    _TabSpec('Listen', strings.tabListen(), Icons.headphones_outlined),
    _TabSpec('Practice', strings.tabPractice(), Icons.replay_rounded),
    _TabSpec('Notes', strings.tabNotes(), Icons.menu_book_outlined),
    _TabSpec('Settings', strings.tabSettings(), Icons.tune_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs(SelahStrings.of(controller.uiLocale));
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 900;
        if (!desktop) return _mobileLayout(context, tabs);
        return _desktopLayout(context, constraints.maxWidth >= 1180, tabs);
      },
    );
  }

  Widget _desktopLayout(
    BuildContext context,
    bool showCompanion,
    List<_TabSpec> tabs,
  ) {
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            _Sidebar(controller: controller, tabs: tabs),
            Expanded(
              child: Column(
                children: [
                  _TopBar(controller: controller, tabs: tabs),
                  Expanded(child: _Content(controller: controller)),
                ],
              ),
            ),
            if (showCompanion &&
                controller.state.preferences.companionRailVisible &&
                controller.tab != 0)
              _CompanionRail(controller: controller),
          ],
        ),
      ),
    );
  }

  Widget _mobileLayout(BuildContext context, List<_TabSpec> tabs) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _MobileTopBar(controller: controller, tabs: tabs),
            Expanded(child: _Content(controller: controller)),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: controller.tab.clamp(0, tabs.length - 1),
        onDestinationSelected: controller.navigate,
        destinations: tabs
            .map(
              (tab) => NavigationDestination(
                icon: Icon(tab.icon),
                selectedIcon: Icon(tab.icon),
                label: tab.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _TabSpec {
  const _TabSpec(this.name, this.label, this.icon);

  final String name;
  final String label;
  final IconData icon;
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.controller, required this.tabs});

  final LearningController controller;
  final List<_TabSpec> tabs;

  @override
  Widget build(BuildContext context) {
    final strings = SelahStrings.of(controller.uiLocale);
    return Container(
      width: 238,
      decoration: const BoxDecoration(
        color: SelahColors.cardSoft,
        border: Border(right: BorderSide(color: SelahColors.borderLight)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 24, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _BrandMark(size: 36),
          const SizedBox(height: 10),
          Text(
            'SELAH',
            style: SelahTypography.labelLarge(
              color: SelahColors.textPrimary,
            ).copyWith(letterSpacing: 2.6),
          ),
          const SizedBox(height: 4),
          Text(
            'quiet growth',
            style: SelahTypography.bodySmall(color: SelahColors.textTertiary),
          ),
          const SizedBox(height: 38),
          Text(
            strings.text('sidebar.space'),
            style: SelahTypography.labelSmall(color: SelahColors.textTertiary),
          ),
          const SizedBox(height: 8),
          ...tabs.asMap().entries.map((entry) {
            final index = entry.key;
            final tab = entry.value;
            final selected = controller.tab == index;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Semantics(
                button: true,
                selected: selected,
                label: strings.pageLabel(tab.label),
                child: InkWell(
                  borderRadius: BorderRadius.circular(SelahCornerRadius.md),
                  onTap: () => controller.navigate(index),
                  child: AnimatedContainer(
                    duration: SelahMotion.quick,
                    curve: SelahMotion.standardCurve,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? SelahColors.coralSoft
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(SelahCornerRadius.md),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          tab.icon,
                          size: 19,
                          color: selected
                              ? SelahColors.coral
                              : SelahColors.textSecondary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            tab.label,
                            style:
                                SelahTypography.bodyLarge(
                                  color: selected
                                      ? SelahColors.coral
                                      : SelahColors.textSecondary,
                                ).copyWith(
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                          ),
                        ),
                        if (index == 2 && controller.due.isNotEmpty)
                          _CountBadge(value: controller.due.length),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
          _SidebarStatus(controller: controller),
        ],
      ),
    );
  }
}

class _SidebarStatus extends StatelessWidget {
  const _SidebarStatus({required this.controller});

  final LearningController controller;

  @override
  Widget build(BuildContext context) {
    final strings = SelahStrings.of(controller.uiLocale);
    final online = _boolValue(controller.platformInfo, const [
      'online',
      'isOnline',
    ]);
    final configured = controller.configured;
    final session = controller.hasSession;
    final label = !configured
        ? strings.translateLegacy('本机学习中（云端未配置）')
        : !session
        ? strings.translateLegacy('本机学习中（登录后可同步）')
        : online == false
        ? strings.translateLegacy('离线学习中')
        : online == true
        ? strings.translateLegacy('已连接，可以同步')
        : strings.translateLegacy('账户已连接，等待网络状态');
    final muted = !configured || !session || online == false;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: muted ? SelahColors.amberSoft : SelahColors.sageSoft,
        borderRadius: BorderRadius.circular(SelahCornerRadius.md),
      ),
      child: Row(
        children: [
          Icon(
            muted ? Icons.cloud_off_outlined : Icons.cloud_done_outlined,
            size: 17,
            color: muted ? SelahColors.amber : SelahColors.sage,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
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

class _TopBar extends StatelessWidget {
  const _TopBar({required this.controller, required this.tabs});

  final LearningController controller;
  final List<_TabSpec> tabs;

  @override
  Widget build(BuildContext context) {
    final index = controller.tab.clamp(0, tabs.length - 1);
    final title = controller.tab == 5
        ? SelahStrings.of(controller.uiLocale).text('admin.title')
        : tabs[index].label;
    return Container(
      height: 78,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: SelahColors.borderLight)),
      ),
      child: Row(
        children: [
          Text(title, style: SelahTypography.headlineLarge()),
          const Spacer(),
          if (controller.busy || controller.syncing)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
    );
  }
}

class _MobileTopBar extends StatelessWidget {
  const _MobileTopBar({required this.controller, required this.tabs});

  final LearningController controller;
  final List<_TabSpec> tabs;

  @override
  Widget build(BuildContext context) {
    final index = controller.tab.clamp(0, tabs.length - 1);
    final title = controller.tab == 5
        ? SelahStrings.of(controller.uiLocale).text('admin.title')
        : tabs[index].label;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 10),
      child: Row(
        children: [
          const _BrandMark(size: 28),
          const SizedBox(width: 10),
          Text(title, style: SelahTypography.headlineLarge()),
          const Spacer(),
          if (controller.busy || controller.syncing)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }
}

class _CompanionRail extends StatelessWidget {
  const _CompanionRail({required this.controller});

  final LearningController controller;

  @override
  Widget build(BuildContext context) {
    final strings = SelahStrings.of(controller.uiLocale);
    final stage = _decorationStage(controller);
    const memoriesEnabled = _growthMemoriesUiEnabled;
    final unlockedMemoryKeys = controller.state.memories.keys
        .where(memoryTitles.containsKey)
        .toList();
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: SelahColors.cardSoft,
        border: Border(left: BorderSide(color: SelahColors.borderLight)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 26, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          strings.translateLegacy('陪伴角落'),
                          style: SelahTypography.labelSmall(
                            color: SelahColors.textTertiary,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: strings.text('settings.companion.hide'),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => controller.updatePreferences(
                          companionRailVisible: false,
                        ),
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    controller.state.preferences.name,
                    style: SelahTypography.headlineMedium(),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: PlushCompanion(
                      action: controller.companionAction,
                      revision: controller.companionRevision,
                      size: 174,
                      decorationStage: stage,
                      uiLocale: controller.uiLocale,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      companionCaption(
                        controller.companionAction,
                        uiLocale: controller.uiLocale,
                      ),
                      textAlign: TextAlign.center,
                      style: SelahTypography.bodySmall(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(child: _StagePill(stage: stage)),
                  const SizedBox(height: 24),
                  _CompanionProgress(controller: controller),
                  if (memoriesEnabled) ...[
                    const SizedBox(height: 22),
                    Text(
                      strings.translateLegacy('成长回忆'),
                      style: SelahTypography.labelLarge(),
                    ),
                    const SizedBox(height: 8),
                    if (unlockedMemoryKeys.isEmpty)
                      Text(
                        strings.translateLegacy('完成一次聆听或练习，这里会亮起第一段回忆。'),
                        style: SelahTypography.bodySmall(),
                      )
                    else
                      ...unlockedMemoryKeys
                          .take(3)
                          .map(
                            (key) => Padding(
                              padding: const EdgeInsets.only(bottom: 7),
                              child: _MemoryRow(
                                title: strings.memoryTitle(key),
                                subtitle: strings.memorySubtitle(key),
                              ),
                            ),
                          ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (memoriesEnabled)
            OutlinedButton.icon(
              onPressed: () => _showMemories(context, controller),
              icon: const Icon(Icons.auto_awesome_outlined, size: 17),
              label: Text(strings.translateLegacy('查看全部回忆')),
            ),
        ],
      ),
    );
  }
}

class _CompanionProgress extends StatelessWidget {
  const _CompanionProgress({required this.controller});

  final LearningController controller;

  @override
  Widget build(BuildContext context) {
    final strings = SelahStrings.of(controller.uiLocale);
    final sessions = controller.state.events
        .where(
          (event) =>
              event.type == 'listen_completed' ||
              event.type == 'practice_rated',
        )
        .length;
    final progress = (sessions % 15) / 15;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              strings.translateLegacy('累计生长'),
              style: SelahTypography.labelSmall(
                color: SelahColors.textTertiary,
              ),
            ),
            const Spacer(),
            Text(
              strings.sessionCount(sessions),
              style: SelahTypography.labelSmall(color: SelahColors.sage),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(SelahCornerRadius.pill),
          child: LinearProgressIndicator(
            value: sessions == 0 ? 0 : progress.clamp(.06, 1.0),
            minHeight: 7,
            backgroundColor: SelahColors.sageSoft,
            valueColor: const AlwaysStoppedAnimation(SelahColors.sage),
          ),
        ),
      ],
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.controller});

  final LearningController controller;

  @override
  Widget build(BuildContext context) {
    final showFeedbackInvite =
        controller.tab != 4 &&
        !controller.isAnonymous &&
        controller.feedbackSurvey.canShowInvite;
    final showProfileInvite =
        controller.tab != 4 &&
        !controller.isAnonymous &&
        !controller.feedbackSurvey.blocksOtherInvites &&
        controller.researchProfile.canShowInvite;
    return Column(
      children: [
        if (showFeedbackInvite)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: FeedbackSurveyInvite(
              controller: controller.feedbackSurvey,
              uiLocale: controller.uiLocale,
              onOpen: () => _showFeedbackSurvey(context, controller),
            ),
          ),
        if (showProfileInvite)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: ResearchProfileInvite(
              controller: controller.researchProfile,
              uiLocale: controller.uiLocale,
              onOpen: () => controller.navigate(4),
            ),
          ),
        if (controller.error != null || controller.notice != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: _MessageBar(controller: controller),
          ),
        if (controller.platformInfo['updateAvailable'] == true)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: _UpdateBanner(controller: controller),
          ),
        Expanded(
          child: IndexedStack(
            index: controller.tab,
            children: [
              _TodayPage(controller: controller, key: const ValueKey('today')),
              _ListenPage(
                controller: controller,
                key: const ValueKey('listen'),
              ),
              _PracticePage(
                controller: controller,
                key: const ValueKey('practice'),
              ),
              _NotesPage(controller: controller, key: const ValueKey('notes')),
              _SettingsPage(
                controller: controller,
                key: const ValueKey('settings'),
              ),
              if (controller.tab == 5)
                AdminDashboardPage(
                  controller: controller.admin,
                  uiLocale: controller.uiLocale,
                  onBack: () => controller.navigate(4),
                  onLogin: () => _showAuth(context, controller),
                  key: const ValueKey('admin'),
                ),
            ],
          ),
        ),
        if (controller.loopActive)
          LoopListeningMiniPlayer(controller: controller),
      ],
    );
  }
}

class _MessageBar extends StatelessWidget {
  const _MessageBar({required this.controller});

  final LearningController controller;

  bool get _offersLogin {
    if (!controller.configured) return false;
    final text = '${controller.error ?? ''} ${controller.notice ?? ''}';
    return controller.isAnonymous ||
        text.contains('登录') ||
        text.contains('登入') ||
        text.contains('注册') ||
        text.contains('註冊') ||
        text.contains('ログイン');
  }

  @override
  Widget build(BuildContext context) {
    final error = controller.error;
    final isError = error != null;
    final strings = SelahStrings.of(controller.uiLocale);
    final message = strings.translateLegacy(error ?? controller.notice!);
    return Semantics(
      liveRegion: true,
      label: '${strings.translateLegacy(isError ? '错误：' : '提示：')}$message',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isError ? SelahColors.coralSoft : SelahColors.sageSoft,
          borderRadius: BorderRadius.circular(SelahCornerRadius.md),
        ),
        child: Row(
          children: [
            Icon(
              isError
                  ? Icons.info_outline_rounded
                  : Icons.check_circle_outline_rounded,
              size: 18,
              color: isError ? SelahColors.coral : SelahColors.sage,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                message,
                style: SelahTypography.bodySmall(
                  color: SelahColors.textSecondary,
                ),
              ),
            ),
            if (_offersLogin)
              TextButton(
                onPressed: controller.busy
                    ? null
                    : () => _showAuth(context, controller),
                child: Text(
                  strings.translateLegacy(
                    controller.isAnonymous ? '注册／登录' : '登录',
                  ),
                ),
              ),
            IconButton(
              tooltip: strings.text('common.close'),
              onPressed: controller.clearMessage,
              icon: const Icon(Icons.close_rounded, size: 18),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

class _UpdateBanner extends StatefulWidget {
  const _UpdateBanner({required this.controller});

  final LearningController controller;

  @override
  State<_UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<_UpdateBanner> {
  bool _dismissed = false;

  LearningController get controller => widget.controller;

  Future<void> _apply(BuildContext context) async {
    if (controller.hasUnsavedChanges) return;
    final s = SelahStrings.of(controller.uiLocale);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(s.text('settings.update')),
        content: Text(s.text('settings.updateConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(s.text('settings.updateLater')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(s.text('settings.updateNow')),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.applyUpdate();
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    final s = SelahStrings.of(controller.uiLocale);
    final blocked = controller.hasUnsavedChanges;
    return Material(
      color: SelahColors.amberSoft,
      borderRadius: BorderRadius.circular(SelahCornerRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          children: [
            const Icon(
              Icons.system_update_alt,
              size: 18,
              color: SelahColors.amber,
            ),
            const SizedBox(width: 9),
            Expanded(child: Text(s.text('settings.updateAvailable'))),
            TextButton(
              onPressed: controller.busy
                  ? null
                  : () => setState(() => _dismissed = true),
              child: Text(s.text('settings.updateLater')),
            ),
            FilledButton(
              onPressed: controller.busy || blocked
                  ? null
                  : () => _apply(context),
              child: Text(s.text('settings.updateNow')),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageFrame extends StatelessWidget {
  const _PageFrame({required this.child, this.maxWidth = 820});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );
  }
}

class _TodayPage extends StatefulWidget {
  const _TodayPage({required this.controller, super.key});

  final LearningController controller;

  @override
  State<_TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<_TodayPage> {
  final _input = TextEditingController();
  final _segments = <TextEditingController>[];
  bool _applyingControllerText = false;
  bool _syncingSegments = false;
  DateTime? _recordingStartedAt;
  Timer? _recordingTimer;
  int _recordingSeconds = 0;
  bool _preparing = false;

  LearningController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _input.text = c.todayInput;
    _input.addListener(_onInputChanged);
    c.addListener(_onControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncSegments());
  }

  @override
  void dispose() {
    c.removeListener(_onControllerChanged);
    _input.removeListener(_onInputChanged);
    _input.dispose();
    _disposeSegments();
    _recordingTimer?.cancel();
    super.dispose();
  }

  void _onInputChanged() {
    if (_applyingControllerText) return;
    c.updateTodayInput(_input.text);
  }

  void _onControllerChanged() {
    if (!mounted) return;
    if (c.todayInput != _input.text) {
      _applyingControllerText = true;
      _input.value = TextEditingValue(
        text: c.todayInput,
        selection: TextSelection.collapsed(offset: c.todayInput.length),
      );
      _applyingControllerText = false;
    }
    _syncSegments();
    setState(() {});
  }

  void _disposeSegments() {
    for (final segment in _segments) {
      segment.dispose();
    }
    _segments.clear();
  }

  void _syncSegments() {
    final preparation = c.preparationDraft;
    final expected = preparation?.segments.length ?? 0;
    final textMatches =
        preparation != null &&
        expected == _segments.length &&
        preparation.segments.asMap().entries.every(
          (entry) => _segments[entry.key].text.trim() == entry.value.sourceText,
        );
    if (_syncingSegments ||
        textMatches ||
        (preparation == null && expected == 0 && _segments.isEmpty)) {
      return;
    }
    _syncingSegments = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _disposeSegments();
      final current = c.preparationDraft;
      if (current != null) {
        for (final segment in current.segments) {
          final controller = TextEditingController(text: segment.sourceText);
          controller.addListener(() {
            final index = _segments.indexOf(controller);
            if (index >= 0) c.updatePreparationSegment(index, controller.text);
          });
          _segments.add(controller);
        }
      }
      setState(() {});
      _syncingSegments = false;
    });
  }

  Future<void> _submit() async {
    final text = _input.text.trim();
    if (text.isEmpty || c.busy) return;
    c.clearMessage();
    if (text.length <= 500) {
      await c.generate(text);
      return;
    }
    await _prepare(text);
  }

  Future<void> _prepare(String text) async {
    if (_preparing) return;
    setState(() => _preparing = true);
    c.clearMessage();
    try {
      final prepared = await c.prepare(text);
      if (!mounted) return;
      if (prepared.isEmpty &&
          c.error == null &&
          c.todayInput.trim() == text.trim()) {
        c.error = c.strings.translateLegacy('没有整理出可学习的句子，请修改文字后重试。');
      }
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
  }

  Future<void> _generateSegments() async {
    final texts = _segments
        .map((controller) => controller.text.trim())
        .toList();
    c.clearMessage();
    if (texts.isEmpty || texts.any((text) => text.isEmpty)) {
      setState(() => c.error = c.strings.translateLegacy('请补全每一个分句，再继续生成。'));
      return;
    }
    await c.generatePreparedSegments();
  }

  Future<void> _cancelSegments() async {
    c.cancelPreparation();
    _disposeSegments();
    setState(() {});
  }

  Future<void> _toggleRecording() async {
    c.clearMessage();
    if (!c.recording) {
      await c.startRecording();
      if (!mounted || !c.recording) return;
      _recordingStartedAt = DateTime.now();
      _recordingSeconds = 0;
      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
        if (!mounted || !c.recording) return;
        final elapsed = DateTime.now()
            .difference(_recordingStartedAt!)
            .inSeconds;
        if (elapsed >= 180) {
          _recordingTimer?.cancel();
          await _finishRecording();
          return;
        }
        setState(() => _recordingSeconds = elapsed);
      });
      setState(() {});
      return;
    }
    await _finishRecording();
  }

  Future<void> _finishRecording() async {
    _recordingTimer?.cancel();
    final transcript = await c.stopRecording();
    if (!mounted) return;
    _recordingStartedAt = null;
    _recordingSeconds = 0;
    if (transcript != null && transcript.trim().isNotEmpty) {
      final trimmed = transcript.trim();
      _input.text = trimmed.substring(
        0,
        trimmed.length > 4000 ? 4000 : trimmed.length,
      );
      _input.selection = TextSelection.collapsed(offset: _input.text.length);
      c.updateTodayInput(_input.text);
    }
    setState(() {});
  }

  Future<void> _retryTranscript() async {
    c.clearMessage();
    final transcript = await c.stopRecording();
    if (!mounted) return;
    if (transcript != null && transcript.trim().isNotEmpty) {
      final trimmed = transcript.trim();
      _input.text = trimmed.substring(
        0,
        trimmed.length > 4000 ? 4000 : trimmed.length,
      );
      _input.selection = TextSelection.collapsed(offset: _input.text.length);
      c.updateTodayInput(_input.text);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final sentence = c.activeSentence;
    final textLength = _input.text.length;
    final strings = c.strings;
    return _PageFrame(
      maxWidth: 760,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TodayGreeting(controller: c),
          const SizedBox(height: 24),
          _ExpressionComposer(
            controller: _input,
            strings: strings,
            nativeLanguage: c.nativeLanguage,
            busy: c.busy || _preparing,
            recording: c.recording,
            recordingSeconds: _recordingSeconds,
            onChanged: (_) {},
            onRecord: _toggleRecording,
            onSubmit: _submit,
            onClear: _input.text.isEmpty ? null : _input.clear,
            textLength: textLength,
          ),
          const SizedBox(height: 8),
          _ModelDisclosure(strings: strings),
          if (_segments.isNotEmpty) ...[
            const SizedBox(height: 18),
            _SegmentEditor(
              segments: _segments,
              strings: strings,
              busy: c.busy,
              onGenerate: _generateSegments,
              onCancel: _cancelSegments,
            ),
          ],
          if (c.legacySentence != null) ...[
            const SizedBox(height: 12),
            _InfoBox(
              icon: Icons.history_rounded,
              color: SelahColors.amber,
              text: strings.text('today.legacyText'),
              actionLabel: strings.text('today.openExisting'),
              onAction: c.openLegacySentence,
            ),
          ],
          if (sentence != null) ...[
            const SizedBox(height: 22),
            _GeneratedSentenceCard(controller: c, sentence: sentence),
          ],
          if (c.hasPendingRecording && !c.recording) ...[
            const SizedBox(height: 12),
            _InfoBox(
              icon: Icons.mic_none_rounded,
              color: SelahColors.amber,
              text: strings.text('today.pendingRecording'),
              actionLabel: strings.text('today.retryTranscript'),
              onAction: c.busy ? null : _retryTranscript,
            ),
          ],
          if (c.state.drafts.isNotEmpty) ...[
            const SizedBox(height: 24),
            _DraftsCard(controller: c),
          ],
          const SizedBox(height: 32),
          _SeedShelf(controller: c),
        ],
      ),
    );
  }
}

class _TodayGreeting extends StatelessWidget {
  const _TodayGreeting({required this.controller});

  final LearningController controller;

  @override
  Widget build(BuildContext context) {
    final strings = SelahStrings.of(controller.uiLocale);
    final nativeLanguage = controller.nativeLanguage;
    final name = controller.state.preferences.name.trim();
    final displayName = name.isEmpty ? '小芽' : name;
    final stage = _decorationStage(controller);
    final caption = companionCaption(
      controller.companionAction,
      uiLocale: controller.uiLocale,
    );

    return SizedBox(
      width: double.infinity,
      child: Column(
        children: [
          Semantics(
            label:
                '${strings.translateLegacy('精灵')}：$displayName，${strings.translateLegacy('当前状态')}：$caption',
            image: true,
            excludeSemantics: true,
            child: PlushCompanion(
              action: controller.companionAction,
              revision: controller.companionRevision,
              size: 144,
              decorationStage: stage,
              uiLocale: controller.uiLocale,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SelahTypography.labelLarge(
                  color: SelahColors.textSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: SelahColors.sageSoft,
                  borderRadius: BorderRadius.circular(SelahCornerRadius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: SelahColors.sage,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        caption,
                        textAlign: TextAlign.center,
                        style: SelahTypography.bodySmall(
                          color: const Color(0xFF376F57),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            strings.todayGreetingTitle(),
            textAlign: TextAlign.center,
            style: SelahTypography.displayLarge(),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              strings.todayGreetingSubtitle(nativeLanguage),
              textAlign: TextAlign.center,
              style: SelahTypography.bodyLarge(
                color: SelahColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpressionComposer extends StatelessWidget {
  const _ExpressionComposer({
    required this.controller,
    required this.strings,
    required this.nativeLanguage,
    required this.busy,
    required this.recording,
    required this.recordingSeconds,
    required this.onChanged,
    required this.onRecord,
    required this.onSubmit,
    required this.onClear,
    required this.textLength,
  });

  final TextEditingController controller;
  final SelahStrings strings;
  final String nativeLanguage;
  final bool busy;
  final bool recording;
  final int recordingSeconds;
  final ValueChanged<String> onChanged;
  final VoidCallback onRecord;
  final VoidCallback onSubmit;
  final VoidCallback? onClear;
  final int textLength;

  @override
  Widget build(BuildContext context) {
    final long = textLength > 500;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.edit_note_rounded,
                  size: 20,
                  color: SelahColors.coral,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    strings.text('today.inputLabel'),
                    style: SelahTypography.headlineMedium(),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$textLength / 4,000',
                  style: SelahTypography.labelSmall(
                    color: textLength > 4000
                        ? SelahColors.danger
                        : SelahColors.textTertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLength: 4000,
              maxLines: 5,
              minLines: 3,
              onChanged: onChanged,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: strings.todayInputHint(nativeLanguage),
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) => Row(
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth * .42,
                    ),
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : onRecord,
                      icon: Icon(
                        recording ? Icons.stop_rounded : Icons.mic_none_rounded,
                        size: 18,
                      ),
                      label: Text(
                        strings.recordLabel(
                          recording: recording,
                          seconds: recordingSeconds,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: busy || textLength == 0 ? null : onSubmit,
                      icon: Icon(
                        long
                            ? Icons.view_agenda_outlined
                            : Icons.auto_awesome_rounded,
                        size: 18,
                      ),
                      label: Text(strings.submitLabel(busy: busy, long: long)),
                    ),
                  ),
                  if (onClear != null) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: strings.text('common.clear'),
                      onPressed: onClear,
                      icon: const Icon(Icons.close_rounded, size: 19),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 9),
            Text(
              long
                  ? strings.text('today.longInfo')
                  : strings.text('today.shortInfo'),
              style: SelahTypography.bodySmall(color: SelahColors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModelDisclosure extends StatelessWidget {
  const _ModelDisclosure({required this.strings});

  final SelahStrings strings;

  @override
  Widget build(BuildContext context) {
    final text = switch (strings.locale) {
      'ja' => 'OpenAI GPT モデルで学習内容を生成・整理します。音声は AI 合成です。',
      'zh-Hant' => '使用 OpenAI GPT 模型產生與整理學習內容，語音由 AI 合成。',
      _ => '使用 OpenAI GPT 模型生成和整理学习内容，语音由 AI 合成。',
    };
    return Semantics(
      label: text,
      child: Row(
        children: [
          const Icon(
            Icons.auto_awesome_outlined,
            size: 16,
            color: SelahColors.coral,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: SelahTypography.bodySmall(color: SelahColors.textTertiary),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentEditor extends StatelessWidget {
  const _SegmentEditor({
    required this.segments,
    required this.strings,
    required this.busy,
    required this.onGenerate,
    required this.onCancel,
  });

  final List<TextEditingController> segments;
  final SelahStrings strings;
  final bool busy;
  final VoidCallback onGenerate;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: SelahColors.lavenderSoft,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.call_split_rounded,
                  size: 20,
                  color: SelahColors.lavender,
                ),
                const SizedBox(width: 8),
                Text(
                  strings.translateLegacy('先整理成几句'),
                  style: SelahTypography.headlineMedium(),
                ),
                const Spacer(),
                Text(
                  '${segments.length} / 20',
                  style: SelahTypography.labelSmall(
                    color: SelahColors.textTertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              strings.translateLegacy('确认每一段都是你想练习的完整表达；系统会按每 5 段一批继续生成。'),
              style: SelahTypography.bodySmall(),
            ),
            const SizedBox(height: 14),
            ...segments.asMap().entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: TextField(
                  controller: entry.value,
                  enabled: !busy,
                  maxLength: 500,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: strings.segmentLabel(entry.key + 1),
                    counterText: '',
                  ),
                ),
              ),
            ),
            Row(
              children: [
                TextButton(
                  onPressed: busy ? null : onCancel,
                  child: Text(strings.text('common.cancel')),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: busy ? null : onGenerate,
                  icon: const Icon(Icons.auto_awesome_rounded, size: 17),
                  label: Text(strings.confirmGenerateLabel(busy: busy)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GeneratedSentenceCard extends StatelessWidget {
  const _GeneratedSentenceCard({
    required this.controller,
    required this.sentence,
  });

  final LearningController controller;
  final LearnSentence sentence;

  @override
  Widget build(BuildContext context) {
    final strings = SelahStrings.of(controller.uiLocale);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.translateLegacy('你的新句子'),
                        style: SelahTypography.labelSmall(
                          color: SelahColors.coral,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(sentence.source, style: SelahTypography.bodyLarge()),
                      const SizedBox(height: 10),
                      Text(
                        sentence.target,
                        style: SelahTypography.headlineLarge(),
                      ),
                    ],
                  ),
                ),
                _CategoryPill(category: sentence.category),
              ],
            ),
            if (sentence.breakdown.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(
                strings.translateLegacy('句子拆解'),
                style: SelahTypography.labelLarge(),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: sentence.breakdown
                    .map((item) => _BreakdownChip(item: item))
                    .toList(),
              ),
            ],
            if (sentence.vocabulary.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(
                strings.translateLegacy('值得留下的词'),
                style: SelahTypography.labelLarge(),
              ),
              const SizedBox(height: 8),
              ...sentence.vocabulary
                  .take(4)
                  .map(
                    (entry) => _VocabularyRow(
                      sentence: sentence,
                      entry: entry,
                      controller: controller,
                    ),
                  ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: controller.busy
                        ? null
                        : () async {
                            controller.clearMessage();
                            await controller.play(sentence);
                          },
                    icon: const Icon(Icons.headphones_rounded, size: 18),
                    label: Text(strings.translateLegacy('去聆听这句')),
                  ),
                ),
                if (sentence.origin == 'user_recording') ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: controller.busy
                        ? null
                        : () async {
                            controller.clearMessage();
                            await controller.regenerate(sentence.source);
                          },
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(strings.translateLegacy('重新生成')),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DraftsCard extends StatelessWidget {
  const _DraftsCard({required this.controller});

  final LearningController controller;

  @override
  Widget build(BuildContext context) {
    final strings = SelahStrings.of(controller.uiLocale);
    final drafts = controller.state.drafts;
    if (drafts.isEmpty) return const SizedBox.shrink();
    return Card(
      color: SelahColors.amberSoft,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.bookmark_border_rounded,
                  size: 19,
                  color: SelahColors.amber,
                ),
                const SizedBox(width: 8),
                Text(
                  strings.translateLegacy('待完成的草稿'),
                  style: SelahTypography.headlineMedium(),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...drafts.map(
              (draft) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  draft.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  strings.translateLegacy('生成未完成，可安全重试。'),
                  style: SelahTypography.bodySmall(),
                ),
                trailing: IconButton(
                  tooltip: strings.translateLegacy('重试这条草稿'),
                  onPressed: controller.busy
                      ? null
                      : () async {
                          controller.clearMessage();
                          await controller.retryDraft(draft);
                        },
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeedShelf extends StatelessWidget {
  const _SeedShelf({required this.controller});

  final LearningController controller;

  @override
  Widget build(BuildContext context) {
    final strings = SelahStrings.of(controller.uiLocale);
    final seeds = controller.seeds.take(3).toList();
    if (seeds.isEmpty) return const SizedBox.shrink();
    final added = controller.state.sentences
        .map((sentence) => sentence.seedId)
        .whereType<String>()
        .toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                strings.translateLegacy('从真实生活开始'),
                style: SelahTypography.headlineMedium(),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => _showSeedLibrary(context, controller),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(
                '${strings.translateLegacy('查看全部')} ${controller.seeds.length} ${strings.locale == 'ja'
                    ? '文'
                    : strings.locale == 'zh-Hant'
                    ? '句'
                    : '句'}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...seeds.map(
          (seed) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(SelahCornerRadius.lg),
                onTap: controller.busy
                    ? null
                    : () async {
                        controller.clearMessage();
                        await controller.addSeed(seed);
                      },
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.eco_outlined,
                        size: 19,
                        color: SelahColors.sage,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          seed.source,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (added.contains(seed.seedId))
                        const Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: Icon(
                            Icons.check_circle_outline_rounded,
                            size: 18,
                            color: SelahColors.sage,
                          ),
                        ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: SelahColors.textTertiary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ListenPage extends StatefulWidget {
  const _ListenPage({required this.controller, super.key});

  final LearningController controller;

  @override
  State<_ListenPage> createState() => _ListenPageState();
}

class _ListenPageState extends State<_ListenPage> {
  LearnSentence? _selected;
  bool _revealed = false;
  bool _loopMode = false;

  LearningController get c => widget.controller;

  @override
  void didUpdateWidget(covariant _ListenPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (c.activeSentence != null && c.activeSentence!.id != _selected?.id) {
      _selected = c.activeSentence;
      _revealed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = SelahStrings.of(c.uiLocale);
    final loopMode = _loopMode || c.loopActive;
    final sentences = c.state.sentences
        .where((sentence) => !sentence.archived)
        .toList();
    final selected =
        _selected != null &&
            sentences.any((sentence) => sentence.id == _selected!.id)
        ? sentences.firstWhere((sentence) => sentence.id == _selected!.id)
        : (c.activeSentence != null &&
                  sentences.any(
                    (sentence) => sentence.id == c.activeSentence!.id,
                  )
              ? sentences.firstWhere(
                  (sentence) => sentence.id == c.activeSentence!.id,
                )
              : (sentences.isNotEmpty ? sentences.first : null));
    return _PageFrame(
      maxWidth: 980,
      child: sentences.isEmpty
          ? _EmptyState(
              icon: Icons.headphones_outlined,
              title: strings.translateLegacy('还没有可聆听的句子'),
              message: strings.translateLegacy('先在 Today 写下一句，或完成开场的三句种子。'),
              actionLabel: strings.translateLegacy('去 Today 写一句'),
              onAction: () => c.navigate(0),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                if (loopMode) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ListenHeader(controller: c, count: sentences.length),
                      const SizedBox(height: 14),
                      _ListenModeSwitch(
                        loopMode: loopMode,
                        uiLocale: c.uiLocale,
                        onChanged: (value) => setState(() => _loopMode = value),
                      ),
                      const SizedBox(height: 16),
                      LoopListeningPanel(controller: c),
                    ],
                  );
                }
                final split = constraints.maxWidth >= 680;
                if (!split) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ListenHeader(controller: c, count: sentences.length),
                      const SizedBox(height: 14),
                      _ListenModeSwitch(
                        loopMode: loopMode,
                        uiLocale: c.uiLocale,
                        onChanged: (value) => setState(() => _loopMode = value),
                      ),
                      const SizedBox(height: 16),
                      _SentencePicker(
                        sentences: sentences,
                        selected: selected,
                        uiLocale: c.uiLocale,
                        onSelect: (sentence) {
                          c.selectSentence(sentence);
                          setState(() {
                            _selected = sentence;
                            _revealed = false;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      if (selected != null)
                        _ListenDetail(
                          controller: c,
                          sentence: selected,
                          revealed: _revealed,
                          onReveal: () => setState(() => _revealed = true),
                        ),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ListenHeader(controller: c, count: sentences.length),
                    const SizedBox(height: 16),
                    _ListenModeSwitch(
                      loopMode: loopMode,
                      uiLocale: c.uiLocale,
                      onChanged: (value) => setState(() => _loopMode = value),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 280,
                          child: _SentencePicker(
                            sentences: sentences,
                            selected: selected,
                            uiLocale: c.uiLocale,
                            onSelect: (sentence) {
                              c.selectSentence(sentence);
                              setState(() {
                                _selected = sentence;
                                _revealed = false;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: selected == null
                              ? const SizedBox.shrink()
                              : _ListenDetail(
                                  controller: c,
                                  sentence: selected,
                                  revealed: _revealed,
                                  onReveal: () =>
                                      setState(() => _revealed = true),
                                ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _ListenHeader extends StatelessWidget {
  const _ListenHeader({required this.controller, required this.count});

  final LearningController controller;
  final int count;

  @override
  Widget build(BuildContext context) {
    final strings = SelahStrings.of(controller.uiLocale);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.translateLegacy('给耳朵一点时间'),
                style: SelahTypography.displayMedium(),
              ),
              const SizedBox(height: 6),
              Text(
                strings.translateLegacy('先听声音，再决定要不要看答案。'),
                style: SelahTypography.bodyMedium(),
              ),
            ],
          ),
        ),
        Text(
          strings.locale == 'ja' ? '$count文' : '$count 句',
          style: SelahTypography.labelLarge(color: SelahColors.lavender),
        ),
      ],
    );
  }
}

class _ListenModeSwitch extends StatelessWidget {
  const _ListenModeSwitch({
    required this.loopMode,
    required this.uiLocale,
    required this.onChanged,
  });

  final bool loopMode;
  final String uiLocale;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final strings = SelahStrings.of(uiLocale);
    return SegmentedButton<bool>(
      segments: [
        ButtonSegment(
          value: false,
          label: Text(strings.translateLegacy('逐句听')),
        ),
        ButtonSegment(value: true, label: Text(strings.translateLegacy('循环听'))),
      ],
      selected: {loopMode},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}

class _SentencePicker extends StatelessWidget {
  const _SentencePicker({
    required this.sentences,
    required this.selected,
    required this.uiLocale,
    required this.onSelect,
  });

  final List<LearnSentence> sentences;
  final LearnSentence? selected;
  final String uiLocale;
  final ValueChanged<LearnSentence> onSelect;

  @override
  Widget build(BuildContext context) {
    final strings = SelahStrings.of(uiLocale);
    return Card(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(SelahCornerRadius.lg),
        child: Column(
          children: sentences.map((sentence) {
            final active = selected?.id == sentence.id;
            return Semantics(
              button: true,
              selected: active,
              label: '${strings.translateLegacy('选择句子')}：${sentence.source}',
              child: InkWell(
                onTap: () => onSelect(sentence),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: active
                        ? SelahColors.lavenderSoft
                        : Colors.transparent,
                    border: const Border(
                      bottom: BorderSide(color: SelahColors.borderLight),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _reviewColor(sentence.reviewState),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          sentence.source,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: SelahTypography.bodyMedium(
                            color: active
                                ? SelahColors.textPrimary
                                : SelahColors.textSecondary,
                          ),
                        ),
                      ),
                      if (sentence.listenedAt != null)
                        const Icon(
                          Icons.check_rounded,
                          size: 17,
                          color: SelahColors.sage,
                        ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _ListenDetail extends StatelessWidget {
  const _ListenDetail({
    required this.controller,
    required this.sentence,
    required this.revealed,
    required this.onReveal,
  });

  final LearningController controller;
  final LearnSentence sentence;
  final bool revealed;
  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) {
    final strings = SelahStrings.of(controller.uiLocale);
    final playback = controller.isPlaybackFor(sentence)
        ? controller.playback
        : const <String, dynamic>{};
    final playing = _isPlaying(playback);
    final position =
        _numValue(playback, const ['positionMs', 'position', 'currentMs']) ?? 0;
    final duration = _numValue(playback, const ['durationMs', 'duration']) ?? 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _CategoryPill(category: sentence.category),
                const Spacer(),
                _ReviewStatePill(state: sentence.reviewState),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              strings.translateLegacy('中文提示'),
              style: SelahTypography.labelSmall(
                color: SelahColors.textTertiary,
              ),
            ),
            const SizedBox(height: 8),
            Text(sentence.source, style: SelahTypography.displayMedium()),
            const SizedBox(height: 22),
            if (!revealed)
              Center(
                child: OutlinedButton.icon(
                  onPressed: onReveal,
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: Text(strings.translateLegacy('看英文答案')),
                ),
              )
            else ...[
              Text(
                strings.translateLegacy('英文'),
                style: SelahTypography.labelSmall(
                  color: SelahColors.textTertiary,
                ),
              ),
              const SizedBox(height: 8),
              Text(sentence.target, style: SelahTypography.headlineLarge()),
              if (sentence.breakdown.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  strings.translateLegacy('拆解'),
                  style: SelahTypography.labelLarge(),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: sentence.breakdown
                      .map((item) => _BreakdownChip(item: item))
                      .toList(),
                ),
              ],
            ],
            const SizedBox(height: 26),
            _PlaybackControls(
              controller: controller,
              sentence: sentence,
              playing: playing,
              position: position,
              duration: duration,
              cacheToken:
                  '${controller.playback['state']}:${controller.playback['key'] ?? ''}',
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaybackControls extends StatelessWidget {
  const _PlaybackControls({
    required this.controller,
    required this.sentence,
    required this.playing,
    required this.position,
    required this.duration,
    required this.cacheToken,
  });

  final LearningController controller;
  final LearnSentence sentence;
  final bool playing;
  final double position;
  final double duration;
  final String cacheToken;

  @override
  Widget build(BuildContext context) {
    final strings = SelahStrings.of(controller.uiLocale);
    return Column(
      children: [
        Row(
          children: [
            Text(
              _formatDuration(position),
              style: SelahTypography.labelSmall(
                color: SelahColors.textTertiary,
              ),
            ),
            Expanded(
              child: Semantics(
                label: strings.translateLegacy('音频进度'),
                child: Slider(
                  value: position.clamp(0, duration),
                  max: duration > 0 ? duration : 1.0,
                  onChanged: duration > 0
                      ? (value) => controller.seek(value)
                      : null,
                ),
              ),
            ),
            Text(
              _formatDuration(duration),
              style: SelahTypography.labelSmall(
                color: SelahColors.textTertiary,
              ),
            ),
          ],
        ),
        Row(
          children: [
            FilledButton.icon(
              onPressed: controller.busy
                  ? null
                  : () async {
                      controller.clearMessage();
                      if (controller.isPlaybackFor(sentence) &&
                          (playing ||
                              controller.playback['state'] == 'paused')) {
                        await controller.togglePlayback();
                      } else {
                        await controller.play(sentence);
                      }
                    },
              icon: Icon(
                playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 20,
              ),
              label: Text(strings.translateLegacy(playing ? '暂停' : '播放')),
            ),
            const SizedBox(width: 9),
            IconButton(
              tooltip: strings.translateLegacy('重新播放'),
              onPressed: controller.busy
                  ? null
                  : () => controller.play(sentence),
              icon: const Icon(Icons.replay_rounded),
            ),
            const Spacer(),
            _CacheStatus(
              controller: controller,
              sentence: sentence,
              refreshToken: cacheToken,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              strings.translateLegacy('语速'),
              style: SelahTypography.labelSmall(
                color: SelahColors.textTertiary,
              ),
            ),
            const SizedBox(width: 8),
            ...[.7, .85, 1.0, 1.2].map((speed) {
              final selected = controller.state.preferences.speed == speed;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text('${speed}x'),
                  selected: selected,
                  onSelected: (_) => controller.updatePreferences(speed: speed),
                  visualDensity: VisualDensity.compact,
                ),
              );
            }),
          ],
        ),
      ],
    );
  }
}

class _PracticePage extends StatefulWidget {
  const _PracticePage({required this.controller, super.key});

  final LearningController controller;

  @override
  State<_PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<_PracticePage> {
  LearnSentence? _selected;
  bool _revealed = false;
  String? _pendingSignal;

  LearningController get c => widget.controller;

  void _openSentence(LearnSentence? sentence) {
    setState(() {
      _selected = sentence;
      _revealed = false;
      _pendingSignal = null;
    });
  }

  void _rate(String signal) {
    final sentence = _selected ?? (c.due.isEmpty ? null : c.due.first);
    if (sentence == null || !_revealed || c.busy) return;
    setState(() {
      _selected = sentence;
      _pendingSignal = signal;
    });
  }

  Future<void> _commitAndAdvance({bool complete = false}) async {
    final sentence = _selected;
    final signal = _pendingSignal;
    if (sentence == null || signal == null) return;
    c.clearMessage();
    c.stagePracticeRating(sentence, signal);
    await c.commitPracticeRating();
    if (!mounted || c.error != null) return;
    if (complete) {
      _openSentence(null);
      return;
    }
    final remaining = c.due.where((item) => item.id != sentence.id).toList();
    _openSentence(remaining.isEmpty ? null : remaining.first);
  }

  void _undoRating() {
    c.clearPendingPracticeRating();
    setState(() => _pendingSignal = null);
  }

  @override
  Widget build(BuildContext context) {
    final strings = SelahStrings.of(c.uiLocale);
    final due = c.due;
    final selected =
        _selected != null &&
            c.state.sentences.any((sentence) => sentence.id == _selected!.id)
        ? c.state.sentences.firstWhere(
            (sentence) => sentence.id == _selected!.id,
          )
        : null;
    if (due.isEmpty && selected == null) {
      final learned = c.state.sentences
          .where(
            (sentence) => !sentence.archived && sentence.listenedAt != null,
          )
          .toList();
      return _PageFrame(
        maxWidth: 760,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.translateLegacy('练习会在合适的时候回来'),
              style: SelahTypography.displayMedium(),
            ),
            const SizedBox(height: 7),
            Text(
              strings.translateLegacy('现在没有到期句子。你可以复习已经听过的表达，让它们更熟悉。'),
              style: SelahTypography.bodyMedium(),
            ),
            const SizedBox(height: 22),
            _EmptyState(
              icon: Icons.wb_twilight_outlined,
              title: strings.translateLegacy('今天的复习完成了'),
              message: learned.isEmpty
                  ? strings.translateLegacy('先去聆听一句，明天它会回来。')
                  : strings.translateLegacy('挑一句已经听过的内容，随时温习。'),
              actionLabel: learned.isEmpty
                  ? strings.translateLegacy('去聆听')
                  : strings.translateLegacy('挑一句复习'),
              onAction: learned.isEmpty
                  ? () => c.navigate(1)
                  : () {
                      setState(() {
                        _selected = learned.first;
                        _revealed = false;
                      });
                    },
            ),
            if (learned.isNotEmpty) ...[
              const SizedBox(height: 16),
              _LearnedPicker(
                sentences: learned,
                onSelect: (sentence) => setState(() {
                  _selected = sentence;
                  _revealed = false;
                }),
              ),
            ],
          ],
        ),
      );
    }
    final current = selected ?? (due.isNotEmpty ? due.first : null);
    if (current == null) return const SizedBox.shrink();
    return _PageFrame(
      maxWidth: 760,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.translateLegacy('练习时刻'),
                      style: SelahTypography.displayMedium(),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      strings.locale == 'ja'
                          ? '${due.length}文が待っています。自分のペースで。'
                          : strings.locale == 'zh-Hant'
                          ? '${due.length} 句在等你，按自己的節奏來。'
                          : '${due.length} 句在等你，按自己的节奏来。',
                      style: SelahTypography.bodyMedium(),
                    ),
                  ],
                ),
              ),
              _CountBadge(value: due.length),
            ],
          ),
          const SizedBox(height: 22),
          _PracticeCard(
            controller: c,
            sentence: current,
            revealed: _revealed,
            pendingSignal: c.pendingPracticeSentenceId == current.id
                ? (c.pendingPracticeSignal ?? _pendingSignal)
                : _pendingSignal,
            onReveal: () => setState(() => _revealed = true),
            onRate: _rate,
            onUndo: _undoRating,
            onCommit: () => _commitAndAdvance(),
            onComplete: () => _commitAndAdvance(complete: true),
          ),
          if (due.length > 1) ...[
            const SizedBox(height: 20),
            Text(
              strings.translateLegacy('接下来'),
              style: SelahTypography.labelLarge(),
            ),
            const SizedBox(height: 9),
            _LearnedPicker(
              sentences: due
                  .where((sentence) => sentence.id != current.id)
                  .toList(),
              onSelect: (sentence) => setState(() {
                _selected = sentence;
                _revealed = false;
              }),
            ),
          ],
        ],
      ),
    );
  }
}

class _PracticeCard extends StatelessWidget {
  const _PracticeCard({
    required this.controller,
    required this.sentence,
    required this.revealed,
    required this.pendingSignal,
    required this.onReveal,
    required this.onRate,
    required this.onUndo,
    required this.onCommit,
    required this.onComplete,
  });

  final LearningController controller;
  final LearnSentence sentence;
  final bool revealed;
  final String? pendingSignal;
  final VoidCallback onReveal;
  final ValueChanged<String> onRate;
  final VoidCallback onUndo;
  final VoidCallback onCommit;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final strings = SelahStrings.of(controller.uiLocale);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Row(
              children: [
                _CategoryPill(category: sentence.category),
                const Spacer(),
                _ReviewStatePill(state: sentence.reviewState),
              ],
            ),
            const SizedBox(height: 36),
            Text(
              strings.translateLegacy('回想一下英文'),
              style: SelahTypography.labelSmall(
                color: SelahColors.textTertiary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              sentence.source,
              textAlign: TextAlign.center,
              style: SelahTypography.displayMedium(),
            ),
            const SizedBox(height: 28),
            if (!revealed)
              OutlinedButton.icon(
                onPressed: onReveal,
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: Text(strings.translateLegacy('揭示答案')),
              )
            else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: SelahColors.lavenderSoft,
                  borderRadius: BorderRadius.circular(SelahCornerRadius.md),
                ),
                child: Text(
                  sentence.target,
                  textAlign: TextAlign.center,
                  style: SelahTypography.headlineLarge(),
                ),
              ),
              const SizedBox(height: 23),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  strings.translateLegacy('这次感觉怎么样？'),
                  style: SelahTypography.labelLarge(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _RatingButton(
                      signal: 'clear',
                      title: strings.locale == 'ja'
                          ? '順調'
                          : strings.locale == 'zh-Hant'
                          ? '很順'
                          : '很顺',
                      subtitle: strings.locale == 'ja'
                          ? '次は長く'
                          : strings.locale == 'zh-Hant'
                          ? '下次更久'
                          : '下次更久',
                      icon: Icons.wb_sunny_outlined,
                      color: SelahColors.sage,
                      selected: pendingSignal == 'clear',
                      onTap: controller.busy ? null : () => onRate('clear'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _RatingButton(
                      signal: 'almost',
                      title: strings.translateLegacy('差一点'),
                      subtitle: strings.translateLegacy('明天再见'),
                      icon: Icons.wb_twilight_outlined,
                      color: SelahColors.amber,
                      selected: pendingSignal == 'almost',
                      onTap: controller.busy ? null : () => onRate('almost'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _RatingButton(
                      signal: 'failed',
                      title: strings.translateLegacy('没想起'),
                      subtitle: strings.translateLegacy('很快回来'),
                      icon: Icons.favorite_border_rounded,
                      color: SelahColors.coral,
                      selected: pendingSignal == 'failed',
                      onTap: controller.busy ? null : () => onRate('failed'),
                    ),
                  ),
                ],
              ),
              if (pendingSignal != null) ...[
                const SizedBox(height: 14),
                Text(
                  strings.translateLegacy('自评还没有保存。确认后才会计入学习进度。'),
                  style: SelahTypography.bodySmall(
                    color: SelahColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: controller.busy ? null : onUndo,
                      child: Text(strings.translateLegacy('撤销')),
                    ),
                    FilledButton(
                      onPressed: controller.busy ? null : onCommit,
                      child: Text(strings.text('common.next')),
                    ),
                    FilledButton.tonal(
                      onPressed: controller.busy ? null : onComplete,
                      child: Text(strings.translateLegacy('完成并保存')),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _RatingButton extends StatelessWidget {
  const _RatingButton({
    required this.signal,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.selected = false,
    required this.onTap,
  });

  final String signal;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title，$subtitle',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SelahCornerRadius.md),
        child: Container(
          constraints: const BoxConstraints(minHeight: 82),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 11),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .09),
            borderRadius: BorderRadius.circular(SelahCornerRadius.md),
            border: Border.all(color: color.withValues(alpha: .25)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 5),
              Text(
                title,
                style: SelahTypography.labelLarge(
                  color: SelahColors.textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: SelahTypography.labelSmall(
                  color: SelahColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LearnedPicker extends StatelessWidget {
  const _LearnedPicker({required this.sentences, required this.onSelect});

  final List<LearnSentence> sentences;
  final ValueChanged<LearnSentence> onSelect;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: sentences
            .take(8)
            .map(
              (sentence) => ListTile(
                dense: true,
                leading: const Icon(
                  Icons.replay_rounded,
                  size: 18,
                  color: SelahColors.lavender,
                ),
                title: Text(
                  sentence.source,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right_rounded, size: 19),
                onTap: () => onSelect(sentence),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _NotesPage extends StatefulWidget {
  const _NotesPage({required this.controller, super.key});

  final LearningController controller;

  @override
  State<_NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<_NotesPage> {
  final _search = TextEditingController();
  String _category = 'all';
  final Set<String> _expandedIds = <String>{};
  String? _activeVocabularyId;
  late String _sessionAccountId;

  LearningController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _sessionAccountId = c.accountId;
    c.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (!mounted || c.accountId == _sessionAccountId) return;
    _sessionAccountId = c.accountId;
    _search.clear();
    setState(() {
      _category = 'all';
      _expandedIds.clear();
      _activeVocabularyId = null;
    });
  }

  @override
  void dispose() {
    c.removeListener(_onControllerChanged);
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = SelahStrings.of(c.uiLocale);
    final query = _search.text.trim().toLowerCase();
    final sentences = c.state.sentences.where((sentence) {
      if (sentence.archived) return false;
      if (_category != 'all' && sentence.category != _category) return false;
      if (query.isEmpty) return true;
      return '${sentence.source} ${sentence.target}'.toLowerCase().contains(
        query,
      );
    }).toList();
    return _PageFrame(
      maxWidth: 980,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.translateLegacy('把学过的留下来'),
            style: SelahTypography.displayMedium(),
          ),
          const SizedBox(height: 7),
          Text(
            strings.text('notes.subtitle'),
            style: SelahTypography.bodyMedium(),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: strings.translateLegacy('搜索中文或英文'),
              suffixIcon: Icon(Icons.tune_rounded),
            ),
          ),
          const SizedBox(height: 11),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _FilterChip(
                  label: strings.translateLegacy('全部'),
                  selected: _category == 'all',
                  onTap: () => setState(() => _category = 'all'),
                ),
                ...categories.entries.map(
                  (entry) => _FilterChip(
                    label: strings.categoryLabel(entry.key),
                    selected: _category == entry.key,
                    onTap: () => setState(() => _category = entry.key),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (sentences.isEmpty)
            _EmptyState(
              icon: Icons.menu_book_outlined,
              title: query.isEmpty
                  ? strings.translateLegacy('还没有笔记')
                  : strings.translateLegacy('没有匹配的句子'),
              message: query.isEmpty
                  ? strings.translateLegacy('完成一次生成或导入备份，句子会在这里安静地保存。')
                  : strings.translateLegacy('试试换个词，或清除分类筛选。'),
              actionLabel: query.isEmpty
                  ? strings.translateLegacy('去 Today 写一句')
                  : strings.translateLegacy('显示全部'),
              onAction: query.isEmpty
                  ? () => c.navigate(0)
                  : () => setState(() {
                      _search.clear();
                      _category = 'all';
                    }),
            ),
          if (sentences.isNotEmpty)
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  children: sentences
                      .map(
                        (sentence) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _NotesCard(
                            controller: c,
                            sentence: sentence,
                            expanded: _expandedIds.contains(sentence.id),
                            activeVocabularyId: _activeVocabularyId,
                            onToggleExpanded: () => setState(() {
                              if (_expandedIds.contains(sentence.id)) {
                                _expandedIds.remove(sentence.id);
                              } else {
                                _expandedIds.add(sentence.id);
                              }
                            }),
                            onVocabularyTap: (entry) => setState(() {
                              final key = _vocabularyKey(sentence, entry);
                              _activeVocabularyId = _activeVocabularyId == key
                                  ? null
                                  : key;
                            }),
                            onCloseVocabulary: () =>
                                setState(() => _activeVocabularyId = null),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          if (_growthMemoriesUiEnabled) ...[
            const SizedBox(height: 26),
            _MemoriesCard(controller: c),
          ],
        ],
      ),
    );
  }
}

String _vocabularyKey(LearnSentence sentence, VocabularyEntry entry) =>
    '${sentence.id}:${entry.id}';

VocabularyEntry? featuredVocabulary(LearnSentence sentence) =>
    sentence.vocabulary.isEmpty ? null : sentence.vocabulary.first;

class VocabularySpan {
  const VocabularySpan({
    required this.start,
    required this.end,
    required this.entry,
  });

  final int start;
  final int end;
  final VocabularyEntry entry;
}

List<VocabularySpan> vocabularySpans(
  String target,
  List<VocabularyEntry> vocabulary,
) {
  final candidates = <VocabularySpan>[];
  final ordered = vocabulary.asMap().entries.toList()
    ..sort((a, b) {
      final length = b.value.text.length.compareTo(a.value.text.length);
      return length == 0 ? a.key.compareTo(b.key) : length;
    });
  for (final candidate in ordered) {
    final text = candidate.value.text.trim();
    if (text.isEmpty) continue;
    final match = RegExp(
      RegExp.escape(text),
      caseSensitive: false,
    ).firstMatch(target);
    if (match == null) continue;
    final span = VocabularySpan(
      start: match.start,
      end: match.end,
      entry: candidate.value,
    );
    final overlaps = candidates.any(
      (existing) => span.start < existing.end && existing.start < span.end,
    );
    if (!overlaps) candidates.add(span);
  }
  candidates.sort((a, b) => a.start.compareTo(b.start));
  return candidates;
}

class _NotesCard extends StatelessWidget {
  const _NotesCard({
    required this.controller,
    required this.sentence,
    required this.expanded,
    required this.activeVocabularyId,
    required this.onToggleExpanded,
    required this.onVocabularyTap,
    required this.onCloseVocabulary,
  });

  final LearningController controller;
  final LearnSentence sentence;
  final bool expanded;
  final String? activeVocabularyId;
  final VoidCallback onToggleExpanded;
  final ValueChanged<VocabularyEntry> onVocabularyTap;
  final VoidCallback onCloseVocabulary;

  @override
  Widget build(BuildContext context) {
    final strings = SelahStrings.of(controller.uiLocale);
    final featured = featuredVocabulary(sentence);
    final canExpand =
        sentence.breakdown.isNotEmpty || sentence.vocabulary.isNotEmpty;
    final activeEntry = sentence.vocabulary
        .where((entry) => activeVocabularyId == _vocabularyKey(sentence, entry))
        .firstOrNull;
    final featuredIsActive = featured != null && activeEntry == featured;
    final targetStyle = SelahTypography.headlineLarge();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _CategoryPill(category: sentence.category),
                _ReviewStatePill(state: sentence.reviewState),
              ],
            ),
            const SizedBox(height: 16),
            Text(sentence.source, style: SelahTypography.bodyLarge()),
            const SizedBox(height: 8),
            _VocabularyTargetText(
              target: sentence.target,
              vocabulary: sentence.vocabulary,
              style: targetStyle,
              onVocabularyTap: onVocabularyTap,
            ),
            if (featured != null) ...[
              const SizedBox(height: 14),
              Semantics(
                button: true,
                label: '${strings.text('notes.featured')}：${featured.text}',
                child: Material(
                  color: SelahColors.lavenderSoft,
                  borderRadius: BorderRadius.circular(SelahCornerRadius.sm),
                  child: InkWell(
                    onTap: () => onVocabularyTap(featured),
                    borderRadius: BorderRadius.circular(SelahCornerRadius.sm),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.auto_awesome_outlined,
                            size: 16,
                            color: SelahColors.lavender,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: '${strings.text('notes.featured')}  ',
                                    style: SelahTypography.labelLarge(
                                      color: SelahColors.lavender,
                                    ),
                                  ),
                                  TextSpan(
                                    text:
                                        '${featured.text} · ${featured.meaning}',
                                    style: SelahTypography.bodySmall(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Icon(
                            featuredIsActive
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.chevron_right_rounded,
                            size: 20,
                            color: SelahColors.lavender,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
            if (activeEntry != null)
              _VocabularyPanel(
                controller: controller,
                sentence: sentence,
                entry: activeEntry,
                onClose: onCloseVocabulary,
              ),
            if (expanded) ...[
              const SizedBox(height: 18),
              const Divider(height: 1),
              const SizedBox(height: 16),
              if (sentence.breakdown.isNotEmpty) ...[
                Text(
                  strings.translateLegacy('句子拆解'),
                  style: SelahTypography.labelLarge(),
                ),
                const SizedBox(height: 10),
                ...sentence.breakdown.map((item) => _BreakdownLine(item: item)),
              ],
              if (sentence.vocabulary.isNotEmpty) ...[
                if (sentence.breakdown.isNotEmpty) const SizedBox(height: 8),
                Text(
                  strings.translateLegacy('词汇掌握'),
                  style: SelahTypography.labelLarge(),
                ),
                const SizedBox(height: 8),
                ...sentence.vocabulary.map(
                  (entry) => _NotesVocabularyRow(
                    entry: entry,
                    controller: controller,
                    onTap: () => onVocabularyTap(entry),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: controller.busy
                    ? null
                    : () async {
                        controller.clearMessage();
                        await controller.markPreviewed([sentence]);
                      },
                icon: const Icon(Icons.nightlight_outlined, size: 17),
                label: Text(
                  strings.translateLegacy(
                    sentence.previewedAt == null ? '标记夜间预览' : '已预览',
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () {
                    controller.selectSentence(sentence);
                    controller.navigate(1);
                  },
                  icon: const Icon(Icons.headphones_rounded, size: 18),
                  label: Text(strings.text('notes.listen')),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    controller.selectSentence(sentence);
                    controller.navigate(2);
                  },
                  icon: const Icon(Icons.record_voice_over_outlined, size: 18),
                  label: Text(strings.text('notes.practice')),
                ),
                if (canExpand)
                  Semantics(
                    button: true,
                    expanded: expanded,
                    label: strings.text(
                      expanded ? 'notes.collapse' : 'notes.expand',
                    ),
                    child: OutlinedButton.icon(
                      onPressed: onToggleExpanded,
                      icon: Icon(
                        expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 18,
                      ),
                      label: Text(
                        strings.text(
                          expanded ? 'notes.collapse' : 'notes.expand',
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VocabularyTargetText extends StatelessWidget {
  const _VocabularyTargetText({
    required this.target,
    required this.vocabulary,
    required this.style,
    required this.onVocabularyTap,
  });

  final String target;
  final List<VocabularyEntry> vocabulary;
  final TextStyle style;
  final ValueChanged<VocabularyEntry> onVocabularyTap;

  @override
  Widget build(BuildContext context) {
    final matches = vocabularySpans(target, vocabulary);
    if (matches.isEmpty) return Text(target, style: style);
    final children = <InlineSpan>[];
    var cursor = 0;
    for (final match in matches) {
      if (match.start > cursor) {
        children.add(TextSpan(text: target.substring(cursor, match.start)));
      }
      children.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: Semantics(
            button: true,
            label: match.entry.text,
            child: InkWell(
              onTap: () => onVocabularyTap(match.entry),
              borderRadius: BorderRadius.circular(3),
              child: Container(
                padding: const EdgeInsets.only(bottom: 1),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: SelahColors.lavender, width: 1.5),
                  ),
                ),
                child: Text(
                  target.substring(match.start, match.end),
                  style: style.copyWith(color: SelahColors.lavender),
                ),
              ),
            ),
          ),
        ),
      );
      cursor = match.end;
    }
    if (cursor < target.length) {
      children.add(TextSpan(text: target.substring(cursor)));
    }
    return Semantics(
      container: true,
      label: target,
      child: RichText(
        text: TextSpan(style: style, children: children),
        softWrap: true,
      ),
    );
  }
}

class _VocabularyPanel extends StatelessWidget {
  const _VocabularyPanel({
    required this.controller,
    required this.sentence,
    required this.entry,
    required this.onClose,
  });

  final LearningController controller;
  final LearnSentence sentence;
  final VocabularyEntry entry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final strings = SelahStrings.of(controller.uiLocale);
    final next = _nextVocabularyState(entry.state);
    final nextLabel = next == 'familiar'
        ? strings.text('notes.markFamiliar')
        : strings.vocabularyLabel(next);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: SelahColors.cardSoft,
        border: Border.all(color: SelahColors.lavender.withValues(alpha: .35)),
        borderRadius: BorderRadius.circular(SelahCornerRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.text, style: SelahTypography.labelLarge()),
                    const SizedBox(height: 4),
                    Text(entry.meaning, style: SelahTypography.bodySmall()),
                  ],
                ),
              ),
              IconButton(
                tooltip: strings.text('common.close'),
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded, size: 18),
                constraints: const BoxConstraints(
                  minWidth: SelahSpacing.minTouchTarget,
                  minHeight: SelahSpacing.minTouchTarget,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _VocabularyStatePill(
                label: strings.vocabularyLabel(entry.state),
                state: entry.state,
              ),
              OutlinedButton(
                onPressed: controller.busy
                    ? null
                    : () async {
                        controller.clearMessage();
                        await controller.setVocabularyState(
                          sentence,
                          entry,
                          next,
                          expectedState: entry.state,
                        );
                      },
                child: Text(nextLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _nextVocabularyState(String state) =>
    state == 'owned' ? 'new' : (state == 'familiar' ? 'owned' : 'familiar');

class _VocabularyStatePill extends StatelessWidget {
  const _VocabularyStatePill({required this.label, required this.state});

  final String label;
  final String state;

  @override
  Widget build(BuildContext context) {
    final color = _vocabColor(state);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(SelahCornerRadius.pill),
      ),
      child: Text(label, style: SelahTypography.labelSmall(color: color)),
    );
  }
}

class _NotesVocabularyRow extends StatelessWidget {
  const _NotesVocabularyRow({
    required this.entry,
    required this.controller,
    required this.onTap,
  });

  final VocabularyEntry entry;
  final LearningController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final strings = SelahStrings.of(controller.uiLocale);
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Semantics(
        button: true,
        label: '${entry.text}：${strings.vocabularyLabel(entry.state)}',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(SelahCornerRadius.sm),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: SelahSpacing.minTouchTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.text, style: SelahTypography.labelLarge()),
                        const SizedBox(height: 2),
                        Text(entry.meaning, style: SelahTypography.bodySmall()),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _VocabularyStatePill(
                    label: strings.vocabularyLabel(entry.state),
                    state: entry.state,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MemoriesCard extends StatelessWidget {
  const _MemoriesCard({required this.controller});

  final LearningController controller;

  @override
  Widget build(BuildContext context) {
    final strings = SelahStrings.of(controller.uiLocale);
    final keys = controller.state.memories.keys
        .where(memoryTitles.containsKey)
        .toList();
    return Card(
      color: SelahColors.roseSoft,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.auto_awesome_outlined,
                  size: 19,
                  color: SelahColors.rose,
                ),
                const SizedBox(width: 8),
                Text(
                  strings.translateLegacy('成长回忆'),
                  style: SelahTypography.headlineMedium(),
                ),
                const Spacer(),
                Text(
                  '${keys.length} / ${memoryTitles.length}',
                  style: SelahTypography.labelSmall(
                    color: SelahColors.textTertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              keys.isEmpty
                  ? strings.translateLegacy('每一次真实的聆听和练习，都会让这里多一小段故事。')
                  : strings.memorySubtitle(keys.last),
              style: SelahTypography.bodySmall(),
            ),
            if (keys.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: keys
                    .map(
                      (key) => Chip(
                        label: Text(strings.memoryTitle(key)),
                        avatar: const Icon(
                          Icons.check_rounded,
                          size: 15,
                          color: SelahColors.sage,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: () => _showMemories(context, controller),
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: Text(strings.translateLegacy('打开回忆册')),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsPage extends StatefulWidget {
  const _SettingsPage({required this.controller, super.key});

  final LearningController controller;

  @override
  State<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<_SettingsPage> {
  late final TextEditingController _name;

  LearningController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: c.state.preferences.name);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    c.clearMessage();
    await c.updatePreferences(name: name);
  }

  Future<void> _pickReminderTime() async {
    final current = _parseTime(c.state.preferences.reminderTime);
    final picked = await showTimePicker(context: context, initialTime: current);
    if (picked == null) return;
    final time =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    c.clearMessage();
    await c.updatePreferences(reminderTime: time);
  }

  @override
  Widget build(BuildContext context) {
    final p = c.state.preferences;
    final platform = c.platformInfo;
    final s = SelahStrings.of(c.uiLocale);
    final installKind = platform['installKind'] is String
        ? platform['installKind'] as String
        : platform['installed'] == true
        ? 'installed'
        : platform['canInstall'] == true
        ? 'prompt'
        : 'unsupported';
    final storagePersisted = platform['storagePersisted'];
    final buildId = platform['buildId']?.toString() ?? 'dev';
    return _PageFrame(
      maxWidth: 760,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.text('settings.title'),
            style: SelahTypography.displayMedium(),
          ),
          const SizedBox(height: 7),
          Text(
            s.text('settings.subtitle'),
            style: SelahTypography.bodyMedium(),
          ),
          const SizedBox(height: 20),
          _SettingsSection(
            title: s.languageTitle(),
            icon: Icons.translate_rounded,
            children: [
              Text(
                s.nativeLanguageLabel(),
                style: SelahTypography.bodyMedium(),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: supportedNativeLanguages.map((language) {
                  return ChoiceChip(
                    label: Text(s.languageLabel(language)),
                    selected: p.nativeLanguage == language,
                    onSelected: c.busy
                        ? null
                        : (_) => c.updatePreferences(nativeLanguage: language),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Text(
                s.text('settings.language.nativeMergedDetail'),
                style: SelahTypography.bodySmall(
                  color: SelahColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                s.text('settings.language.learning'),
                style: SelahTypography.bodyMedium(),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ChoiceChip(
                    label: Text(s.learningLanguageValue()),
                    selected: true,
                    onSelected: c.busy ? null : (_) {},
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ChoiceChip(
                        label: Text(s.text('language.ja')),
                        selected: false,
                        onSelected: null,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        s.text('settings.language.comingSoon'),
                        style: SelahTypography.bodySmall(
                          color: SelahColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(s.nativeHint(p.nativeLanguage)),
            ],
          ),
          const SizedBox(height: 14),
          _SettingsSection(
            title: s.text('settings.companion'),
            icon: Icons.spa_outlined,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _name,
                      maxLength: 24,
                      decoration: InputDecoration(
                        labelText: s.text('settings.name'),
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: c.busy ? null : _saveName,
                    child: Text(s.text('settings.save')),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(s.text('settings.companion.rail')),
                subtitle: Text(
                  s.text('settings.companion.railDetail'),
                  style: SelahTypography.bodySmall(),
                ),
                value: p.companionRailVisible,
                onChanged: c.busy
                    ? null
                    : (value) => c.updatePreferences(
                          companionRailVisible: value,
                        ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                key: ValueKey(p.voice),
                initialValue: voices.containsKey(p.voice)
                    ? p.voice
                    : voices.keys.first,
                decoration: InputDecoration(
                  labelText: s.text('settings.voice'),
                ),
                items: voices.entries
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(s.voiceLabel(entry.key)),
                      ),
                    )
                    .toList(),
                onChanged: c.busy
                    ? null
                    : (value) {
                        if (value != null) c.updatePreferences(voice: value);
                      },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                key: ValueKey(p.nativeVoice),
                initialValue: nativeVoices.containsKey(p.nativeVoice)
                    ? p.nativeVoice
                    : nativeVoices.keys.first,
                decoration: InputDecoration(
                  labelText: s.text('settings.nativeVoice'),
                ),
                items: nativeVoices.entries
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(s.nativeVoiceLabel(entry.key)),
                      ),
                    )
                    .toList(),
                onChanged: c.busy
                    ? null
                    : (value) {
                        if (value != null) {
                          c.updatePreferences(nativeVoice: value);
                        }
                      },
              ),
              const SizedBox(height: 8),
              Text(
                s.text('settings.nativeVoice.detail'),
                style: SelahTypography.bodySmall(
                  color: SelahColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    s.text('settings.speed'),
                    style: SelahTypography.bodyMedium(),
                  ),
                  ...[.7, .85, 1.0, 1.2].map(
                    (speed) => Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: ChoiceChip(
                        label: Text('${speed}x'),
                        selected: p.speed == speed,
                        onSelected: (_) => c.updatePreferences(speed: speed),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SettingsSection(
            title: s.text('settings.reminder'),
            icon: Icons.notifications_none_rounded,
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(s.text('settings.foregroundReminder')),
                subtitle: Text(
                  s.text('settings.reminder.background'),
                  style: SelahTypography.bodySmall(),
                ),
                value: p.reminderEnabled,
                onChanged: c.busy
                    ? null
                    : (value) => c.updatePreferences(reminderEnabled: value),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(s.text('settings.reminderTime')),
                subtitle: Text(p.reminderTime),
                trailing: const Icon(Icons.schedule_rounded, size: 20),
                onTap: p.reminderEnabled ? _pickReminderTime : null,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SettingsSection(
            title: s.text('settings.account'),
            icon: Icons.cloud_outlined,
            children: [
              if (c.hasSession && c.isAnonymous) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.translateLegacy('测试访客')),
                  subtitle: Text(
                    s.translateLegacy(
                      '正在免登录测试云端学习，资料主要保存在当前浏览器。',
                    ),
                  ),
                  leading: const Icon(
                    Icons.science_outlined,
                    color: SelahColors.amber,
                  ),
                  trailing: TextButton(
                    onPressed: c.busy ? null : () => _showAuth(context, c),
                    child: Text(s.translateLegacy('注册／登录')),
                  ),
                ),
              ] else if (c.hasSession) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(c.email ?? s.translateLegacy('已登录')),
                  subtitle: Text(s.translateLegacy('学习记录会按账户同步')),
                  leading: const Icon(
                    Icons.verified_user_outlined,
                    color: SelahColors.sage,
                  ),
                  trailing: TextButton(
                    onPressed: c.busy
                        ? null
                        : () async {
                            c.clearMessage();
                            await c.logout();
                          },
                    child: Text(s.translateLegacy('退出')),
                  ),
                ),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: c.syncing
                          ? null
                          : () async {
                              c.clearMessage();
                              await c.sync();
                            },
                      icon: const Icon(Icons.sync_rounded, size: 17),
                      label: Text(
                        s.translateLegacy(c.syncing ? '同步中…' : '立即同步'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        c.state.lastSyncAt == null
                            ? s.translateLegacy('还没有同步记录')
                            : '${s.translateLegacy('上次同步：')}${_formatDate(c.state.lastSyncAt!)}',
                        style: SelahTypography.bodySmall(),
                      ),
                    ),
                  ],
                ),
              ] else if (!c.configured)
                _InfoBox(
                  icon: Icons.cloud_off_outlined,
                  color: SelahColors.amber,
                  text: s.translateLegacy('当前部署还没有连接云端配置。你可以继续在本机学习。'),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.translateLegacy('登录后可在不同设备继续学习。'),
                        style: SelahTypography.bodyMedium(),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: c.busy ? null : () => _showAuth(context, c),
                      child: Text(s.translateLegacy('登录／注册')),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: c.busy
                    ? null
                    : () async {
                        c.clearMessage();
                        await c.importGuest();
                      },
                icon: const Icon(Icons.download_for_offline_outlined, size: 18),
                label: Text(s.translateLegacy('导入本机学习记录')),
              ),
            ],
          ),
          if (c.membership.membershipModeEnabled && !c.isAnonymous) ...[
            const SizedBox(height: 14),
            _SettingsSection(
              title: s.translateLegacy('会员与方案'),
              icon: Icons.workspace_premium_outlined,
              children: [
                MembershipCenter(
                  controller: c.membership,
                  uiLocale: c.uiLocale,
                ),
              ],
            ),
          ],
          if (c.hasSession && !c.isAnonymous) ...[
            const SizedBox(height: 14),
            _SettingsSection(
              title: s.translateLegacy('关于你的学习'),
              icon: Icons.person_outline_rounded,
              children: [
                ResearchProfileEntry(
                  controller: c.researchProfile,
                  uiLocale: c.uiLocale,
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          _SettingsSection(
            title: s.text('settings.backup'),
            icon: Icons.inventory_2_outlined,
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: c.busy
                          ? null
                          : () async {
                              c.clearMessage();
                              await c.exportBackup();
                            },
                      icon: const Icon(Icons.file_upload_outlined, size: 17),
                      label: Text(s.text('settings.export')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: c.busy
                          ? null
                          : () async {
                              c.clearMessage();
                              await c.importBackup();
                            },
                      icon: const Icon(Icons.file_download_outlined, size: 17),
                      label: Text(s.text('settings.import')),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 11),
              _InfoBox(
                icon: Icons.offline_bolt_outlined,
                color: SelahColors.sage,
                text: _offlineText(platform, s),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SettingsSection(
            title: s.text('settings.device'),
            icon: Icons.devices_other_outlined,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.shield_outlined),
                title: Text(
                  storagePersisted == true
                      ? s.text('settings.protected')
                      : s.text('settings.protect'),
                ),
                subtitle: Text(
                  storagePersisted == true
                      ? s.text('settings.protectDetail')
                      : storagePersisted == false
                      ? s.text('settings.protectPending')
                      : s.text('settings.protectUnsupported'),
                ),
                trailing: storagePersisted == false
                    ? OutlinedButton(
                        onPressed: c.busy
                            ? null
                            : () async {
                                c.clearMessage();
                                await c.persistStorage();
                              },
                        child: Text(s.text('settings.protect')),
                      )
                    : null,
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.add_to_home_screen_outlined),
                title: Text(
                  installKind == 'installed'
                      ? s.text('settings.installed')
                      : s.text('settings.install'),
                ),
                subtitle: Text(switch (installKind) {
                  'installed' => s.text('settings.installDetail'),
                  'prompt' => s.text('settings.installDetail'),
                  'ios-manual' => s.text('settings.installIos'),
                  _ => s.text('settings.installUnsupported'),
                }),
                trailing: installKind == 'prompt'
                    ? OutlinedButton.icon(
                        onPressed: c.busy
                            ? null
                            : () async {
                                c.clearMessage();
                                await c.install();
                              },
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: Text(s.text('settings.install')),
                      )
                    : null,
              ),
              const Divider(height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.system_update_alt),
                title: Text(s.text('settings.version')),
                subtitle: Text(buildId),
                trailing: TextButton(
                  onPressed: c.busy
                      ? null
                      : () async {
                          c.clearMessage();
                          await c.checkForUpdates();
                        },
                  child: Text(s.text('settings.checkUpdate')),
                ),
              ),
              if (platform['updateAvailable'] == true) ...[
                const SizedBox(height: 11),
                OutlinedButton.icon(
                  onPressed: c.busy || c.recording || c.hasPendingRecording
                      ? null
                      : () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: Text(s.text('settings.update')),
                              content: Text(s.text('settings.updateConfirm')),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(dialogContext, false),
                                  child: Text(s.text('settings.updateLater')),
                                ),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.pop(dialogContext, true),
                                  child: Text(s.text('settings.updateNow')),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true) await c.applyUpdate();
                        },
                  icon: const Icon(Icons.system_update_alt, size: 18),
                  label: Text(s.text('settings.update')),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 19, color: SelahColors.coral),
                const SizedBox(width: 8),
                Text(title, style: SelahTypography.headlineMedium()),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatefulWidget {
  const _OnboardingPage({required this.controller});

  final LearningController controller;

  @override
  State<_OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<_OnboardingPage> {
  late final TextEditingController _name;
  final _selected = <String>{};

  LearningController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    final current = c.state.preferences.name;
    _name = TextEditingController(text: current == '小豆' ? '' : current);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    final name = _name.text.trim();
    if (c.busy || name.isEmpty || _selected.length < minOnboardingSeedCount) {
      return;
    }
    FocusScope.of(context).unfocus();
    c.clearMessage();
    await c.onboard(name, _selected.toList());
  }

  @override
  Widget build(BuildContext context) {
    final s = c.strings;
    return Scaffold(
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (c.error != null || c.notice != null) ...[
            SizedBox(
              width: (MediaQuery.sizeOf(context).width - 32).clamp(0.0, 360.0),
              child: _MessageBar(controller: c),
            ),
            const SizedBox(height: 12),
          ],
          Material(
            color: SelahColors.cardSoft,
            elevation: 6,
            shadowColor: SelahColors.textPrimary.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(48),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 22, 10),
              child: SizedBox(
                width: 192,
                child: WebStartAction(
                  selectedCount: _selected.length,
                  hasName: _name.text.trim().isNotEmpty,
                  busy: c.busy,
                  onStart: _complete,
                  uiLocale: c.uiLocale,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide =
                constraints.maxWidth >= 960 && constraints.maxHeight >= 500;
            final content = SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                wide ? 40 : 20,
                26,
                wide ? 40 : 20,
                148,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (wide)
                      const _BrandMark(size: 42)
                    else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _BrandMark(size: 42),
                          PlushCompanion(
                            size: 78,
                            decorationStage: DecorationStage.none,
                            uiLocale: c.uiLocale,
                          ),
                        ],
                      ),
                    const SizedBox(height: 20),
                    Text(
                      s.text('onboarding.title'),
                      style: SelahTypography.displayLarge(),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      s.text('onboarding.description'),
                      style: SelahTypography.bodyLarge(),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _name,
                      onChanged: (_) => setState(() {}),
                      enabled: !c.busy,
                      maxLength: 24,
                      decoration: InputDecoration(
                        labelText: s.text('onboarding.nameLabel'),
                        hintText: s.text('onboarding.nameHint'),
                        prefixIcon: Icon(Icons.spa_outlined),
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 25),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            s.text('onboarding.selectTitle'),
                            style: SelahTypography.headlineMedium(),
                          ),
                        ),
                        TextButton(
                          onPressed: c.busy ||
                                  c.seeds.length < minOnboardingSeedCount
                              ? null
                              : () => setState(() {
                                  _selected
                                    ..clear()
                                    ..addAll(
                                      c.seeds
                                          .where(
                                            (seed) =>
                                                recommendedOnboardingSeedIds
                                                    .contains(seed.seedId),
                                          )
                                          .take(minOnboardingSeedCount)
                                          .map((seed) => seed.seedId!),
                                    );
                                  if (_selected.length < minOnboardingSeedCount) {
                                    _selected
                                      ..clear()
                                      ..addAll(
                                        c.seeds
                                            .take(minOnboardingSeedCount)
                                            .map((seed) => seed.seedId!),
                                      );
                                  }
                                }),
                          child: Text(s.text('onboarding.recommend')),
                        ),
                        Text(
                          s.message('onboarding.selectedCount', {
                            'count': '${_selected.length}',
                          }),
                          style: SelahTypography.labelLarge(
                            color: _selected.length >= minOnboardingSeedCount
                                ? SelahColors.sage
                                : SelahColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      s.text('onboarding.seedHint'),
                      style: SelahTypography.bodySmall(),
                    ),
                    const SizedBox(height: 13),
                    if (c.seeds.isEmpty)
                      _EmptyState(
                        icon: Icons.eco_outlined,
                        title: s.text('onboarding.seedsPreparing'),
                        message: s.text('onboarding.tryLater'),
                      )
                    else
                      ...c.seeds.map((seed) {
                        final selected = _selected.contains(seed.seedId);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 9),
                          child: _SeedChoice(
                            seed: seed,
                            strings: s,
                            selected: selected,
                            disabled: c.busy,
                            offlineAudio: _hasBundledAudio(c, seed),
                            onTap: () => setState(() {
                              if (selected) {
                                _selected.remove(seed.seedId);
                              } else if (seed.seedId != null) {
                                _selected.add(seed.seedId!);
                              }
                            }),
                          ),
                        );
                      }),
                    const SizedBox(height: 17),
                    Text(
                      s.text('onboarding.localFirst'),
                      style: SelahTypography.bodySmall(
                        color: SelahColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            );
            if (!wide) {
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: content,
                ),
              );
            }
            return Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 640, child: content),
                  const SizedBox(width: 50),
                  Padding(
                    padding: const EdgeInsets.only(top: 125),
                    child: Column(
                      children: [
                        PlushCompanion(
                          action: SpriteActionId.gentleFloat,
                          size: 210,
                          decorationStage: DecorationStage.none,
                          uiLocale: c.uiLocale,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          s.locale == 'ja'
                              ? 'ゆっくりで大丈夫です。'
                              : s.translateLegacy('慢慢来，就很好。'),
                          style: SelahTypography.bodyMedium(
                            color: SelahColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SeedChoice extends StatelessWidget {
  const _SeedChoice({
    required this.seed,
    required this.strings,
    required this.selected,
    required this.disabled,
    required this.offlineAudio,
    required this.onTap,
  });

  final LearnSentence seed;
  final SelahStrings strings;
  final bool selected;
  final bool disabled;
  final bool offlineAudio;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      enabled: !disabled,
      label:
          '${selected ? strings.text('onboarding.selected') : strings.text('onboarding.choose')}${strings.translateLegacy('种子句')}：${seed.source}',
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(SelahCornerRadius.lg),
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : SelahMotion.quick,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? SelahColors.coralSoft : SelahColors.cardPrimary,
            borderRadius: BorderRadius.circular(SelahCornerRadius.lg),
            border: Border.all(
              color: selected
                  ? SelahColors.coral.withValues(alpha: .5)
                  : SelahColors.borderLight,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: selected ? SelahColors.coral : SelahColors.textTertiary,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(seed.source, style: SelahTypography.bodyLarge()),
                    const SizedBox(height: 3),
                    Text(
                      seed.target,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: SelahTypography.bodySmall(
                        color: SelahColors.textSecondary,
                      ),
                    ),
                    if (offlineAudio) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(
                            Icons.offline_pin_outlined,
                            size: 14,
                            color: SelahColors.sage,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            strings.text('onboarding.offlinePreview'),
                            style: SelahTypography.labelSmall(
                              color: SelahColors.sage,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              _CategoryPill(category: seed.category),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Selah',
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: SelahColors.coral,
          borderRadius: BorderRadius.circular(size * .32),
        ),
        child: Icon(Icons.spa_rounded, color: Colors.white, size: size * .56),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    final label = SelahStrings.of(
      _contextUiLocale(context),
    ).categoryLabel(categories.containsKey(category) ? category : 'daily_life');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: SelahColors.lavenderSoft,
        borderRadius: BorderRadius.circular(SelahCornerRadius.pill),
      ),
      child: Text(
        label,
        style: SelahTypography.labelSmall(color: SelahColors.lavender),
      ),
    );
  }
}

class _ReviewStatePill extends StatelessWidget {
  const _ReviewStatePill({required this.state});

  final String state;

  @override
  Widget build(BuildContext context) {
    final label = SelahStrings.of(_contextUiLocale(context)).reviewLabel(state);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: _reviewColor(state).withValues(alpha: .1),
        borderRadius: BorderRadius.circular(SelahCornerRadius.pill),
      ),
      child: Text(
        label,
        style: SelahTypography.labelSmall(color: _reviewColor(state)),
      ),
    );
  }
}

class _StagePill extends StatelessWidget {
  const _StagePill({required this.stage});

  final DecorationStage stage;

  @override
  Widget build(BuildContext context) {
    final strings = SelahStrings.of(_contextUiLocale(context));
    final label = strings.growthLabel(
      stage == DecorationStage.none ? 'none' : stage.name,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: SelahColors.sageSoft,
        borderRadius: BorderRadius.circular(SelahCornerRadius.pill),
      ),
      child: Text(
        label,
        style: SelahTypography.labelSmall(color: SelahColors.sage),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: SelahColors.coral,
        borderRadius: BorderRadius.circular(SelahCornerRadius.pill),
      ),
      child: Text(
        '$value',
        style: SelahTypography.labelSmall(color: Colors.white),
      ),
    );
  }
}

class _BreakdownChip extends StatelessWidget {
  const _BreakdownChip({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final strings = SelahStrings.of(_contextUiLocale(context));
    final surface =
        _stringValue(item, const ['surfaceText', 'surface', 'text']) ?? '';
    final explanation = _stringValue(item, const [
      'explanation',
      'meaningInContext',
      'meaning',
    ]);
    return Tooltip(
      message: explanation ?? '',
      child: Chip(
        label: Text(surface.isEmpty ? strings.translateLegacy('词组') : surface),
        backgroundColor: SelahColors.lavenderSoft,
        side: BorderSide.none,
      ),
    );
  }
}

class _BreakdownLine extends StatelessWidget {
  const _BreakdownLine({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final strings = SelahStrings.of(_contextUiLocale(context));
    final surface =
        _stringValue(item, const ['surfaceText', 'surface', 'text']) ??
        strings.translateLegacy('词组');
    final explanation =
        _stringValue(item, const [
          'explanation',
          'meaningInContext',
          'meaning',
        ]) ??
        '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 7),
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: SelahColors.lavender,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: SelahTypography.bodyMedium(),
                children: [
                  TextSpan(
                    text: '$surface  ',
                    style: SelahTypography.labelLarge(),
                  ),
                  TextSpan(text: explanation),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VocabularyRow extends StatelessWidget {
  const _VocabularyRow({
    required this.sentence,
    required this.entry,
    required this.controller,
  });

  final LearnSentence sentence;
  final VocabularyEntry entry;
  final LearningController controller;

  @override
  Widget build(BuildContext context) {
    final strings = SelahStrings.of(controller.uiLocale);
    final state = entry.state;
    final next = state == 'owned'
        ? 'new'
        : (state == 'familiar' ? 'owned' : 'familiar');
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Text(entry.text, style: SelahTypography.labelLarge())],
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label:
                '${entry.text}：${strings.vocabularyLabel(state)}，${strings.locale == 'ja'
                    ? 'タップして'
                    : strings.locale == 'zh-Hant'
                    ? '點擊標記為'
                    : '点击标记为'}${strings.vocabularyLabel(next)}',
            child: InkWell(
              onTap: controller.busy
                  ? null
                  : () => controller.setVocabularyState(sentence, entry, next),
              borderRadius: BorderRadius.circular(SelahCornerRadius.pill),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: _vocabColor(state).withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(SelahCornerRadius.pill),
                ),
                child: Text(
                  strings.vocabularyLabel(state),
                  style: SelahTypography.labelSmall(color: _vocabColor(state)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _CacheStatus extends StatefulWidget {
  const _CacheStatus({
    required this.controller,
    required this.sentence,
    required this.refreshToken,
  });

  final LearningController controller;
  final LearnSentence sentence;
  final String refreshToken;

  @override
  State<_CacheStatus> createState() => _CacheStatusState();
}

class _CacheStatusState extends State<_CacheStatus> {
  bool? _cached;
  String? _key;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(covariant _CacheStatus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sentence.id != widget.sentence.id ||
        oldWidget.refreshToken != widget.refreshToken ||
        oldWidget.controller.state.preferences.voice !=
            widget.controller.state.preferences.voice) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    final key =
        '${widget.sentence.id}:${widget.controller.state.preferences.voice}';
    _key = key;
    if (mounted) setState(() => _cached = null);
    try {
      final value = await widget.controller.isAudioCached(widget.sentence);
      if (mounted && _key == key) setState(() => _cached = value);
    } catch (_) {
      if (mounted && _key == key) setState(() => _cached = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = SelahStrings.of(widget.controller.uiLocale);
    final label = _cached == true
        ? strings.text('cache.cachedOffline')
        : (_cached == false
              ? strings.text('cache.notCached')
              : strings.text('cache.checking'));
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          _cached == true ? Icons.offline_pin_outlined : Icons.cloud_outlined,
          size: 16,
          color: _cached == true ? SelahColors.sage : SelahColors.textTertiary,
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: SelahTypography.labelSmall(color: SelahColors.textTertiary),
        ),
      ],
    );
  }
}

class _MemoryRow extends StatelessWidget {
  const _MemoryRow({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.local_florist_outlined,
          size: 16,
          color: SelahColors.rose,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: SelahTypography.labelLarge()),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: SelahTypography.labelSmall(
                  color: SelahColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: const BoxDecoration(
                  color: SelahColors.lavenderSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: SelahColors.lavender, size: 26),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: SelahTypography.headlineMedium(),
              ),
              const SizedBox(height: 7),
              Text(
                message,
                textAlign: TextAlign.center,
                style: SelahTypography.bodySmall(),
              ),
              if (onAction != null && actionLabel != null) ...[
                const SizedBox(height: 16),
                OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({
    required this.icon,
    required this.color,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final Color color;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(SelahCornerRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: SelahTypography.bodySmall()),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 7),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: onAction,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, SelahSpacing.minTouchTarget),
                        padding: EdgeInsets.zero,
                      ),
                      child: Text(actionLabel!),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthDialog extends StatefulWidget {
  const _AuthDialog({required this.controller});

  final LearningController controller;

  @override
  State<_AuthDialog> createState() => _AuthDialogState();
}

class _AuthDialogState extends State<_AuthDialog> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.length < 6) return;
    setState(() => _busy = true);
    widget.controller.clearMessage();
    try {
      await widget.controller.login(email, password, register: _register);
      if (mounted && widget.controller.error == null) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = SelahStrings.of(widget.controller.uiLocale);
    return AlertDialog(
      title: Text(
        strings.translateLegacy(_register ? '创建 Selah 账户' : '登录 Selah'),
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              decoration: InputDecoration(
                labelText: strings.translateLegacy('邮箱'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: InputDecoration(
                labelText: strings.translateLegacy('密码'),
                helperText: strings.translateLegacy('至少 6 个字符'),
              ),
            ),
            if (widget.controller.error != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.controller.error!,
                  style: SelahTypography.bodySmall(color: SelahColors.danger),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy
              ? null
              : () => setState(() => _register = !_register),
          child: Text(strings.translateLegacy(_register ? '已有账户？登录' : '创建新账户')),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(
            strings.translateLegacy(_busy ? '处理中…' : (_register ? '注册' : '登录')),
          ),
        ),
      ],
    );
  }
}

void _showAuth(BuildContext context, LearningController controller) {
  showDialog<void>(
    context: context,
    builder: (_) => _AuthDialog(controller: controller),
  );
}

void _showFeedbackSurvey(BuildContext context, LearningController controller) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => FeedbackSurveySheet(
      controller: controller.feedbackSurvey,
      uiLocale: controller.uiLocale,
      onViewPlans: () {
        controller.navigate(4);
      },
    ),
  );
}

void _showSeedLibrary(BuildContext context, LearningController controller) {
  final strings = SelahStrings.of(controller.uiLocale);
  showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) {
        final added = controller.state.sentences
            .map((sentence) => sentence.seedId)
            .whereType<String>()
            .toSet();
        return AlertDialog(
          title: Text(strings.translateLegacy('全部种子句')),
          content: SizedBox(
            width: 520,
            height: 500,
            child: ListView.separated(
              itemCount: controller.seeds.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, index) {
                final seed = controller.seeds[index];
                final isAdded =
                    seed.seedId != null && added.contains(seed.seedId);
                final offline = _hasBundledAudio(controller, seed);
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 5),
                  leading: Icon(
                    isAdded ? Icons.check_circle_rounded : Icons.eco_outlined,
                    color: isAdded ? SelahColors.sage : SelahColors.coral,
                  ),
                  title: Text(
                    seed.source,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Row(
                    children: [
                      Expanded(
                        child: Text(
                          seed.target,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (offline) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.offline_pin_outlined,
                          size: 14,
                          color: SelahColors.sage,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          strings.translateLegacy('可离线试听'),
                          style: SelahTypography.labelSmall(
                            color: SelahColors.sage,
                          ),
                        ),
                      ],
                    ],
                  ),
                  trailing: _CategoryPill(category: seed.category),
                  onTap: controller.busy
                      ? null
                      : () async {
                          controller.clearMessage();
                          await controller.addSeed(seed);
                          if (!dialogContext.mounted) return;
                          if (controller.error == null) {
                            Navigator.of(dialogContext).pop();
                          } else {
                            setDialogState(() {});
                          }
                        },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(strings.text('common.close')),
            ),
          ],
        );
      },
    ),
  );
}

void _showMemories(BuildContext context, LearningController controller) {
  final strings = SelahStrings.of(controller.uiLocale);
  final keys = controller.state.memories.keys
      .where(memoryTitles.containsKey)
      .toList();
  showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(strings.translateLegacy('成长回忆册')),
      content: SizedBox(
        width: 420,
        child: keys.isEmpty
            ? Text(strings.translateLegacy('完成一次真实的聆听或练习后，第一段回忆会在这里出现。'))
            : ListView(
                shrinkWrap: true,
                children: keys
                    .map(
                      (key) => ListTile(
                        leading: const Icon(
                          Icons.local_florist_outlined,
                          color: SelahColors.rose,
                        ),
                        title: Text(strings.memoryTitle(key)),
                        subtitle: Text(strings.memorySubtitle(key)),
                      ),
                    )
                    .toList(),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(strings.translateLegacy('知道了')),
        ),
      ],
    ),
  );
}

String _formatDuration(double milliseconds) {
  final total = (milliseconds / 1000).round();
  return '${(total ~/ 60).toString().padLeft(1, '0')}:${(total % 60).toString().padLeft(2, '0')}';
}

String _formatDate(DateTime value) =>
    '${value.month}/${value.day} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

TimeOfDay _parseTime(String value) {
  final parts = value.split(':');
  final hour = parts.isNotEmpty ? int.tryParse(parts.first) ?? 20 : 20;
  final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  return TimeOfDay(hour: hour.clamp(0, 23), minute: minute.clamp(0, 59));
}

String _offlineText(Map<String, dynamic> info, [SelahStrings? strings]) {
  final s = strings ?? SelahStrings.of(defaultUiLocale);
  final storage = _boolValue(info, const [
    'storage',
    'indexedDb',
    'localStorage',
  ]);
  final audio = _boolValue(info, const ['audio', 'audioPlayback']);
  if (storage == false) {
    return s.text('settings.offline.storageUnavailable');
  }
  if (audio == false) {
    return s.text('settings.offline.audioUnavailable');
  }
  return s.text('settings.offline');
}

DecorationStage _decorationStage(LearningController controller) {
  final value = LearningEngine.stage(controller.state);
  return DecorationStage.values.firstWhere(
    (stage) => stage.name == value,
    orElse: () => DecorationStage.none,
  );
}

Color _reviewColor(String state) => switch (state) {
  'learning' => SelahColors.lavender,
  'familiar' => SelahColors.sage,
  'quiet' => SelahColors.rose,
  _ => SelahColors.textTertiary,
};

Color _vocabColor(String state) => switch (state) {
  'owned' => SelahColors.sage,
  'familiar' => SelahColors.lavender,
  'learning' => SelahColors.amber,
  _ => SelahColors.textTertiary,
};

bool _isPlaying(Map<String, dynamic> playback) =>
    playback['state'] == 'playing';

double? _numValue(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is num && value.isFinite) return value.toDouble();
  }
  return null;
}

bool? _boolValue(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is bool) return value;
  }
  return null;
}

String? _stringValue(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}

bool _hasBundledAudio(LearningController controller, LearnSentence sentence) {
  final seedId = sentence.seedId;
  if (seedId == null) return false;
  return controller.bundledAudio.containsKey('$seedId:gentle-natural');
}
