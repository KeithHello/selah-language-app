import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/container.dart';
import '../../design/selah_colors.dart';
import '../../design/selah_spacing.dart';
import '../../design/selah_typography.dart';
import '../../design/widgets/selah_button.dart';
import '../../design/widgets/selah_card.dart';
import '../../design/widgets/selah_text_field.dart';
import '../../domain/entities.dart';
import '../../domain/selah_enums.dart';
import '../companion/selah_sprite.dart';

/// Onboarding：命名精灵、选择 3 个种子句、保存偏好。
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _nameController = TextEditingController();
  final Set<String> _selectedSeeds = {};
  bool _saving = false;

  static const _seedOptions = [
    ('seed-001', 'Pulled another all-nighter at work. I literally can\'t even.', '工作'),
    ('seed-002', 'Boss is making empty promises again.', '工作'),
    ('seed-006', 'I want to learn English.', '學習'),
    ('seed-010', 'This week has been very busy.', '生活'),
    ('seed-015', 'Dinner plans are never simple.', '生活'),
    ('seed-020', 'I miss my old friends.', '心情'),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先幫精靈取一個名字')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final db = ref.read(localDatabaseProvider);
      await db.insertCompanion(
        Companion(
          id: 'companion-1',
          name: name,
          decorationStage: DecorationStage.sprout,
          createdAt: DateTime.now(),
        ),
      );
      await db.insertPreference(const UserPreference());
      if (mounted) context.go('/today');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(SelahSpacing.page),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: SelahSpacing.lg),
              Center(
                child: SelahSprite(
                  action: SpriteActionId.gentleFloat,
                  size: 140,
                  decorationStage: DecorationStage.sprout,
                ),
              ),
              const SizedBox(height: SelahSpacing.lg),
              Text('歡迎來到 Selah', style: SelahTypography.displayMedium()),
              const SizedBox(height: SelahSpacing.sm),
              Text(
                '一隻安靜陪伴你學英文的小精靈。先幫它取個名字吧。',
                style: SelahTypography.bodyMedium(),
              ),
              const SizedBox(height: SelahSpacing.xl),
              SelahTextField(
                controller: _nameController,
                label: '精靈的名字',
                hint: '例如：小芽',
              ),
              const SizedBox(height: SelahSpacing.xl),
              Text('挑 3 句開始學習', style: SelahTypography.headlineMedium()),
              const SizedBox(height: SelahSpacing.md),
              ..._seedOptions.map(
                (option) => Padding(
                  padding: const EdgeInsets.only(bottom: SelahSpacing.sm),
                  child: _SeedOptionCard(
                    id: option.$1,
                    en: option.$2,
                    category: option.$3,
                    selected: _selectedSeeds.contains(option.$1),
                    onTap: () {
                      setState(() {
                        if (_selectedSeeds.contains(option.$1)) {
                          _selectedSeeds.remove(option.$1);
                        } else {
                          _selectedSeeds.add(option.$1);
                        }
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: SelahSpacing.xl),
              SelahPrimaryButton(
                label: _saving ? '準備中…' : '開始學習',
                onPressed: _saving ? null : _complete,
                icon: Icons.arrow_forward_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeedOptionCard extends StatelessWidget {
  const _SeedOptionCard({
    required this.id,
    required this.en,
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final String id;
  final String en;
  final String category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SelahCard(
      onTap: onTap,
      color: selected ? SelahColors.coralSoft : null,
      child: Row(
        children: [
          Icon(
            selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: selected ? SelahColors.coral : SelahColors.textTertiary,
            size: 22,
          ),
          const SizedBox(width: SelahSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(en, style: SelahTypography.bodyLarge()),
                const SizedBox(height: 2),
                Text(category, style: SelahTypography.labelSmall()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
