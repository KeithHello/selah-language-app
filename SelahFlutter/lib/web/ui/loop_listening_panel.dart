import 'package:flutter/material.dart';

import '../../design/selah_colors.dart';
import '../../design/selah_spacing.dart';
import '../../design/selah_typography.dart';
import '../domain/loop_listening.dart';
import '../domain/learning_models.dart';
import '../learning_controller.dart';
import '../l10n/selah_strings.dart';

Future<void> showLoopListeningSettings(
  BuildContext context,
  LearningController controller,
) async {
  final strings = SelahStrings.of(controller.uiLocale);
  final content = LoopListeningPanel(
    controller: controller,
    settingsOnly: true,
  );
  if (MediaQuery.sizeOf(context).width < 900) {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.76,
        minChildSize: 0.58,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, scrollController) => Material(
          color: SelahColors.bgPrimary,
          clipBehavior: Clip.antiAlias,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(SelahCornerRadius.lg),
          ),
          child: Column(
            children: [
              _LoopSettingsHeader(
                strings: strings,
                onClose: () => Navigator.of(sheetContext).pop(),
                showDragHandle: true,
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: content,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return;
  }

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      constraints: BoxConstraints(
        maxWidth: 560,
        maxHeight: MediaQuery.sizeOf(context).height * 0.82,
      ),
      child: Column(
        children: [
          _LoopSettingsHeader(
            strings: strings,
            onClose: () => Navigator.of(dialogContext).pop(),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: content,
            ),
          ),
        ],
      ),
    ),
  );
}

class _LoopSettingsHeader extends StatelessWidget {
  const _LoopSettingsHeader({
    required this.strings,
    required this.onClose,
    this.showDragHandle = false,
  });

  final SelahStrings strings;
  final VoidCallback onClose;
  final bool showDragHandle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(20, showDragHandle ? 10 : 12, 12, 12),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showDragHandle) ...[
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: SelahColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: Text(
                strings.text('loop.settings'),
                style: SelahTypography.headlineLarge(),
              ),
            ),
            IconButton(
              tooltip: strings.text('common.close'),
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ],
    ),
  );
}

class LoopListeningPanel extends StatefulWidget {
  const LoopListeningPanel({
    super.key,
    required this.controller,
    this.settingsOnly = false,
  });

  final LearningController controller;
  final bool settingsOnly;

  @override
  State<LoopListeningPanel> createState() => _LoopListeningPanelState();
}

class _LoopListeningPanelState extends State<LoopListeningPanel> {
  final TextEditingController _customMinutes = TextEditingController();
  String? _customError;

  LearningController get c => widget.controller;

  @override
  void dispose() {
    _customMinutes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = SelahStrings.of(c.uiLocale);
    if (!widget.settingsOnly) return _status(strings);

    final sentences = c.listenSentences;
    if (sentences.isEmpty) return Text(strings.text('loop.empty'));
    final options = c.state.preferences.loopOptions;
    final source = strings.nativeLanguageValue(c.nativeLanguage);
    final target = strings.languageLabel(generationTargetLanguage);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.text('loop.subtitle'),
          style: SelahTypography.bodyMedium(color: SelahColors.textSecondary),
        ),
        const SizedBox(height: 18),
        Text(
          strings.message('loop.allSentences', {
            'count': '${sentences.length}',
          }),
          style: SelahTypography.labelLarge(color: SelahColors.textSecondary),
        ),
        const SizedBox(height: 20),
        Text(strings.text('loop.order'), style: SelahTypography.labelLarge()),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _orderButton(
                LoopOrder.targetFirst,
                strings.message('loop.targetFirst', {
                  'target': target,
                  'source': source,
                }),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _orderButton(
                LoopOrder.sourceFirst,
                strings.message('loop.sourceFirst', {
                  'source': source,
                  'target': target,
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          strings.text('loop.duration'),
          style: SelahTypography.labelLarge(),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children:
              [
                15,
                30,
                60,
              ].map((minutes) => _durationChip(minutes, strings)).toList()..add(
                _durationChip(options.durationMinutes, strings, custom: true),
              ),
        ),
        const SizedBox(height: 12),
        Text(
          strings.text('loop.nextSessionDuration'),
          style: SelahTypography.bodySmall(color: SelahColors.textTertiary),
        ),
        const SizedBox(height: 8),
        Text(
          strings.text('loop.voiceSpeed'),
          style: SelahTypography.bodySmall(color: SelahColors.textTertiary),
        ),
        if (c.loopSessionVisible) ...[
          const SizedBox(height: 18),
          TextButton.icon(
            onPressed: c.busy
                ? null
                : () async {
                    await c.stopLoop();
                    if (context.mounted) Navigator.of(context).maybePop();
                  },
            icon: const Icon(Icons.stop_circle_outlined),
            label: Text(strings.text('loop.end')),
          ),
        ],
      ],
    );
  }

