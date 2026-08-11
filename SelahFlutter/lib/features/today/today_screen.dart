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

/// Today：核心学习页（输入中文 → 生成英文 → Listen / Practice）。
class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  final _inputController = TextEditingController();
  Sentence? _current;
  bool _generating = false;
  bool _listening = false;
  String? _error;

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      final useCase = ref.read(generateSentenceUseCaseProvider);
      final sentence = await useCase.execute(sourceText: text);
      if (mounted) {
        setState(() => _current = sentence);
        _inputController.clear();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = '生成失敗，請稍後再試。');
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _listen() async {
    final sentence = _current;
    if (sentence == null) return;
    setState(() => _listening = true);
    try {
      final useCase = ref.read(listenUseCaseProvider);
      final pref = await ref.read(preferenceRepositoryProvider).get();
      await useCase.execute(
        sentence: sentence,
        voiceProfile: pref.voiceProfile,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('聆聽完成，做得很好')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = '音頻暫時無法播放，稍後再試。');
      }
    } finally {
      if (mounted) setState(() => _listening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Today'),
        actions: [
          IconButton(
            tooltip: '設定',
            onPressed: () => context.go('/settings'),
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(SelahSpacing.page),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: SelahSprite(
                  action: _current == null
                      ? SpriteActionId.gentleFloat
                      : SpriteActionId.listenComplete,
                  size: 120,
                  decorationStage: DecorationStage.leaf,
                ),
              ),
              const SizedBox(height: SelahSpacing.lg),
              Text('今天想說點什麼？', style: SelahTypography.displayMedium()),
              const SizedBox(height: SelahSpacing.xs),
              Text(
                '用中文說出真實想法，Selah 幫你變成自然英文。',
                style: SelahTypography.bodyMedium(),
              ),
              const SizedBox(height: SelahSpacing.xl),
              SelahTextField(
                controller: _inputController,
                hint: '例如：今天過得怎麼樣？',
                maxLines: 3,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: SelahSpacing.md),
              SelahPrimaryButton(
                label: _generating ? '生成中…' : '產生英文',
                icon: Icons.auto_awesome_rounded,
                onPressed: _generating || _inputController.text.trim().isEmpty
                    ? null
                    : _generate,
              ),
              if (_error != null) ...[
                const SizedBox(height: SelahSpacing.md),
                Text(_error!, style: SelahTypography.bodySmall(color: SelahColors.danger)),
              ],
              if (_current != null) ...[
                const SizedBox(height: SelahSpacing.xl),
                _CurrentSentenceCard(
                  sentence: _current!,
                  onListen: _listening ? null : _listen,
                  listening: _listening,
                ),
              ],
              const SizedBox(height: SelahSpacing.xl),
              _SeedListenRow(
                onOpen: () => context.go('/companion-gallery'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurrentSentenceCard extends StatelessWidget {
  const _CurrentSentenceCard({
    required this.sentence,
    required this.onListen,
    required this.listening,
  });

  final Sentence sentence;
  final VoidCallback? onListen;
  final bool listening;

  @override
  Widget build(BuildContext context) {
    return SelahCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(sentence.zhText, style: SelahTypography.labelLarge()),
          const SizedBox(height: SelahSpacing.sm),
          Text(sentence.enText, style: SelahTypography.headlineLarge()),
          const SizedBox(height: SelahSpacing.md),
          Wrap(
            spacing: SelahSpacing.sm,
            children: sentence.deconstruction
                .map((d) => SelahTag(
                      label: d.surfaceText,
                      color: SelahColors.lavender,
                    ))
                .toList(),
          ),
          const SizedBox(height: SelahSpacing.lg),
          SelahPrimaryButton(
            label: listening ? '播放中…' : '聆聽這句',
            icon: Icons.play_arrow_rounded,
            onPressed: onListen,
          ),
        ],
      ),
    );
  }
}

class _SeedListenRow extends StatelessWidget {
  const _SeedListenRow({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return SelahCard(
      onTap: onOpen,
      color: SelahColors.lavenderSoft,
      child: Row(
        children: [
          Icon(Icons.auto_awesome_rounded, color: SelahColors.lavender),
          const SizedBox(width: SelahSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('看看 Selah 的動作', style: SelahTypography.headlineSmall()),
                Text('10 個原生微動效', style: SelahTypography.bodySmall()),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}
