import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/selah_colors.dart';
import '../../design/selah_motion.dart';
import '../../domain/selah_enums.dart';
import 'plush_companion_poses.dart';

/// Shared full-pose asset mapping used by the native and Web displays.
class SelahSpriteAssets {
  const SelahSpriteAssets._();

  static String poseFor(DecorationStage stage, SpriteActionId action) =>
      plushPoseAsset(stage, action);

  /// Compatibility helper for callers that have not yet supplied a stage.
  static String bodyFor(SpriteActionId action) {
    return plushPoseAsset(DecorationStage.none, action);
  }

  static Color? haloFor(SpriteActionId action) {
    return switch (action) {
      SpriteActionId.listenEnter ||
      SpriteActionId.listenPlaying => SelahColors.listen,
      SpriteActionId.listenComplete => SelahColors.success,
      SpriteActionId.recRecording => SelahColors.coral,
      SpriteActionId.recDone => SelahColors.success,
      SpriteActionId.quizGood => SelahColors.success,
      _ => null,
    };
  }
}

/// Native companion view using one complete stage/action pose plus a halo.
/// 对应 Swift 侧 `PetLayeredSpriteView` 的 Flutter 版。
class SelahSprite extends StatefulWidget {
  const SelahSprite({
    super.key,
    required this.action,
    this.size = 120,
    this.reduceMotion = false,
    this.decorationStage = DecorationStage.none,
    this.imageProvider,
  });

  final SpriteActionId action;
  final double size;
  final bool reduceMotion;
  final DecorationStage decorationStage;
  @visibleForTesting
  final PlushPoseImageProvider? imageProvider;

  @override
  State<SelahSprite> createState() => SelahSpriteState();
}

class SelahSpriteState extends State<SelahSprite>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  late Animation<double> _breathe;
  late Animation<double> _jump;
  late Animation<double> _sway;
  bool _allowed = false;
  bool _foreground = true;
  bool _finished = false;

  @visibleForTesting
  bool get isAnimating => _controller.isAnimating;

  bool get _looping => switch (widget.action) {
    SpriteActionId.gentleFloat || SpriteActionId.listenPlaying => true,
    _ => false,
  };

  /// 系统级 Reduce Motion（可在 initState 使用，不依赖 MediaQuery）。
  bool get _systemReduceMotion => WidgetsBinding
      .instance
      .platformDispatcher
      .accessibilityFeatures
      .disableAnimations;

  /// 完整判定：显式参数 + 系统设置 + MediaQuery（用于 build）。
  bool get _reduceMotion =>
      widget.reduceMotion ||
      _systemReduceMotion ||
      MediaQuery.disableAnimationsOf(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _controller = AnimationController(vsync: this, duration: SelahMotion.slow);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_looping) _finished = true;
    });
    _breathe = Tween<double>(
      begin: 1.0,
      end: 1.035,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _jump =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 1),
        ]).animate(
          CurvedAnimation(parent: _controller, curve: SelahMotion.bounceCurve),
        );
    _sway = Tween<double>(
      begin: -0.12,
      end: 0.12,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
    _scheduleStagePrefetch();
  }

  @override
  void didUpdateWidget(covariant SelahSprite oldWidget) {
    super.didUpdateWidget(oldWidget);
    final poseChanged =
        oldWidget.action != widget.action ||
        oldWidget.decorationStage != widget.decorationStage;
    if (poseChanged) {
      _finished = false;
      _controller.reset();
    }
    _syncMotion(restart: poseChanged);
    if (oldWidget.decorationStage != widget.decorationStage) {
      _scheduleStagePrefetch();
    }
  }

  @override
  void didChangeAccessibilityFeatures() => setState(_syncMotion);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    setState(_syncMotion);
  }

  void _syncMotion({bool restart = false}) {
    final allowed =
        !_reduceMotion && _foreground && TickerMode.valuesOf(context).enabled;
    final changed = allowed != _allowed;
    _allowed = allowed;
    if (!allowed) {
      _controller.stop();
      return;
    }
    if (!restart && !changed) return;
    _controller.duration = Duration(
      milliseconds: switch (widget.action) {
        SpriteActionId.gentleFloat => 7200,
        SpriteActionId.listenPlaying => 3600,
        SpriteActionId.blink => 280,
        SpriteActionId.leafSway => 1400,
        SpriteActionId.recRecording => 550,
        _ => 1000,
      },
    );
    if (_looping) {
      _controller.repeat(reverse: true);
    } else if (!_finished) {
      _controller.forward();
    }
  }

  void _scheduleStagePrefetch() {
    if (widget.imageProvider != null) return;
    final stage = widget.decorationStage;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        PlushPosePrecache.ensureStage(
          context,
          stage,
          displayWidth: widget.size,
        ),
      );
    });
  }

  /// 测试辅助：停止循环动画，避免测试框架等待无限帧。
  @visibleForTesting
  void stopAnimationForTest() {
    _controller.stop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final halo = SelahSpriteAssets.haloFor(widget.action);
    final bounce =
        widget.action == SpriteActionId.quizGood ||
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
            final scale = _allowed ? _breathe.value : 1.0;
            final jumpOffset = bounce && _allowed
                ? -12 * _jump.value * widget.size / 120
                : 0.0;
            final rotation =
                _allowed && widget.action == SpriteActionId.quizGood
                ? _sway.value
                : 0.0;
            final asset = plushPoseAsset(widget.decorationStage, widget.action);
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
                // One complete pose image; no atlas crop or facial overlay.
                Transform.translate(
                  offset: Offset(0, jumpOffset),
                  child: Transform.rotate(
                    angle: rotation,
                    child: Transform.scale(
                      scale: scale,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AnimatedSwitcher(
                            duration: !_allowed || _reduceMotion
                                ? Duration.zero
                                : const Duration(milliseconds: 160),
                            child: PlushPoseImage(
                              key: ValueKey(asset),
                              stage: widget.decorationStage,
                              action: widget.action,
                              width: widget.size,
                              height: widget.size * 1.2,
                              imageProvider: widget.imageProvider,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
