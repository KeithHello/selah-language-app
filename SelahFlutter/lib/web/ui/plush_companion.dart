import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../design/selah_motion_scope.dart';
import '../../domain/selah_enums.dart';
import '../../features/companion/plush_companion_poses.dart';
import '../domain/learning_models.dart';

String companionCaption(
  SpriteActionId action, {
  String uiLocale = defaultUiLocale,
}) {
  final locale = normalizeUiLocale(uiLocale);
  if (locale == 'ja') {
    return switch (action) {
      SpriteActionId.gentleFloat ||
      SpriteActionId.blink ||
      SpriteActionId.leafSway => 'ゆっくりで大丈夫です。',
      SpriteActionId.listenEnter => '準備できました。一緒に聞きましょう。',
      SpriteActionId.listenPlaying => '集中して聞いています。',
      SpriteActionId.listenComplete => 'また少し聞き取れましたね。',
      SpriteActionId.recRecording => 'ゆっくり話してください。ここにいます。',
      SpriteActionId.recDone => 'あなたの言葉を記録しました。',
      SpriteActionId.quizGood => 'この表現が少し近づきました。',
      SpriteActionId.quizFail => '大丈夫です。もう一度練習しましょう。',
    };
  }
  if (locale == 'zh-Hant') {
    return switch (action) {
      SpriteActionId.gentleFloat ||
      SpriteActionId.blink ||
      SpriteActionId.leafSway => '慢慢來，就很好。',
      SpriteActionId.listenEnter => '準備好了，陪你一起聽。',
      SpriteActionId.listenPlaying => '我在認真聽。',
      SpriteActionId.listenComplete => '又聽懂了一點。',
      SpriteActionId.recRecording => '慢慢說，我在這裡。',
      SpriteActionId.recDone => '你的話，已經記下了。',
      SpriteActionId.quizGood => '這句話，離你更近了。',
      SpriteActionId.quizFail => '沒關係，我們再練一次。',
    };
  }
  return switch (action) {
    SpriteActionId.gentleFloat ||
    SpriteActionId.blink ||
    SpriteActionId.leafSway => '慢慢来，就很好。',
    SpriteActionId.listenEnter => '准备好了，陪你一起听。',
    SpriteActionId.listenPlaying => '我在认真听。',
    SpriteActionId.listenComplete => '又听懂了一点。',
    SpriteActionId.recRecording => '慢慢说，我在这里。',
    SpriteActionId.recDone => '你的话，已经记下了。',
    SpriteActionId.quizGood => '这句话，离你更近了。',
    SpriteActionId.quizFail => '没关系，我们再练一次。',
  };
}

String companionSemanticLabel(
  SpriteActionId action, {
  String uiLocale = defaultUiLocale,
}) {
  final locale = normalizeUiLocale(uiLocale);
  final name = switch (locale) {
    'ja' => 'Selah の精霊、',
    'zh-Hant' => 'Selah 精靈，',
    _ => 'Selah 精灵，',
  };
  return '$name${companionCaption(action, uiLocale: locale)}';
}

class PlushCompanion extends StatefulWidget {
  const PlushCompanion({
    super.key,
    this.action = SpriteActionId.gentleFloat,
    this.revision = 0,
    this.size = 170,
    this.reduceMotion = false,
    this.decorationStage = DecorationStage.sprout,
    this.imageProvider,
    this.uiLocale = defaultUiLocale,
  });
  final SpriteActionId action;
  final int revision;
  final double size;
  final bool reduceMotion;
  final DecorationStage decorationStage;
  final String uiLocale;
  @visibleForTesting
  final PlushPoseImageProvider? imageProvider;

  @override
  State<PlushCompanion> createState() => PlushCompanionState();
}

