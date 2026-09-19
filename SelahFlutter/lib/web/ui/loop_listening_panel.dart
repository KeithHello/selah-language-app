import 'package:flutter/material.dart';

import '../../design/selah_colors.dart';
import '../../design/selah_spacing.dart';
import '../../design/selah_typography.dart';
import '../domain/loop_listening.dart';
import '../domain/learning_models.dart';
import '../learning_controller.dart';
import '../l10n/selah_strings.dart';
import 'speed_selector.dart';

class LoopListeningPanel extends StatefulWidget {
  const LoopListeningPanel({super.key, required this.controller});

  final LearningController controller;

  @override
  State<LoopListeningPanel> createState() => _LoopListeningPanelState();
}

class _LoopListeningPanelState extends State<LoopListeningPanel> {
  final TextEditingController _customMinutes = TextEditingController();
  String? _customError;

  @override
  void dispose() {
    _customMinutes.dispose();
    super.dispose();
  }

  LearningController get c => widget.controller;

  @override
  Widget build(BuildContext context) {
    final strings = SelahStrings.of(c.uiLocale);
    final sentences = c.state.sentences
        .where((sentence) => !sentence.archived)
        .toList();
    if (sentences.isEmpty) {
      return _LoopEmptyState(strings: strings);
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(SelahSpacing.xxl),
        child: c.loopActive
            ? _playingUi(sentences.length, strings)
            : _setupUi(sentences.length, strings),
      ),
    );
  }

  String _language(String language, SelahStrings strings) =>
      strings.languageLabel(language);

  String _countLabel(int count, SelahStrings strings) =>
      strings.message('loop.allSentences', {'count': '$count'});

  Widget _setupUi(int count, SelahStrings strings) {
    final options = c.state.preferences.loopOptions;
    final source = strings.nativeLanguageValue(c.nativeLanguage);
    final target = _language(generationTargetLanguage, strings);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.text('loop.title'),
          style: SelahTypography.displayMedium(),
        ),
        const SizedBox(height: 8),
        Text(
          strings.text('loop.subtitle'),
          style: SelahTypography.bodyMedium(color: SelahColors.textSecondary),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Text(
              _countLabel(count, strings),
              style: SelahTypography.labelLarge(
                color: SelahColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
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
            const SizedBox(width: 12),
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
        const SizedBox(height: 24),
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
          strings.text('loop.afterStart'),
          style: SelahTypography.bodySmall(color: SelahColors.textTertiary),
        ),
        if (c.loopPlayback['stopReason'] == 'autoplay_blocked') ...[
          const SizedBox(height: 10),
          Text(
            strings.text('loop.autoplayBlocked'),
            style: SelahTypography.bodySmall(color: SelahColors.coral),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: c.busy || c.loopPreparing
              ? null
              : () async {
                  c.clearMessage();
                  await c.startLoop();
                },
          child: c.loopPreparing
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator.adaptive(
                        strokeWidth: 2,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      strings.message('loop.preparing', {
                        'done': '${c.loopPreparedTracks}',
                        'total': '${c.loopTotalTracks}',
                      }),
                    ),
                  ],
              )
              : Text(strings.text('loop.start')),
        ),
        const SizedBox(height: 12),
        Text(
          strings.text('loop.voiceSpeed'),
          style: SelahTypography.bodySmall(color: SelahColors.textTertiary),
        ),
      ],
    );
  }

  Widget _orderButton(LoopOrder order, String label) {
    final selected = c.state.preferences.loopOptions.order == order;
    return OutlinedButton(
      onPressed: c.busy ? null : () => c.setLoopOrder(order),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 50),
        backgroundColor: selected
            ? SelahColors.lavenderSoft
            : SelahColors.cardSoft,
        side: BorderSide(
          color: selected ? SelahColors.lavender : SelahColors.border,
        ),
      ),
      child: Text(
        label,
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
      onSelected: (_) {
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

  Widget _playingUi(int count, SelahStrings strings) {
    final status = c.loopPlayback;
    final remaining = (status['remainingMs'] as num? ?? 0).toInt();
    final index = ((status['sentenceIndex'] as num? ?? 0).toInt()) + 1;
    final phase = status['phase'];
    final source = strings.nativeLanguageValue(c.nativeLanguage);
    final target = _language(generationTargetLanguage, strings);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              strings.text('loop.playingTitle'),
              style: SelahTypography.labelLarge(),
            ),
            const Spacer(),
            Text(
              _countLabel(count, strings),
              style: SelahTypography.bodySmall(
                color: SelahColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Text(
          _formatMs(remaining),
          textAlign: TextAlign.center,
          style: SelahTypography.displayLarge().copyWith(fontSize: 48),
        ),
        const SizedBox(height: 4),
        Text(
          strings.text('loop.remaining'),
          textAlign: TextAlign.center,
          style: SelahTypography.bodySmall(color: SelahColors.textSecondary),
        ),
        const SizedBox(height: 22),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          children: [
            Chip(
              label: Text(
                strings.message(
                  phase == 'source'
                      ? 'loop.playingSource'
                      : 'loop.playingTarget',
                  {
                    phase == 'source' ? 'source' : 'target': phase == 'source'
                        ? source
                        : target,
                  },
                ),
              ),
            ),
            Chip(
              label: Text(
                strings.message('loop.sentenceIndex', {
                  'index': '$index',
                  'count': '$count',
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: () =>
                  status['state'] == 'paused' ? c.resumeLoop() : c.pauseLoop(),
              icon: Icon(
                status['state'] == 'paused'
                    ? Icons.play_arrow_rounded
                    : Icons.pause_rounded,
              ),
              label: Text(
                strings.text(
                  status['state'] == 'paused' ? 'loop.resume' : 'loop.pause',
                ),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: c.nextLoopSentence,
              icon: const Icon(Icons.skip_next_rounded),
              label: Text(strings.text('loop.next')),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Center(
          child: SpeedSelector(
            controller: c,
            label: strings.text('settings.speed'),
            alignment: WrapAlignment.center,
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => c.stopLoop(),
          child: Text(strings.text('loop.end')),
        ),
      ],
    );
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

class _LoopEmptyState extends StatelessWidget {
  const _LoopEmptyState({required this.strings});

  final SelahStrings strings;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(strings.text('loop.empty')),
      ),
    );
  }
}

class LoopListeningMiniPlayer extends StatelessWidget {
  const LoopListeningMiniPlayer({super.key, required this.controller});

  final LearningController controller;

  @override
  Widget build(BuildContext context) {
    final strings = SelahStrings.of(controller.uiLocale);
    final status = controller.loopPlayback;
    if (status['state'] != 'playing' &&
        status['state'] != 'gap' &&
        status['state'] != 'paused') {
      return const SizedBox.shrink();
    }
    final remaining = ((status['remainingMs'] as num?) ?? 0).toInt();
    final index = ((status['sentenceIndex'] as num?) ?? 0).toInt() + 1;
    final count = ((status['sentenceCount'] as num?) ?? 0).toInt();
    return Material(
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
                status['state'] == 'paused'
                    ? 'loop.resumeLoop'
                    : 'loop.pauseLoop',
              ),
              onPressed: () => status['state'] == 'paused'
                  ? controller.resumeLoop()
                  : controller.pauseLoop(),
              icon: Icon(
                status['state'] == 'paused'
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
