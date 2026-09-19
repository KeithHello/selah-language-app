import 'package:flutter/material.dart';

import '../../design/selah_colors.dart';
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
  });

  final LearningController controller;
  final String label;
  final WrapAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final strings = SelahStrings.of(controller.uiLocale);
    final current = controller.state.preferences.speed;
    final isPreset = speedPresets.any((value) => value == current);
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
          ),
        ),
        OutlinedButton(
          onPressed: controller.busy
              ? null
              : () => showCustomSpeedDialog(context, controller),
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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