  Widget _status(SelahStrings strings) {
    final status = c.loopPlayback;
    final state = status['state'];
    if (!c.loopSessionVisible) {
      return Container(
        key: const ValueKey('loop-status'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: SelahColors.lavenderSoft,
          borderRadius: BorderRadius.circular(SelahCornerRadius.sm),
        ),
        child: Row(
          children: [
            const Icon(Icons.headphones_outlined, color: SelahColors.lavender),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                strings.text('loop.startHint'),
                style: SelahTypography.bodySmall(
                  color: SelahColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final phase = status['phase'];
    final source = strings.nativeLanguageValue(c.nativeLanguage);
    final target = strings.languageLabel(generationTargetLanguage);
    final title = switch (state) {
      'ready' => strings.text('loop.autoplayBlocked'),
      'playing' => strings.message(
        phase == 'source' ? 'loop.playingSource' : 'loop.playingTarget',
        {
          phase == 'source' ? 'source' : 'target': phase == 'source'
              ? source
              : target,
        },
      ),
      'gap' => strings.text('loop.gap'),
      'paused' => strings.text('loop.paused'),
      'starting' => strings.message('loop.preparing', {
        'done': '${c.loopPreparedTracks}',
        'total': '${c.loopTotalTracks}',
      }),
      _ => strings.text('loop.startHint'),
    };
    final remaining = ((status['remainingMs'] as num?) ?? 0).toInt();
    return Container(
      key: const ValueKey('loop-status'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: SelahColors.lavenderSoft,
        borderRadius: BorderRadius.circular(SelahCornerRadius.sm),
      ),
      child: Row(
        children: [
          const Icon(Icons.headphones_outlined, color: SelahColors.lavender),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Text(title, style: SelahTypography.labelLarge())],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            strings.message('loop.miniRemaining', {
              'remaining': _formatMs(remaining),
            }),
            textAlign: TextAlign.end,
            style: SelahTypography.bodySmall(color: SelahColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _orderButton(LoopOrder order, String label) {
    final selected = c.state.preferences.loopOptions.order == order;
    return OutlinedButton(
      onPressed: c.busy ? null : () => c.setLoopOrder(order),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 50),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        backgroundColor: selected
            ? SelahColors.lavenderSoft
            : SelahColors.cardSoft,
        side: BorderSide(
          color: selected ? SelahColors.lavender : SelahColors.border,
        ),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: SelahTypography.labelLarge(
          color: selected ? const Color(0xFF554B85) : SelahColors.textSecondary,
        ),
      ),
    );
  }

  Widget _durationChip(
    int minutes,
    SelahStrings strings, {
    bool custom = false,
  }) {
    final isPreset = const [15, 30, 60].contains(minutes);
    final selected = custom
        ? !isPreset &&
              c.state.preferences.loopOptions.durationMinutes == minutes
        : c.state.preferences.loopOptions.durationMinutes == minutes;
    final label = custom && !isPreset
        ? _formatCustomLabel(minutes, strings)
        : custom
        ? strings.text('loop.custom')
        : strings.message('loop.customMinutes', {'minutes': '$minutes'});
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: c.busy
          ? null
          : (_) {
              if (custom) {
                _openCustomDuration(
                  !isPreset
                      ? minutes
                      : c.state.preferences.loopOptions.durationMinutes,
                );
              } else {
                c.updateLoopPreferences(durationMinutes: minutes);
              }
            },
    );
  }

  String _formatCustomLabel(int minutes, SelahStrings strings) =>
      '${strings.text('loop.custom')} · ${strings.message('loop.customMinutes', {'minutes': '$minutes'})}';

  Future<void> _openCustomDuration([int? currentMinutes]) async {
    _customMinutes.text =
        '${currentMinutes ?? c.state.preferences.loopOptions.durationMinutes}';
    _customError = null;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final strings = SelahStrings.of(c.uiLocale);
          return AlertDialog(
            title: Text(strings.text('loop.customDuration')),
            content: TextField(
              controller: _customMinutes,
              autofocus: true,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: strings.text('loop.durationLabel'),
                suffixText: strings.locale == 'ja'
                    ? '分'
                    : strings.locale == 'zh-Hant'
                    ? '分鐘'
                    : '分钟',
                helperText: strings.text('loop.durationValidation'),
                errorText: _customError,
              ),
              onSubmitted: (value) =>
                  _saveCustomMinutes(value, dialogContext, setDialogState),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(strings.text('common.cancel')),
              ),
              FilledButton(
                onPressed: () => _saveCustomMinutes(
                  _customMinutes.text,
                  dialogContext,
                  setDialogState,
                ),
                child: Text(strings.text('common.confirm')),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _saveCustomMinutes(
    String value,
    BuildContext dialogContext,
    void Function(void Function()) setDialogState,
  ) async {
    final minutes = validateLoopDuration(value);
    if (minutes == null) {
      final strings = SelahStrings.of(c.uiLocale);
      setDialogState(
        () => _customError = strings.text('loop.durationValidation'),
      );
      return;
    }
    setDialogState(() => _customError = null);
    c.clearMessage();
    await c.updateLoopPreferences(durationMinutes: minutes);
    if (!mounted) return;
    if (c.error != null) {
      setDialogState(() => _customError = c.error);
      return;
    }
    if (dialogContext.mounted) Navigator.of(dialogContext).pop();
  }

  String _formatMs(int value) {
    final total = (value / 1000).round();
    final hour = total ~/ 3600;
    final minute = (total % 3600) ~/ 60;
    final second = total % 60;
    String two(int input) => input.toString().padLeft(2, '0');
    return hour > 0
        ? '$hour:${two(minute)}:${two(second)}'
        : '${two(minute)}:${two(second)}';
  }
}

class LoopListeningMiniPlayer extends StatelessWidget {
  const LoopListeningMiniPlayer({super.key, required this.controller});

  final LearningController controller;

  @override
  Widget build(BuildContext context) {
    final strings = SelahStrings.of(controller.uiLocale);
    final status = controller.loopPlayback;
    if (status['state'] != 'ready' &&
        status['state'] != 'playing' &&
        status['state'] != 'gap' &&
        status['state'] != 'paused') {
      return const SizedBox.shrink();
    }
    final remaining = ((status['remainingMs'] as num?) ?? 0).toInt();
    final index = ((status['sentenceIndex'] as num?) ?? 0).toInt() + 1;
    final count = ((status['sentenceCount'] as num?) ?? 0).toInt();
    return Material(
      key: const ValueKey('loop-mini-player'),
      color: SelahColors.cardSoft,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: SelahColors.cardSoft,
          borderRadius: BorderRadius.circular(SelahCornerRadius.lg),
          border: Border.all(color: SelahColors.border),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.headphones_outlined,
              size: 20,
              color: SelahColors.lavender,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    strings.message('loop.miniTitle', {
                      'index': '$index',
                      'count': '$count',
                    }),
                    style: SelahTypography.labelMedium(),
                  ),
                  Text(
                    strings.message('loop.miniRemaining', {
                      'remaining': _formatRemaining(remaining),
                    }),
                    style: SelahTypography.bodySmall(
                      color: SelahColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: strings.text(
                status['state'] == 'paused' || status['state'] == 'ready'
                    ? 'loop.resumeLoop'
                    : 'loop.pauseLoop',
              ),
              onPressed: () =>
                  status['state'] == 'paused' || status['state'] == 'ready'
                  ? controller.resumeLoop()
                  : controller.pauseLoop(),
              icon: Icon(
                status['state'] == 'paused' || status['state'] == 'ready'
                    ? Icons.play_arrow_rounded
                    : Icons.pause_rounded,
              ),
            ),
            IconButton(
              tooltip: strings.text('loop.return'),
              onPressed: () => controller.navigate(1),
              icon: const Icon(Icons.open_in_new_rounded),
            ),
          ],
        ),
      ),
    );
  }

  String _formatRemaining(int value) {
    final total = (value / 1000).round();
    final hour = total ~/ 3600;
    final minute = (total % 3600) ~/ 60;
    final second = total % 60;
    String two(int input) => input.toString().padLeft(2, '0');
    return hour > 0
        ? '$hour:${two(minute)}:${two(second)}'
        : '${two(minute)}:${two(second)}';
  }
}
