import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../design/selah_colors.dart';
import '../../design/selah_spacing.dart';
import '../../design/selah_typography.dart';
import '../../design/widgets/selah_card.dart';
import '../../domain/selah_enums.dart';
import 'selah_sprite.dart';

/// 精灵 10 动作 Gallery（开发预览入口）。
class CompanionGalleryScreen extends StatefulWidget {
  const CompanionGalleryScreen({super.key});

  @override
  State<CompanionGalleryScreen> createState() => _CompanionGalleryScreenState();
}

class _CompanionGalleryScreenState extends State<CompanionGalleryScreen> {
  bool _reduceMotion = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('精靈動作'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Reduce Motion',
            icon: Icon(
              _reduceMotion
                  ? Icons.motion_photos_off_rounded
                  : Icons.motion_photos_on_rounded,
            ),
            onPressed: () => setState(() => _reduceMotion = !_reduceMotion),
          ),
        ],
      ),
      body: SafeArea(
        child: GridView.count(
          padding: const EdgeInsets.all(SelahSpacing.page),
          crossAxisCount: 2,
          mainAxisSpacing: SelahSpacing.md,
          crossAxisSpacing: SelahSpacing.md,
          childAspectRatio: 0.92,
          children: SpriteActionId.values.map((action) {
            return SelahCard(
              color: SelahColors.cardSoft,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SelahSprite(
                    action: action,
                    size: 84,
                    reduceMotion: _reduceMotion,
                  ),
                  const SizedBox(height: SelahSpacing.md),
                  Text(action.name, style: SelahTypography.labelLarge()),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
