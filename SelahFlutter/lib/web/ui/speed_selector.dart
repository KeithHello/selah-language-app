import 'package:flutter/material.dart';

import '../../design/selah_colors.dart';
import '../../design/selah_spacing.dart';
import '../../design/selah_typography.dart';
import '../domain/learning_models.dart';
import '../l10n/selah_strings.dart';
import '../learning_controller.dart';

class SpeedSelector extends StatelessWidget {
  const SpeedSelector({
    super.key,
    required this.controller,
    required this.label,
    this.alignment = WrapAlignment.start,
    this.compact = false,
  });

  final LearningController controller;
  final String label;
  final WrapAlignment alignment;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final strings = SelahStrings.of(controller.uiLocale);
    final current = controller.state.preferences.speed;
    final isPreset = speedPresets.any((value) => value == current);
    if (compact) {
      return _CompactSpeedSelector(
        controller: controller,
        label: label,
        current: current,
      );
    }
    return Wrap(
      alignment: alignment,
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          label,
          style: SelahTypography.labelSmall(color: SelahColors.textTertiary),
        ),
        ...speedPresets.map(
          (speed) => ChoiceChip(
            label: Text('${speedLabel(speed)}x'),
            selected: current == speed,
            onSelected: controller.busy
                ? null
                : (_) => controller.updatePreferences(speed: speed),
            visualDensity: VisualDensity.compact,
            backgroundColor: SelahColors.cardSoft,
            selectedColor: SelahColors.lavenderSoft,
            labelStyle: SelahTypography.labelSmall(
              color: current == speed
                  ? SelahColors.lavenderInk
                  : SelahColors.textSecondary,
            ),
            side: BorderSide(
              color: current == speed
                  ? SelahColors.lavender
                  : SelahColors.border,
            ),
          ),
        ),
        OutlinedButton(
          onPressed: controller.busy
              ? null
              : () => showCustomSpeedDialog(context, controller),
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            backgroundColor: isPreset ? null : SelahColors.lavenderSoft,
            foregroundColor: isPreset
                ? SelahColors.textSecondary
                : SelahColors.lavenderInk,
            side: BorderSide(
              color: isPreset ? SelahColors.border : SelahColors.lavender,
            ),
          ),
          child: Text(
            isPreset
                ? strings.text('settings.speed.custom')
                : '${strings.text('settings.speed.custom')}（${speedLabel(current)}x）',
          ),
        ),
      ],
    );
  }
}

enum _CompactSpeedChoice {
  half,
  threeQuarter,
  one,
  oneQuarter,
  oneHalf,
  custom,
}

class _CompactSpeedSelector extends StatelessWidget {
  const _CompactSpeedSelector({
    required this.controller,
    required this.label,
    required this.current,
  });

  final LearningController controller;
  final String label;
  final double current;

  List<PopupMenuEntry<_CompactSpeedChoice>> _menuItems(SelahStrings strings) =>
      [
        for (var index = 0; index < speedPresets.length; index++)
          PopupMenuItem(
            value: _CompactSpeedChoice.values[index],
            child: Text('${speedLabel(speedPresets[index])}×'),
          ),
        PopupMenuItem(
          value: _CompactSpeedChoice.custom,
          child: Text(strings.text('settings.speed.custom')),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final strings = SelahStrings.of(controller.uiLocale);
    return Builder(
      builder: (buttonContext) => OutlinedButton.icon(
        key: const ValueKey('listen-speed-compact'),
        onPressed: controller.busy ? null : () => _open(buttonContext, strings),
        icon: const Icon(Icons.speed_rounded, size: 18),
        label: Text('$label ${speedLabel(current)}×'),
        style: OutlinedButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          foregroundColor: SelahColors.textSecondary,
          side: const BorderSide(color: SelahColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SelahCornerRadius.md),
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, SelahStrings strings) async {
    final choice = MediaQuery.sizeOf(context).width < 900
        ? await showModalBottomSheet<_CompactSpeedChoice>(
            context: context,
            useSafeArea: true,
            builder: (sheetContext) =>
                _CompactSpeedSheet(current: current, strings: strings),
          )
        : await _showDesktopMenu(context, strings);
    if (choice == null || !context.mounted) return;
    if (choice == _CompactSpeedChoice.custom) {
      await showCustomSpeedDialog(context, controller);
    } else {
      await controller.updatePreferences(speed: speedPresets[choice.index]);
    }
  }

  Future<_CompactSpeedChoice?> _showDesktopMenu(
    BuildContext context,
    SelahStrings strings,
  ) {
    final box = context.findRenderObject()! as RenderBox;
    final origin = box.localToGlobal(Offset.zero);
    final rect = origin & box.size;
    final size = MediaQuery.sizeOf(context);
    return showMenu<_CompactSpeedChoice>(
      context: context,
      position: RelativeRect.fromLTRB(
        rect.left,
        rect.bottom,
        size.width - rect.right,
        size.height - rect.top,
      ),
      items: _menuItems(strings),
    );
  }
}

class _CompactSpeedSheet extends StatelessWidget {
  const _CompactSpeedSheet({required this.current, required this.strings});

  final double current;
  final SelahStrings strings;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.text('listen.speedTitle'),
            style: SelahTypography.bodyLarge(),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var index = 0; index < speedPresets.length; index++)
                ChoiceChip(
                  label: Text('${speedLabel(speedPresets[index])}×'),
                  selected: current == speedPresets[index],
                  onSelected: (_) => Navigator.of(
                    context,
                  ).pop(_CompactSpeedChoice.values[index]),
                  selectedColor: SelahColors.lavenderSoft,
                  side: BorderSide(
                    color: current == speedPresets[index]
                        ? SelahColors.lavender
                        : SelahColors.border,
                  ),
                  labelStyle: SelahTypography.labelLarge(
                    color: current == speedPresets[index]
                        ? SelahColors.lavenderInk
                        : SelahColors.textSecondary,
                  ),
                ),
              OutlinedButton(
                onPressed: () =>
                    Navigator.of(context).pop(_CompactSpeedChoice.custom),
                child: Text(strings.text('settings.speed.custom')),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

String speedLabel(double speed) => speed
    .toStringAsFixed(2)
    .replaceFirst(RegExp(r'0+$'), '')
    .replaceFirst(RegExp(r'\.$'), '');

Future<void> showCustomSpeedDialog(
  BuildContext context,
  LearningController controller,
) async {
  final strings = SelahStrings.of(controller.uiLocale);
  var speed = controller.state.preferences.speed
      .clamp(minPlaybackSpeed, maxPlaybackSpeed)
      .toDouble();
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        title: Text(strings.text('settings.speed.customTitle')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${speedLabel(speed)}x',
              style: SelahTypography.headlineLarge(),
            ),
            Slider(
              value: speed,
              min: minPlaybackSpeed,
              max: maxPlaybackSpeed,
              label: '${speedLabel(speed)}x',
              onChanged: (value) => setState(() => speed = value),
            ),
            Text(
              strings.text('settings.speed.range'),
              style: SelahTypography.bodySmall(
                color: SelahColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(strings.text('common.cancel')),
          ),
          FilledButton(
            onPressed: () async {
              await controller.updatePreferences(speed: speed);
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            },
            child: Text(strings.text('settings.save')),
          ),
        ],
      ),
    ),
  );
}
