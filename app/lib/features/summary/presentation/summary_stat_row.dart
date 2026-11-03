import 'package:flutter/material.dart';

import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/value_row.dart';

/// One "label ... value" line of the totals, with an optional quiet detail.
class SummaryStatRow extends StatelessWidget {
  const SummaryStatRow({
    super.key,
    required this.id,
    required this.label,
    required this.value,
    this.detail,
  });

  /// Key prefix: `<id>` for the row, `<id>-value` for the figure.
  final String id;
  final String label;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    return MergeSemantics(
      key: ValueKey(id),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Sp.s),
        child: ValueRow(
          crossAxisAlignment: CrossAxisAlignment.start,
          valueGap: Sp.m,
          title: Text(label, style: type.body),
          // The figure flush right, or under the label when the row does not
          // fit; the detail travels with it, in the same column (H-T08-1).
          value: Text(
            value,
            key: ValueKey('$id-value'),
            style: AppTypography.tabular(
              type.body.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          detail: detail == null
              ? null
              : Text(
                  detail!,
                  key: ValueKey('$id-detail'),
                  style: type.meta.copyWith(color: colors.textSecondary),
                ),
        ),
      ),
    );
  }
}
