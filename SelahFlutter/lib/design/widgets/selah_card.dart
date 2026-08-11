import 'package:flutter/material.dart';

import '../selah_colors.dart';
import '../selah_motion.dart';
import '../selah_spacing.dart';
import '../selah_typography.dart';

/// Selah 标准卡片（暖色柔光，无重阴影）。
class SelahCard extends StatelessWidget {
  const SelahCard({
    super.key,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(SelahSpacing.lg),
    this.onTap,
    this.radius = SelahCornerRadius.lg,
  });

  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = color ??
        (brightness == Brightness.dark
            ? SelahColors.darkCard
            : SelahColors.cardPrimary);
    final shadow = SelahShadow.sm(brightness: brightness);
    final card = AnimatedContainer(
      duration: SelahMotion.quick,
      curve: SelahMotion.standardCurve,
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: brightness == Brightness.dark
              ? SelahColors.darkBorder
              : SelahColors.borderLight,
        ),
        boxShadow: shadow,
      ),
      child: child,
    );
    if (onTap == null) return card;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: card,
      ),
    );
  }
}

/// 分类徽章（柔和浅色底）。
class SelahTag extends StatelessWidget {
  const SelahTag({
    super.key,
    required this.label,
    required this.color,
    this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bg = color.withValues(alpha: 0.12);
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: SelahSpacing.md, vertical: SelahSpacing.xs),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(SelahCornerRadius.pill),
      ),
      child: Text(label, style: SelahTypography.labelSmall(color: color)),
    );
    if (onTap == null) return child;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(SelahCornerRadius.pill),
      child: child,
    );
  }
}

/// 分区小标题（eyebrow）。
class SelahSectionTitle extends StatelessWidget {
  const SelahSectionTitle({
    super.key,
    required this.title,
    this.trailing,
  });

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: SelahTypography.headlineMedium()),
        ),
        ?trailing,
      ],
    );
  }
}
