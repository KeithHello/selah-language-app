import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

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

  @visibleForTesting
  bool get isAnimating => _motion.isAnimating;

  bool get _looping => switch (widget.action) {
    SpriteActionId.gentleFloat || SpriteActionId.listenPlaying => true,
    _ => false,
  };

  bool get _reduce =>
      widget.reduceMotion ||
      MediaQuery.disableAnimationsOf(context) ||
      WidgetsBinding
          .instance
          .platformDispatcher
          .accessibilityFeatures
          .disableAnimations;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _motion = AnimationController(vsync: this)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && !_looping) _finished = true;
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
      _motion.stop();
      return;
    }
    if (!restart && !changed) return;
    _motion.duration = Duration(
      milliseconds: switch (widget.action) {
        SpriteActionId.gentleFloat => 21600,
        SpriteActionId.listenPlaying => 3600,
        SpriteActionId.blink => 280,
        SpriteActionId.leafSway => 1400,
        SpriteActionId.recRecording => 550,
        _ => 1000,
      },
    );
    if (_looping) {
      _motion.repeat();
    } else if (!_finished) {
      _motion.forward();
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
            var action = widget.action;
            if (_allowed && action == SpriteActionId.gentleFloat) {
              final elapsed = t * 21600;
              // Two brief idle gestures; learning cues always take priority.
              if (elapsed >= 7200 && elapsed < 7480) {
                action = SpriteActionId.blink;
                t = (elapsed - 7200) / 280;
              } else if (elapsed >= 18000 && elapsed < 19400) {
                action = SpriteActionId.leafSway;
                t = (elapsed - 18000) / 1400;
              } else {
                t = (t * 3) % 1;
              }
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
                  lift = -15 * pulse;
                case SpriteActionId.recRecording:
                  lift = 4 * pulse;
                case SpriteActionId.recDone:
                  lift = -10 * pulse;
                case SpriteActionId.quizGood:
                  lift = -27 * pulse;
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
                      child: PlushPoseImage(
                        key: ValueKey('$asset:${widget.revision}'),
                        stage: widget.decorationStage,
                        action: action,
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
