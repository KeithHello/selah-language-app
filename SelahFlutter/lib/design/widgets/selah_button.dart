import 'package:flutter/material.dart';

import '../selah_colors.dart';
import '../selah_spacing.dart';
import '../selah_typography.dart';

/// 主按钮（胶囊形、珊瑚色）。
class SelahPrimaryButton extends StatelessWidget {
  const SelahPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final button = ElevatedButton(
      onPressed: onPressed,
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18),
            const SizedBox(width: SelahSpacing.sm),
          ],
          Text(label),
        ],
      ),
    );
    if (!expand) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}

/// 次级按钮（描边）。
class SelahSecondaryButton extends StatelessWidget {
  const SelahSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18),
            const SizedBox(width: SelahSpacing.sm),
          ],
          Text(label),
        ],
      ),
    );
  }
}

/// 文本按钮（弱强调，用于「跳過」等）。
class SelahTextButton extends StatelessWidget {
  const SelahTextButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = SelahColors.textSecondary,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      child: Text(label, style: SelahTypography.labelLarge(color: color)),
    );
  }
}
