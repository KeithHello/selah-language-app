import 'package:flutter/material.dart';

import '../../design/selah_colors.dart';
import '../../design/selah_motion.dart';
import '../../design/selah_typography.dart';
import '../domain/learning_models.dart';
import '../l10n/selah_strings.dart';

/// The onboarding start action used by the Web client.
///
/// The business rules stay in the parent page. This widget only reflects the
/// current selection/name/busy state and invokes [onStart] when the action is
/// valid. Keeping the validation inputs explicit prevents the floating affordance
/// from silently starting an incomplete onboarding session.
class WebStartAction extends StatelessWidget {
  const WebStartAction({
    super.key,
    required this.selectedCount,
    required this.hasName,
    required this.busy,
    required this.onStart,
    this.uiLocale = defaultUiLocale,
  });

  final int selectedCount;
  final bool hasName;
  final bool busy;
  final VoidCallback onStart;

  /// Kept optional for the standalone widget tests; the Web onboarding page
  /// always passes the user's persisted locale.
  final String uiLocale;

  SelahStrings get _strings => SelahStrings.of(uiLocale);

  bool get _enabled => hasName && selectedCount >= 5 && !busy;

  String get _status {
    if (busy) return _strings.submitLabel(busy: true, long: false);
    if (!hasName) return _strings.text('onboarding.nameRequired');
    if (selectedCount < 5) {
      return _strings.message('onboarding.selectedCount', {
        'count': '$selectedCount',
      });
    }
    return _strings.text('onboarding.ready');
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _enabled;
    final status = _status;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MergeSemantics(
            child: Semantics(
              button: true,
              enabled: enabled,
              label: _strings.text('onboarding.start'),
              hint: status,
              child: Tooltip(
                message: _strings.text('onboarding.start'),
                excludeFromSemantics: true,
                child: SizedBox.square(
                  dimension: 64,
                  child: FilledButton(
                    onPressed: enabled ? onStart : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: SelahColors.coral,
                      foregroundColor: SelahColors.textOnAccent,
                      disabledBackgroundColor: SelahColors.coral.withValues(
                        alpha: .34,
                      ),
                      disabledForegroundColor: SelahColors.textOnAccent
                          .withValues(alpha: .78),
                      fixedSize: const Size.square(64),
                      minimumSize: const Size.square(64),
                      maximumSize: const Size.square(64),
                      padding: EdgeInsets.zero,
                      elevation: enabled ? 2 : 0,
                      shape: const CircleBorder(),
                      animationDuration: reducedMotion
                          ? Duration.zero
                          : SelahMotion.quick,
                    ),
                    child: _ActionIcon(
                      busy: busy,
                      reducedMotion: reducedMotion,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: ExcludeSemantics(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _strings.text('onboarding.start'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SelahTypography.headlineSmall(
                      color: enabled
                          ? SelahColors.textPrimary
                          : SelahColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SelahTypography.bodySmall(
                      color: busy
                          ? SelahColors.coral
                          : enabled
                          ? SelahColors.sage
                          : SelahColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({required this.busy, required this.reducedMotion});

  final bool busy;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    if (!busy) {
      return const ExcludeSemantics(
        child: Icon(Icons.arrow_forward_rounded, size: 28),
      );
    }
    if (reducedMotion) {
      return const ExcludeSemantics(
        child: Icon(Icons.hourglass_top_rounded, size: 25),
      );
    }
    return const ExcludeSemantics(
      child: SizedBox.square(
        dimension: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          valueColor: AlwaysStoppedAnimation<Color>(SelahColors.textOnAccent),
        ),
      ),
    );
  }
}
