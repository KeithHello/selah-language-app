import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/domain/selah_enums.dart';
import 'package:selah/features/companion/plush_companion_poses.dart';
import 'package:selah/features/companion/selah_sprite.dart';
import 'package:selah/web/ui/plush_companion.dart';

final _testPngBytes = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  ),
);
final _testPoseImage = MemoryImage(_testPngBytes);

class _FailOnceAssetBundle extends CachingAssetBundle {
  final attempts = <String, int>{};

  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin') {
      final manifest = <String, List<Map<String, Object>>>{
        for (var action = 1; action <= 10; action++)
          'assets/sprites/PlushV4S5A${action.toString().padLeft(2, '0')}.png': [
            {
              'asset':
                  'assets/sprites/PlushV4S5A${action.toString().padLeft(2, '0')}.png',
            },
          ],
      };
      return const StandardMessageCodec().encodeMessage(manifest)!;
    }
    final attempt = attempts.update(
      key,
      (value) => value + 1,
      ifAbsent: () => 1,
    );
    if (key.endsWith('PlushV4S5A02.png') && attempt == 1) {
      throw StateError('simulated first-load failure');
    }
    return ByteData.sublistView(_testPngBytes);
  }
}

class _CountingAssetBundle extends CachingAssetBundle {
  final attempts = <String, int>{};

  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin') {
      final manifest = <String, List<Map<String, Object>>>{
        for (var action = 1; action <= 10; action++)
          'assets/sprites/PlushV4S5A${action.toString().padLeft(2, '0')}.png': [
            {
              'asset':
                  'assets/sprites/PlushV4S5A${action.toString().padLeft(2, '0')}.png',
            },
          ],
      };
      return const StandardMessageCodec().encodeMessage(manifest)!;
    }
    attempts.update(key, (value) => value + 1, ifAbsent: () => 1);
    await Future<void>.delayed(const Duration(milliseconds: 1));
    return ByteData.sublistView(_testPngBytes);
  }
}