class PlushCompanionState extends State<PlushCompanion>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _motion;
  bool _allowed = false;
  bool _foreground = true;
  bool _finished = false;
  Timer? _idleGestureTimer;
  SpriteActionId? _idleGesture;
  var _idleGestureCount = 0;

  @visibleForTesting
  bool get isAnimating => _motion.isAnimating;

  bool get _reduce => widget.reduceMotion || !MotionScope.of(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _motion = AnimationController(vsync: this)
      ..addStatusListener((status) {
        if (status != AnimationStatus.completed) return;
        _finished = true;
        if (_idleGesture != null) {
          _idleGesture = null;
          if (mounted) setState(() {});
        }
        _scheduleIdleGesture();
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
    _scheduleStagePrefetch();
  }

  @override
  void didUpdateWidget(covariant PlushCompanion oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newCue =
        oldWidget.action != widget.action ||
        oldWidget.revision != widget.revision ||
        oldWidget.decorationStage != widget.decorationStage;
    if (newCue) {
      _idleGestureTimer?.cancel();
      _idleGestureTimer = null;
      _idleGesture = null;
      _finished = false;
      _motion.reset();
    }
    _syncMotion(restart: newCue);
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
        !_reduce && _foreground && TickerMode.valuesOf(context).enabled;
    final changed = allowed != _allowed;
    _allowed = allowed;
    if (!allowed) {
      _idleGestureTimer?.cancel();
      _idleGestureTimer = null;
      _motion.stop();
      return;
    }
    if (!restart && !changed) return;
    if (_finished && !restart) {
      _scheduleIdleGesture();
      return;
    }
    _motion.duration = _durationFor(_idleGesture ?? widget.action);
    _motion.forward();
  }

  Duration _durationFor(SpriteActionId action) => switch (action) {
    SpriteActionId.gentleFloat => const Duration(milliseconds: 14400),
    SpriteActionId.listenPlaying => const Duration(milliseconds: 3600),
    SpriteActionId.blink => const Duration(milliseconds: 280),
    SpriteActionId.leafSway => const Duration(milliseconds: 1400),
    SpriteActionId.recRecording => const Duration(milliseconds: 550),
    _ => const Duration(seconds: 1),
  };

  void _scheduleIdleGesture() {
    if (!_allowed ||
        widget.action != SpriteActionId.gentleFloat ||
        !_finished ||
        _idleGestureTimer != null) {
      return;
    }
    _idleGestureTimer = Timer(const Duration(seconds: 25), () {
      _idleGestureTimer = null;
      if (!mounted ||
          !_allowed ||
          widget.action != SpriteActionId.gentleFloat ||
          !_finished) {
        return;
      }
      _idleGesture = _idleGestureCount++ % 2 == 0
          ? SpriteActionId.blink
          : SpriteActionId.leafSway;
      _finished = false;
      _motion
        ..duration = _durationFor(_idleGesture!)
        ..forward(from: 0);
    });
  }

  void _scheduleStagePrefetch() {
    if (widget.imageProvider != null) return;
    final stage = widget.decorationStage;
    final currentAssetWidth = widget.size;
    final currentAction = widget.action;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // The visible pose wins immediately; remaining actions of the stage
      // trickle in one-by-one afterwards so first interaction never waits
      // behind a 10-pose burst.
      final backgroundWarmup =
          PlushPosePrecache.ensurePose(
            context,
            stage,
            currentAction,
            displayWidth: currentAssetWidth,
          ).then((_) {
            if (!mounted) return null;
            return PlushPosePrecache.warmRemaining(
              context,
              stage,
              displayWidth: currentAssetWidth,
              skip: currentAction,
            );
          });
      unawaited(backgroundWarmup);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _idleGestureTimer?.cancel();
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: companionSemanticLabel(widget.action, uiLocale: widget.uiLocale),
    child: RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size * 1.2,
        child: AnimatedBuilder(
          animation: _motion,
          builder: (context, _) {
            var t = _allowed ? _motion.value : 0.0;
            final action = _idleGesture ?? widget.action;
            if (_allowed && action == SpriteActionId.gentleFloat) {
              t = (t * 2) % 1;
            }
            final pulse = math.sin(math.pi * t);
            var lift = 0.0;
            var angle = 0.0;
            if (_allowed) {
              switch (action) {
                case SpriteActionId.gentleFloat:
                  lift = -7 * (1 - math.cos(2 * math.pi * t));
                case SpriteActionId.blink:
                  // Blink is a complete static pose; the micro-transition is
                  // supplied by the asset change itself.
                  lift = 0;
                case SpriteActionId.leafSway:
                  angle = .045 * math.sin(2 * math.pi * t) * pulse;
                case SpriteActionId.listenEnter:
                  lift = 7 * pulse;
                case SpriteActionId.listenPlaying:
                  lift = -4 * (1 - math.cos(2 * math.pi * t));
                case SpriteActionId.listenComplete:
                  // Fires after every sentence heard, so keep the hop small.
                  lift = -8 * pulse;
                case SpriteActionId.recRecording:
                  lift = 4 * pulse;
                case SpriteActionId.recDone:
                  lift = -10 * pulse;
                case SpriteActionId.quizGood:
                  lift = -14 * pulse;
                  angle = .022 * math.sin(2 * math.pi * t) * pulse;
                case SpriteActionId.quizFail:
                  lift = 7 * pulse;
              }
            }
            lift *= widget.size / 170;
            final duration = !_allowed || _reduce
                ? Duration.zero
                : Duration(
                    milliseconds: widget.action == SpriteActionId.gentleFloat
                        ? 80
                        : 160,
                  );
            final asset = plushPoseAsset(widget.decorationStage, action);
            return Stack(
              alignment: Alignment.bottomCenter,
              clipBehavior: Clip.none,
              children: [
                Transform.translate(
                  offset: Offset(0, lift),
                  child: Transform.rotate(
                    angle: angle,
                    alignment: const Alignment(0, .85),
                    child: AnimatedSwitcher(
                      duration: duration,
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: Tween<double>(
                            begin: 0.98,
                            end: 1,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: PlushPoseImage(
                        key: ValueKey('$asset:${widget.revision}'),
                        stage: widget.decorationStage,
                        action: action,
                        animated: _allowed && _motion.isAnimating,
                        width: widget.size,
                        height: widget.size * 1.2,
                        imageProvider: widget.imageProvider,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}
