import 'package:flutter/material.dart';

import '../../design/selah_colors.dart';
import '../../design/selah_motion.dart';
import '../../domain/selah_enums.dart';

/// 精灵素材映射（与 Swift 侧 9 姿态对应）。
class SelahSpriteAssets {
  const SelahSpriteAssets._();

  static const String bodyNeutral = 'assets/sprites/SeedBodyNeutral.png';
  static const String bodyFloat = 'assets/sprites/SeedBodyFloat.png';
  static const String bodyListenEnter = 'assets/sprites/SeedBodyListenEnter.png';
  static const String bodyListenPlaying = 'assets/sprites/SeedBodyListenPlaying.png';
  static const String bodyListenComplete = 'assets/sprites/SeedBodyListenComplete.png';
  static const String bodyQuizGood = 'assets/sprites/SeedBodyQuizGood.png';
  static const String bodyQuizFail = 'assets/sprites/SeedBodyQuizFail.png';
  static const String bodyRecRecording = 'assets/sprites/SeedBodyRecRecording.png';
  static const String bodyRecDone = 'assets/sprites/SeedBodyRecDone.png';
  static const String eyesClosed = 'assets/sprites/SeedEyesClosed.png';
  static const String eyesSoft = 'assets/sprites/SeedEyesSoft.png';

  static String bodyFor(SpriteActionId action) {
    return switch (action) {
      SpriteActionId.gentleFloat => bodyFloat,
      SpriteActionId.blink => bodyNeutral,
      SpriteActionId.leafSway => bodyNeutral,
      SpriteActionId.listenEnter => bodyListenEnter,
      SpriteActionId.listenPlaying => bodyListenPlaying,
      SpriteActionId.listenComplete => bodyListenComplete,
      SpriteActionId.recRecording => bodyRecRecording,
      SpriteActionId.recDone => bodyRecDone,
      SpriteActionId.quizGood => bodyQuizGood,
      SpriteActionId.quizFail => bodyQuizFail,
    };
  }

  static String? eyeOverlayFor(SpriteActionId action) {
    return switch (action) {
      SpriteActionId.blink => eyesClosed,
      SpriteActionId.quizFail => eyesSoft,
      SpriteActionId.recDone => eyesSoft,
      _ => null,
    };
  }

  static Color? haloFor(SpriteActionId action) {
    return switch (action) {
      SpriteActionId.listenEnter ||
      SpriteActionId.listenPlaying =>
        SelahColors.listen,
      SpriteActionId.listenComplete => SelahColors.success,
      SpriteActionId.recRecording => SelahColors.coral,
      SpriteActionId.recDone => SelahColors.success,
      SpriteActionId.quizGood => SelahColors.success,
      _ => null,
    };
  }
}

/// 分层精灵视图：静态身体 + 可选眼神覆盖层 + 原生装饰与光环。
/// 对应 Swift 侧 `PetLayeredSpriteView` 的 Flutter 版。
class SelahSprite extends StatefulWidget {
  const SelahSprite({
    super.key,
    required this.action,
    this.size = 120,
    this.reduceMotion = false,
    this.decorationStage = DecorationStage.none,
  });

  final SpriteActionId action;
  final double size;
  final bool reduceMotion;
  final DecorationStage decorationStage;

  @override
  State<SelahSprite> createState() => SelahSpriteState();
}

class SelahSpriteState extends State<SelahSprite>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _breathe;
  late Animation<double> _jump;
  late Animation<double> _sway;

  /// 系统级 Reduce Motion（可在 initState 使用，不依赖 MediaQuery）。
  bool get _systemReduceMotion =>
      WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;

  /// 完整判定：显式参数 + 系统设置 + MediaQuery（用于 build）。
  bool get _reduceMotion =>
      widget.reduceMotion ||
      _systemReduceMotion ||
      MediaQuery.disableAnimationsOf(context);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: SelahMotion.slow);
    _breathe = Tween<double>(begin: 1.0, end: 1.035).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _jump = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _controller, curve: SelahMotion.bounceCurve));
    _sway = Tween<double>(begin: -0.12, end: 0.12).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (!_systemReduceMotion) {
      _controller.repeat(reverse: widget.action == SpriteActionId.gentleFloat);
    }
  }

  @override
  void didUpdateWidget(covariant SelahSprite oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.action != widget.action) {
      if (_systemReduceMotion) {
        _controller.stop();
      } else {
        _controller.repeat(reverse: widget.action == SpriteActionId.gentleFloat);
      }
    }
  }

  /// 测试辅助：停止循环动画，避免测试框架等待无限帧。
  @visibleForTesting
  void stopAnimationForTest() {
    _controller.stop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = SelahSpriteAssets.bodyFor(widget.action);
    final eyes = SelahSpriteAssets.eyeOverlayFor(widget.action);
    final halo = SelahSpriteAssets.haloFor(widget.action);
    final bounce = widget.action == SpriteActionId.quizGood ||
        widget.action == SpriteActionId.listenComplete ||
        widget.action == SpriteActionId.recDone;

    return Semantics(
      label: 'Selah 精靈：${widget.action.name}',
      image: true,
      child: SizedBox(
        width: widget.size,
        height: widget.size * 1.2,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final scale = _reduceMotion ? 1.0 : _breathe.value;
            final jumpOffset = bounce && !_reduceMotion
                ? -12 * _jump.value
                : 0.0;
            final rotation = !_reduceMotion &&
                    widget.action == SpriteActionId.quizGood
                ? _sway.value
                : 0.0;
            return Stack(
              alignment: Alignment.center,
              children: [
                // 光环
                if (halo != null)
                  Positioned(
                    top: 0,
                    child: Container(
                      width: widget.size * 0.92,
                      height: widget.size * 0.92,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: halo.withValues(alpha: 0.18),
                      ),
                    ),
                  ),
                // 身体 + 眼神
                Transform.translate(
                  offset: Offset(0, jumpOffset),
                  child: Transform.rotate(
                    angle: rotation,
                    child: Transform.scale(
                      scale: scale,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Image.asset(body, width: widget.size, fit: BoxFit.contain),
                          if (eyes != null)
                            Positioned(
                              top: widget.size * 0.30,
                              child: Image.asset(
                                eyes,
                                width: widget.size * 0.34,
                                fit: BoxFit.contain,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                // 原生成长装饰
                if (widget.decorationStage != DecorationStage.none)
                  Positioned(
                    top: widget.size * 0.02,
                    child: _GrowthDecoration(stage: widget.decorationStage),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _GrowthDecoration extends StatelessWidget {
  const _GrowthDecoration({required this.stage});

  final DecorationStage stage;

  @override
  Widget build(BuildContext context) {
    return switch (stage) {
      DecorationStage.none => const SizedBox.shrink(),
      DecorationStage.sprout => Icon(
          Icons.spa_outlined,
          size: 14,
          color: SelahColors.sage,
        ),
      DecorationStage.leaf => Icon(
          Icons.eco_outlined,
          size: 16,
          color: SelahColors.sage,
        ),
      DecorationStage.bud => Icon(
          Icons.local_florist_outlined,
          size: 16,
          color: SelahColors.rose,
        ),
      DecorationStage.bloom => Icon(
          Icons.local_florist,
          size: 18,
          color: SelahColors.rose,
        ),
    };
  }
}
