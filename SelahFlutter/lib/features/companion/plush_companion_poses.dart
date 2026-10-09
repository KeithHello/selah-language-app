import 'package:flutter/material.dart';

import '../../design/selah_motion_scope.dart';
import '../../domain/selah_enums.dart';

/// Returns the versioned full-body pose for one growth stage and action.
///
/// `DecorationStage` is intentionally used as the five-stage axis, including
/// `none` as the first (newly met) stage. Keeping this as one pure mapping
/// prevents the Web and native Flutter displays from drifting apart.
String plushPoseAsset(DecorationStage stage, SpriteActionId action) {
  final stageNumber = stage.index + 1;
  final actionNumber = (action.index + 1).toString().padLeft(2, '0');
  return 'assets/sprites/PlushV4S${stageNumber}A$actionNumber.webp';
}

/// Optional image-provider seam used by widget tests and local previews.
/// Production callers leave it null so Flutter resolves the packaged asset.
typedef PlushPoseImageProvider = ImageProvider<Object> Function(String asset);

/// Bounds pose warm-up so the currently visible pose loads first and the
/// remaining actions of a stage trickle in afterwards, without competing
/// with input, transitions, or hidden pages.
class PlushPosePrecache {
  PlushPosePrecache._();

  static final _cachedWidths = <String, int>{};
  static final _inFlight = <String, Future<void>>{};

  static int _resolveCacheWidth(BuildContext context, double displayWidth) {
    var cacheWidth = (displayWidth * MediaQuery.of(context).devicePixelRatio)
        .round();
    if (cacheWidth < 256) cacheWidth = 256;
    if (cacheWidth > 768) cacheWidth = 768;
    return cacheWidth;
  }

  /// Warms exactly one pose; repeated calls share or skip work.
  static Future<void> ensurePose(
    BuildContext context,
    DecorationStage stage,
    SpriteActionId action, {
    required double displayWidth,
  }) {
    final asset = plushPoseAsset(stage, action);
    final cacheWidth = _resolveCacheWidth(context, displayWidth);
    if ((_cachedWidths[asset] ?? 0) >= cacheWidth) return Future.value();
    final key = '$asset@$cacheWidth';
    final existing = _inFlight[key];
    if (existing != null) return existing;
    final warmup = _warmAsset(context, asset, cacheWidth);
    _inFlight[key] = warmup;
    return warmup.whenComplete(() {
      if (identical(_inFlight[key], warmup)) _inFlight.remove(key);
    });
  }

  /// Warms the remaining actions of [stage] one at a time so background
  /// work never bursts. A failed pose is retried on the next request.
  static Future<void> warmRemaining(
    BuildContext context,
    DecorationStage stage, {
    required double displayWidth,
    SpriteActionId? skip,
  }) async {
    for (final action in SpriteActionId.values) {
      if (!context.mounted) return;
      if (action == skip) continue;
      await ensurePose(context, stage, action, displayWidth: displayWidth);
    }
  }

  /// Warms every action of a stage; kept for offline preparation callers.
  static Future<void> ensureStage(
    BuildContext context,
    DecorationStage stage, {
    required double displayWidth,
  }) {
    return warmRemaining(context, stage, displayWidth: displayWidth);
  }

  static Future<void> _warmAsset(
    BuildContext context,
    String asset,
    int cacheWidth,
  ) async {
    Object? loadError;
    await precacheImage(
      ResizeImage(AssetImage(asset), width: cacheWidth),
      context,
      onError: (error, stackTrace) => loadError = error,
    );
    if (loadError == null && (_cachedWidths[asset] ?? 0) < cacheWidth) {
      _cachedWidths[asset] = cacheWidth;
    }
  }

  @visibleForTesting
  static void clearForTest() {
    _cachedWidths.clear();
    _inFlight.clear();
  }
}

/// Displays one complete pose image without atlas cropping or facial overlays.
///
/// The image keeps its source aspect ratio with [BoxFit.contain]. A missing
/// asset is made visible as an explicit load error; it never falls back to a
/// different stage or action. Multi-frame source assets pause whenever the
/// app-level motion switch is off.
class PlushPoseImage extends StatelessWidget {
  const PlushPoseImage({
    super.key,
    required this.stage,
    required this.action,
    this.animated = true,
    this.width,
    this.height,
    this.imageProvider,
  });

  final DecorationStage stage;
  final SpriteActionId action;
  final bool animated;
  final double? width;
  final double? height;
  final PlushPoseImageProvider? imageProvider;

  @override
  Widget build(BuildContext context) {
    final asset = plushPoseAsset(stage, action);
    final baseImage = imageProvider?.call(asset) ?? AssetImage(asset);
    final image = imageProvider == null
        ? ResizeImage(baseImage, width: _cacheWidth(context))
        : baseImage;
    return TickerMode(
      enabled: animated && MotionScope.of(context),
      child: Image(
        image: image,
        width: width,
        height: height,
        fit: BoxFit.contain,
        alignment: Alignment.bottomCenter,
        filterQuality: FilterQuality.high,
        // Do not retain the previous stage/action while this asset resolves.
        // The transition must never look like a different growth stage.
        gaplessPlayback: false,
        excludeFromSemantics: true,
        errorBuilder: (context, error, stackTrace) => Semantics(
          container: true,
          image: true,
          label: 'Selah 精灵姿态素材加载失败',
          child: const SizedBox.expand(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.fromBorderSide(
                  BorderSide(color: Color(0xFFD5B3A9)),
                ),
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              child: Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  color: Color(0xFFD07A68),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  int _cacheWidth(BuildContext context) {
    var cacheWidth = ((width ?? 0) * MediaQuery.of(context).devicePixelRatio)
        .round();
    if (cacheWidth < 256) cacheWidth = 256;
    if (cacheWidth > 768) cacheWidth = 768;
    return cacheWidth;
  }
}
