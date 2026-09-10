import 'package:flutter/material.dart';
import 'package:selah/design/selah_colors.dart';
import 'package:selah/design/selah_theme.dart';
import 'package:selah/domain/selah_enums.dart';
import 'package:selah/web/ui/plush_companion.dart';

// Developer-only gallery. It renders the same widget as the production Web app.
void main() => runApp(const _Preview());

class _Preview extends StatefulWidget {
  const _Preview();
  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  int revision = 0;
  bool reduce = false;
  DecorationStage stage = DecorationStage.none;
  static const names = [
    '待机',
    '眨眼',
    '叶片轻摆',
    '准备聆听',
    '播放中',
    '聆听完成',
    '录音中',
    '录音完成',
    '复习顺利',
    '再试一次',
  ];
  static const stages = ['初见', '萌芽', '绿叶', '花苞', '开花'];
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Selah · C 短绒角色效果',
    theme: SelahTheme.light(),
    home: Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SELAH / COMPANION',
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 2,
                      color: SelahColors.sage,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'C · 短绒织物',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '同一个小小伙伴，陪你听、说、慢慢记住。',
                    style: TextStyle(color: SelahColors.textSecondary),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 20,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => setState(() => revision++),
                        icon: const Icon(Icons.replay_rounded, size: 18),
                        label: const Text('重播动作'),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: reduce,
                            onChanged: (value) =>
                                setState(() => reduce = value),
                          ),
                          const SizedBox(width: 8),
                          const Text('减少动态效果'),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    '成长阶段',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final entry in [
                        (DecorationStage.none, '初见'),
                        (DecorationStage.sprout, '萌芽'),
                        (DecorationStage.leaf, '绿叶'),
                        (DecorationStage.bud, '花苞'),
                        (DecorationStage.bloom, '开花'),
                      ])
                        ChoiceChip(
                          label: Text(entry.$2),
                          selected: stage == entry.$1,
                          onSelected: (_) => setState(() => stage = entry.$1),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 950
                          ? 5
                          : constraints.maxWidth >= 600
                          ? 3
                          : 2;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final action in SpriteActionId.values)
                            Container(
                              width:
                                  (constraints.maxWidth - 12 * (columns - 1)) /
                                  columns,
                              padding: const EdgeInsets.symmetric(
                                vertical: 18,
                                horizontal: 8,
                              ),
                              decoration: BoxDecoration(
                                color: SelahColors.cardSoft,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: SelahColors.border),
                              ),
                              child: Column(
                                children: [
                                  PlushCompanion(
                                    action: action,
                                    revision: revision,
                                    size: 124,
                                    reduceMotion: reduce,
                                    decorationStage: stage,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    names[action.index],
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    companionCaption(action),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: SelahColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 26),
                  Text(
                    '当前阶段：${stages[stage.index]}',
                    style: const TextStyle(color: SelahColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
