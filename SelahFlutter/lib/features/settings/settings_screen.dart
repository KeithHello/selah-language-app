import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/container.dart';
import '../../design/selah_colors.dart';
import '../../design/selah_spacing.dart';
import '../../design/selah_typography.dart';
import '../../design/widgets/selah_card.dart';
import '../../domain/entities.dart';
import '../../domain/selah_enums.dart';

/// 设置页：声线、速度、通知。
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  UserPreference? _pref;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pref = await ref.read(preferenceRepositoryProvider).get();
    if (mounted) {
      setState(() {
        _pref = pref;
        _loaded = true;
      });
    }
  }

  Future<void> _save(UserPreference pref) async {
    await ref
        .read(preferenceRepositoryProvider)
        .save(pref.copyWith(updatedAt: DateTime.now()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('設定已儲存')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pref = _pref;
    if (!_loaded || pref == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/today'),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(SelahSpacing.page),
          children: [
            SelahCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('聲線', style: SelahTypography.headlineMedium()),
                  const SizedBox(height: SelahSpacing.sm),
                  ...VoiceProfile.values.map(
                    (voice) => InkWell(
                      onTap: () {
                        final updated = pref.copyWith(voiceProfile: voice);
                        setState(() => _pref = updated);
                        _save(updated);
                      },
                      borderRadius: BorderRadius.circular(SelahCornerRadius.sm),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: SelahSpacing.xs,
                          vertical: SelahSpacing.sm,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              pref.voiceProfile == voice
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: pref.voiceProfile == voice
                                  ? SelahColors.coral
                                  : SelahColors.textTertiary,
                              size: 22,
                            ),
                            const SizedBox(width: SelahSpacing.md),
                            Text(voice.labelZh, style: SelahTypography.bodyLarge()),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: SelahSpacing.lg),
            SelahCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('播放速度', style: SelahTypography.headlineMedium()),
                  const SizedBox(height: SelahSpacing.sm),
                  SegmentedButton<PlaybackSpeed>(
                    segments: PlaybackSpeed.values
                        .map((s) => ButtonSegment(value: s, label: Text(s.label)))
                        .toList(),
                    selected: {pref.playbackSpeed},
                    onSelectionChanged: (selection) {
                      final updated = pref.copyWith(playbackSpeed: selection.first);
                      setState(() => _pref = updated);
                      _save(updated);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: SelahSpacing.lg),
            SelahCard(
              child: SwitchListTile(
                value: pref.notificationsEnabled,
                title: Text('每日提醒', style: SelahTypography.bodyLarge()),
                subtitle: Text('提醒你今天也學一點', style: SelahTypography.bodySmall()),
                activeTrackColor: SelahColors.coral,
                onChanged: (v) {
                  final updated = pref.copyWith(notificationsEnabled: v);
                  setState(() => _pref = updated);
                  _save(updated);
                },
              ),
            ),
            const SizedBox(height: SelahSpacing.lg),
            SelahCard(
              onTap: () => context.go('/companion-gallery'),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: SelahColors.lavender),
                  const SizedBox(width: SelahSpacing.md),
                  Text('精靈動作 Gallery', style: SelahTypography.bodyLarge()),
                  const Spacer(),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
