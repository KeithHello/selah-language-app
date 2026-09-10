import 'package:flutter/material.dart';

import '../../domain/selah_enums.dart';

/// Returns the versioned full-body pose for one growth stage and action.
///
/// `DecorationStage` is intentionally used as the five-stage axis, including
/// `none` as the first (newly met) stage. Keeping this as one pure mapping
/// prevents the Web and native Flutter displays from drifting apart.
String plushPoseAsset(DecorationStage stage, SpriteActionId action) {
  final stageNumber = stage.index + 1;
  final actionNumber = (action.index + 1).toString().padLeft(2, '0');
  return 'assets/sprites/PlushV4S${stageNumber}A$actionNumber.png';
}

/// Optional image-provider seam used by widget tests and local previews.
/// Production callers leave it null so Flutter resolves the packaged asset.
typedef PlushPoseImageProvider = ImageProvider<Object> Function(String asset);

/// Warms only the ten actions for a stage after that stage is first shown.
///
/// A larger display can request a second, higher-resolution warm-up for the
/// same stage. Individual asset failures stay local to the cache warm-up; the
/// displayed pose still reports its own load error through [PlushPoseImage].
class PlushPosePrecache {
  PlushPosePrecache._();

  static final _cachedWidths = <DecorationStage, int>{};
  static final _inFlight = <DecorationStage, Future<void>>{};
  static final _inFlightWidths = <DecorationStage, int>{};

  static Future<void> ensureStage(
    BuildContext context,
    DecorationStage stage, {
    required double displayWidth,
  }) async {
    var cacheWidth = (displayWidth * MediaQuery.of(context).devicePixelRatio)
        .round();
    if (cacheWidth < 256) cacheWidth = 256;
    if (cacheWidth > 768) cacheWidth = 768;

    if ((_cachedWidths[stage] ?? 0) >= cacheWidth) return;
    final existing = _inFlight[stage];
    if (existing != null) {
      final existingWidth = _inFlightWidths[stage] ?? 0;
      await existing;
      if (existingWidth >= cacheWidth ||
          (_cachedWidths[stage] ?? 0) >= cacheWidth ||
          !context.mounted) {
        return;
      }
    }

    final warmup = _warmStage(context, stage, cacheWidth);
    _inFlight[stage] = warmup;
    _inFlightWidths[stage] = cacheWidth;
    try {
      await warmup;
    } finally {
      if (identical(_inFlight[stage], warmup)) {
        _inFlight.remove(stage);
        _inFlightWidths.remove(stage);
      }
    }
  }

  static Future<void> _warmStage(
    BuildContext context,
    DecorationStage stage,
    int cacheWidth,
  ) async {
    var allLoaded = true;
    for (final action in SpriteActionId.values) {
      if (!context.mounted) {
        allLoaded = false;
        break;
      }
      Object? loadError;
      await precacheImage(
        ResizeImage(
          AssetImage(plushPoseAsset(stage, action)),
          width: cacheWidth,
        ),
        context,
        onError: (error, stackTrace) => loadError = error,
      );
      if (loadError != null) allLoaded = false;
    }
    if (allLoaded && (_cachedWidths[stage] ?? 0) < cacheWidth) {
      _cachedWidths[stage] = cacheWidth;
    }
  }

  @visibleForTesting
  static void clearForTest() {
    _cachedWidths.clear();
    _inFlight.clear();
    _inFlightWidths.clear();
  }
}

/// Displays one complete pose image without atlas cropping or facial overlays.
///
/// The image keeps its source aspect ratio with [BoxFit.contain]. A missing
/// asset is made visible as an explicit load error; it never falls back to a
/// different stage or action.
class PlushPoseImage extends StatelessWidget {
  const PlushPoseImage({
    super.key,
    required this.stage,
    required this.action,
    this.width,
    this.height,
    this.imageProvider,
  });

  final DecorationStage stage;
  final SpriteActionId action;
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
    return Image(
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
