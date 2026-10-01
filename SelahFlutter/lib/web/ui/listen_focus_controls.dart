import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/selah_colors.dart';
import '../../design/selah_typography.dart';
import '../l10n/selah_strings.dart';

class ListenFocusControls extends StatelessWidget {
  const ListenFocusControls({
    super.key,
    required this.uiLocale,
    required this.playbackState,
    required this.busy,
    required this.onPlayback,
    this.onPrevious,
    this.onNext,
  });

  final String uiLocale;
  final Map<String, dynamic> playbackState;
  final bool busy;
  final Future<void> Function() onPlayback;
  final Future<void> Function()? onPrevious;
  final Future<void> Function()? onNext;

  @override
  Widget build(BuildContext context) {
    final strings = SelahStrings.of(uiLocale);
    final state = playbackState['state'] as String? ?? 'idle';
    final loading = state == 'loading';
    final enabled = !busy && !loading;
    final playbackLabel = switch (state) {
      'loading' => strings.text('listen.preparing'),
      'playing' => strings.text('common.pause'),
      'paused' => strings.text('listen.resume'),
      'ended' => strings.text('listen.replay'),
      _ => strings.text('common.play'),
    };
    final playbackIcon = switch (state) {
      'loading' => const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      'playing' => const Icon(Icons.pause_rounded, size: 20),
      'ended' => const Icon(Icons.replay_rounded, size: 20),
      _ => const Icon(Icons.play_arrow_rounded, size: 20),
    };

    return Row(
      children: [
        Expanded(
          child: _ListenControlButton(
            buttonKey: const ValueKey('listen-previous'),
            label: strings.text('listen.previous'),
            icon: const Icon(Icons.skip_previous_rounded, size: 20),
            onPressed: enabled ? _onPressed(onPrevious) : null,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ListenControlButton(
            buttonKey: const ValueKey('listen-playback'),
            label: playbackLabel,
            icon: playbackIcon,
            onPressed: enabled ? _onPressed(onPlayback) : null,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ListenControlButton(
            buttonKey: const ValueKey('listen-next'),
            label: strings.text('listen.nextPlay'),
            icon: const Icon(Icons.skip_next_rounded, size: 20),
            primary: true,
            onPressed: enabled ? _onPressed(onNext) : null,
          ),
        ),
      ],
    );
  }

  VoidCallback? _onPressed(Future<void> Function()? callback) =>
      callback == null ? null : () => unawaited(callback());
}

class _ListenControlButton extends StatelessWidget {
  const _ListenControlButton({
    required this.buttonKey,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.primary = false,
  });

  final Key buttonKey;
  final String label;
  final Widget icon;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final child = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 20, height: 20, child: Center(child: icon)),
        const SizedBox(height: 3),
        Text(
          label,
          textAlign: TextAlign.center,
          style: SelahTypography.bodySmall(),
        ),
      ],
    );
    final button = primary
        ? FilledButton(
            key: buttonKey,
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              backgroundColor: SelahColors.coral,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: child,
          )
        : OutlinedButton(
            key: buttonKey,
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              foregroundColor: SelahColors.textSecondary,
              side: const BorderSide(color: SelahColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: child,
          );
    return Tooltip(message: label, child: button);
  }
}
