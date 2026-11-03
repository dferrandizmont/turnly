import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/theme_context.dart';
import '../domain/shift_swap.dart';
import 'swap_format.dart';

/// The state of a change: pending, returned or settled.
///
/// It says it in words, never with colour alone.
class SwapStageBadge extends StatelessWidget {
  const SwapStageBadge({super.key, required this.stage, this.swapId});

  final SwapStage stage;

  /// The change it belongs to: the key of the badge tells which one it is.
  final String? swapId;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Sp.s, vertical: Sp.xs),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: Rad.chipSmallRadius,
      ),
      child: Text(
        swapStageText(context.l10n, stage),
        key: ValueKey('swap-stage-${swapId ?? stage.name}'),
        style: type.caption.copyWith(color: colors.textSecondary),
      ),
    );
  }
}
