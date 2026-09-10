import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../design/selah_colors.dart';
import '../../design/selah_spacing.dart';
import '../../design/selah_typography.dart';
import '../../design/widgets/selah_card.dart';
import '../../domain/selah_enums.dart';
import '../../web/ui/plush_companion.dart';

/// 精灵五阶段 × 十动作 Gallery（开发预览入口）。
class CompanionGalleryScreen extends StatefulWidget {
  const CompanionGalleryScreen({super.key});

  @override
  State<CompanionGalleryScreen> createState() => _CompanionGalleryScreenState();
}

class _CompanionGalleryScreenState extends State<CompanionGalleryScreen> {
  bool _reduceMotion = false;
  DecorationStage _stage = DecorationStage.none;
  int _revision = 0;

  static const _stageLabels = {
    DecorationStage.none: '初见',
    DecorationStage.sprout: '萌芽',
    DecorationStage.leaf: '绿叶',
    DecorationStage.bud: '花苞',
    DecorationStage.bloom: '开花',
  };

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
            tooltip: '重播动作',
            icon: const Icon(Icons.replay_rounded),
            onPressed: () => setState(() => _revision++),
          ),
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 760
                ? 4
                : constraints.maxWidth >= 500
                ? 3
                : 2;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(SelahSpacing.page),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('成长阶段', style: SelahTypography.labelLarge()),
                  const SizedBox(height: SelahSpacing.sm),
                  Wrap(
                    spacing: SelahSpacing.sm,
                    runSpacing: SelahSpacing.sm,
                    children: [
                      for (final stage in DecorationStage.values)
                        ChoiceChip(
                          label: Text(_stageLabels[stage]!),
                          selected: stage == _stage,
                          onSelected: (_) => setState(() => _stage = stage),
                        ),
                    ],
                  ),
                  const SizedBox(height: SelahSpacing.lg),
                  Text(
                    '${_stageLabels[_stage]} · 十种动作',
                    style: SelahTypography.labelLarge(),
                  ),
                  const SizedBox(height: SelahSpacing.sm),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: columns,
                    mainAxisSpacing: SelahSpacing.md,
                    crossAxisSpacing: SelahSpacing.md,
                    childAspectRatio: 0.82,
                    children: SpriteActionId.values.map((action) {
                      return SelahCard(
                        color: SelahColors.cardSoft,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            PlushCompanion(
                              action: action,
                              revision: _revision,
                              decorationStage: _stage,
                              size: columns >= 4 ? 92 : 84,
                              reduceMotion: _reduceMotion,
                            ),
                            const SizedBox(height: SelahSpacing.md),
                            Text(
                              action.name,
                              textAlign: TextAlign.center,
                              style: SelahTypography.labelLarge(),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
