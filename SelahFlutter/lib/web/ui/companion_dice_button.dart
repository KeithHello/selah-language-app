import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../design/selah_colors.dart';
import '../domain/companion_names.dart';

class CompanionDiceButton extends StatefulWidget {
  const CompanionDiceButton({
    super.key,
    required this.tooltip,
    required this.languageCode,
    required this.onRolled,
    this.currentName,
    this.enabled = true,
  });

  final String tooltip;
  final String languageCode;
  final ValueChanged<String> onRolled;
  final String? currentName;
  final bool enabled;

  @override
  State<CompanionDiceButton> createState() => _CompanionDiceButtonState();
}

class _CompanionDiceButtonState extends State<CompanionDiceButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _rotation;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _rotation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.22).chain(
          CurveTween(curve: Curves.easeOutQuad),
        ),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.22, end: 1.0).chain(
          CurveTween(curve: Curves.elasticOut),
        ),
        weight: 55,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _roll() {
    if (!widget.enabled || _controller.isAnimating) return;
    _controller.forward(from: 0.0);
    final newName = CompanionNamePool.randomName(
      widget.languageCode,
      currentName: widget.currentName,
    );
    widget.onRolled(newName);
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: Material(
        type: MaterialType.transparency,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.enabled ? _roll : null,
          customBorder: const CircleBorder(),
          hoverColor: SelahColors.coral.withValues(alpha: .12),
          splashColor: SelahColors.coral.withValues(alpha: .2),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scale.value,
                  child: Transform.rotate(
                    angle: _rotation.value * 2 * math.pi,
                    child: child,
                  ),
                );
              },
              child: Icon(
                Icons.casino_outlined,
                size: 22,
                color: widget.enabled
                    ? SelahColors.coral
                    : SelahColors.textSecondary.withValues(alpha: .36),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