void main() {
  Widget host({
    SpriteActionId action = SpriteActionId.gentleFloat,
    int revision = 0,
    bool reduce = false,
    bool active = true,
    DecorationStage stage = DecorationStage.sprout,
    List<String>? requestedAssets,
  }) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduce),
      child: TickerMode(
        enabled: active,
        child: Center(
          child: PlushCompanion(
            action: action,
            revision: revision,
            decorationStage: stage,
            imageProvider: (asset) {
              requestedAssets?.add(asset);
              return _testPoseImage;
            },
          ),
        ),
      ),
    ),
  );

  test('maps all five stages and ten actions to unique V4 assets', () {
    final assets = [
      for (final stage in DecorationStage.values)
        for (final action in SpriteActionId.values)
          plushPoseAsset(stage, action),
    ];
    expect(assets, hasLength(50));
    expect(assets.toSet(), hasLength(50));
    expect(
      plushPoseAsset(DecorationStage.none, SpriteActionId.gentleFloat),
      'assets/sprites/PlushV4S1A01.png',
    );
    expect(
      plushPoseAsset(DecorationStage.bloom, SpriteActionId.quizFail),
      'assets/sprites/PlushV4S5A10.png',
    );
  });

  testWidgets(
    'stage and action changes select the corresponding complete pose',
    (tester) async {
      final requested = <String>[];
      await tester.pumpWidget(host(requestedAssets: requested));
      expect(requested, contains('assets/sprites/PlushV4S2A01.png'));
      await tester.pumpWidget(
        host(
          action: SpriteActionId.quizFail,
          stage: DecorationStage.bloom,
          requestedAssets: requested,
        ),
      );
      expect(requested, contains('assets/sprites/PlushV4S5A10.png'));
    },
  );

  testWidgets('failed stage precache is retried on the next request', (
    tester,
  ) async {
    final bundle = _FailOnceAssetBundle();
    late BuildContext cacheContext;
    await tester.pumpWidget(
      MaterialApp(
        home: DefaultAssetBundle(
          bundle: bundle,
          child: Builder(
            builder: (context) {
              cacheContext = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    PlushPosePrecache.clearForTest();

    await tester.runAsync(
      () => PlushPosePrecache.ensureStage(
        cacheContext,
        DecorationStage.bloom,
        displayWidth: 80,
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.runAsync(
      () => PlushPosePrecache.ensureStage(
        cacheContext,
        DecorationStage.bloom,
        displayWidth: 80,
      ),
    );

    expect(bundle.attempts['assets/sprites/PlushV4S5A02.png'], 2);
  });

  testWidgets(
    'idle briefly blinks and sways before returning to its own pose',
    (tester) async {
      await tester.pumpWidget(host(stage: DecorationStage.bud));
      SpriteActionId pose() => tester
          .widget<PlushPoseImage>(find.byType(PlushPoseImage).last)
          .action;
      await tester.pump(const Duration(milliseconds: 7300));
      expect(pose(), SpriteActionId.blink);
      await tester.pump(const Duration(milliseconds: 500));
      expect(pose(), SpriteActionId.gentleFloat);
      await tester.pump(const Duration(milliseconds: 10300));
      expect(pose(), SpriteActionId.leafSway);
      await tester.pump(const Duration(milliseconds: 1500));
      expect(pose(), SpriteActionId.gentleFloat);
    },
  );

  testWidgets('reduced motion and hidden idle do not rotate ambient poses', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pump(const Duration(milliseconds: 7300));
    for (final reduce in [true, false]) {
      await tester.pumpWidget(host(reduce: reduce, active: reduce));
      await tester.pump(const Duration(milliseconds: 7300));
      expect(
        tester.widget<PlushPoseImage>(find.byType(PlushPoseImage)).action,
        SpriteActionId.gentleFloat,
      );
    }
  });

  testWidgets('a business action immediately replaces an ambient pose', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pump(const Duration(milliseconds: 7300));
    await tester.pumpWidget(host(action: SpriteActionId.listenPlaying));
    await tester.pump(const Duration(milliseconds: 18100));
    expect(
      tester.widget<PlushPoseImage>(find.byType(PlushPoseImage)).action,
      SpriteActionId.listenPlaying,
    );
  });

  testWidgets('concurrent stage precache requests share one warmup', (
    tester,
  ) async {
    final bundle = _FailOnceAssetBundle();
    late BuildContext cacheContext;
    await tester.pumpWidget(
      MaterialApp(
        home: DefaultAssetBundle(
          bundle: bundle,
          child: Builder(
            builder: (context) {
              cacheContext = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    PlushPosePrecache.clearForTest();

    await tester.runAsync(
      () => Future.wait([
        PlushPosePrecache.ensureStage(
          cacheContext,
          DecorationStage.bloom,
          displayWidth: 80,
        ),
        PlushPosePrecache.ensureStage(
          cacheContext,
          DecorationStage.bloom,
          displayWidth: 80,
        ),
      ]),
    );

    expect(tester.takeException(), isNull);
    expect(bundle.attempts['assets/sprites/PlushV4S5A02.png'], 1);
  });

  testWidgets('a larger concurrent precache request upgrades the warmup', (
    tester,
  ) async {
    final bundle = _CountingAssetBundle();
    late BuildContext cacheContext;
    await tester.pumpWidget(
      MaterialApp(
        home: DefaultAssetBundle(
          bundle: bundle,
          child: Builder(
            builder: (context) {
              cacheContext = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    PlushPosePrecache.clearForTest();

    await tester.runAsync(
      () => Future.wait([
        PlushPosePrecache.ensureStage(
          cacheContext,
          DecorationStage.bloom,
          displayWidth: 80,
        ),
        PlushPosePrecache.ensureStage(
          cacheContext,
          DecorationStage.bloom,
          displayWidth: 420,
        ),
      ]),
    );

    expect(tester.takeException(), isNull);
    expect(bundle.attempts['assets/sprites/PlushV4S5A01.png'], 2);
  });

  testWidgets('native SelahSprite shares the selected complete pose', (
    tester,
  ) async {
    final requested = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: SelahSprite(
          action: SpriteActionId.listenComplete,
          decorationStage: DecorationStage.bud,
          reduceMotion: true,
          imageProvider: (asset) {
            requested.add(asset);
            return _testPoseImage;
          },
        ),
      ),
    );
    expect(requested, contains('assets/sprites/PlushV4S4A06.png'));
  });

  testWidgets('native feedback is one-shot and pauses in the background', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SelahSprite(
          action: SpriteActionId.quizGood,
          reduceMotion: false,
          imageProvider: (_) => _testPoseImage,
        ),
      ),
    );
    final state = tester.state<SelahSpriteState>(find.byType(SelahSprite));
    expect(state.isAnimating, isTrue);
    await tester.pump(const Duration(milliseconds: 1200));
    expect(state.isAnimating, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    expect(state.isAnimating, isFalse);
  });

  testWidgets('native idle loop stays continuous at its turnaround', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SelahSprite(
          action: SpriteActionId.gentleFloat,
          reduceMotion: false,
          imageProvider: (_) => _testPoseImage,
        ),
      ),
    );

    double scale() {
      final transforms = tester.widgetList<Transform>(
        find.descendant(
          of: find.byType(SelahSprite),
          matching: find.byType(Transform),
        ),
      );
      return transforms.last.transform.storage[0];
    }

    await tester.pump(const Duration(milliseconds: 7199));
    final beforeTurnaround = scale();
    await tester.pump(const Duration(milliseconds: 2));
    final afterTurnaround = scale();

    expect((afterTurnaround - beforeTurnaround).abs(), lessThan(0.005));
  });

  testWidgets(
    'reduced motion stops and restarts the idle ticker when changed',
    (tester) async {
      await tester.pumpWidget(host());
      final state = tester.state<PlushCompanionState>(
        find.byType(PlushCompanion),
      );
      expect(state.isAnimating, true);
      await tester.pumpWidget(host(reduce: true));
      expect(state.isAnimating, false);
      await tester.pumpAndSettle();
      await tester.pumpWidget(host());
      expect(state.isAnimating, true);
    },
  );

  testWidgets('feedback plays once and only a new event restarts it', (
    tester,
  ) async {
    await tester.pumpWidget(host(action: SpriteActionId.quizGood));
    final state = tester.state<PlushCompanionState>(
      find.byType(PlushCompanion),
    );
    await tester.pump(const Duration(milliseconds: 1600));
    expect(state.isAnimating, false);
    await tester.pumpWidget(host(action: SpriteActionId.quizGood));
    expect(state.isAnimating, false);
    await tester.pumpWidget(host(action: SpriteActionId.quizGood, revision: 1));
    expect(state.isAnimating, true);
  });

  testWidgets('hidden or inactive companions do not keep animating', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    final state = tester.state<PlushCompanionState>(
      find.byType(PlushCompanion),
    );
    await tester.pumpWidget(host(active: false));
    expect(state.isAnimating, false);
    await tester.pumpWidget(host());
    expect(state.isAnimating, true);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    expect(state.isAnimating, false);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(state.isAnimating, true);
  });

  testWidgets('every action keeps the same frame and accessible description', (
    tester,
  ) async {
    for (final action in SpriteActionId.values) {
      await tester.pumpWidget(host(action: action, reduce: true));
      expect(tester.getSize(find.byType(PlushCompanion)), const Size(170, 204));
      expect(find.bySemanticsLabel(RegExp('Selah 精靈，')), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
