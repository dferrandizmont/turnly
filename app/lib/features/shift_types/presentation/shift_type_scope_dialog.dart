import 'package:flutter/material.dart';

import '../../../core/format/app_date_format.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/theme_context.dart';
import '../../schedule/domain/schedule_domain.dart';

/// Which days a change of hours or money of a shift type reaches.
enum ShiftTypeEditScope {
  /// «Corregir en todos los días»: it was a mistake; every day the current
  /// terms governed changes (what an edit always did).
  everyDay,

  /// «Solo a partir de hoy»: the working hours or the rate changed; the days
  /// already gone keep what they had.
  fromToday,
}

/// Asks which days the change reaches, when the type is already on days
/// gone. [currentSince] is the first day of the current terms when the type
/// was already changed «from today» once (then «every day» only reaches back
/// to it). Returns `null` when the user cancels: nothing is saved.
Future<ShiftTypeEditScope?> showShiftTypeScopeDialog(
  BuildContext context, {
  CivilDate? currentSince,
}) {
  return showDialog<ShiftTypeEditScope>(
    context: context,
    builder: (ctx) {
      final l10n = ctx.l10n;
      final type = ctx.type;
      final allHint = currentSince == null
          ? l10n.shiftTypesScopeAllHint
          : l10n.shiftTypesScopeAllHintSince(
              AppDateFormat.of(ctx).dayMonthYear(
                DateTime(
                  currentSince.year,
                  currentSince.month,
                  currentSince.day,
                ),
              ),
            );
      return AlertDialog(
        scrollable: true,
        title: Text(l10n.shiftTypesScopeTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.shiftTypesScopeBody, style: type.body),
            const SizedBox(height: Sp.m),
            _ScopeOption(
              key: const ValueKey('shift-scope-from-today'),
              label: l10n.shiftTypesScopeFromToday,
              subtitle: l10n.shiftTypesScopeFromTodayHint,
              onTap: () => Navigator.pop(ctx, ShiftTypeEditScope.fromToday),
            ),
            _ScopeOption(
              key: const ValueKey('shift-scope-every-day'),
              label: l10n.shiftTypesScopeAll,
              subtitle: allHint,
              onTap: () => Navigator.pop(ctx, ShiftTypeEditScope.everyDay),
            ),
          ],
        ),
        actions: [
          TextButton(
            key: const ValueKey('shift-scope-cancel'),
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
        ],
      );
    },
  );
}

/// One answer of the dialog: what it does (strong) and what it means for
/// the days gone (quiet), as one button for a screen reader.
class _ScopeOption extends StatelessWidget {
  const _ScopeOption({
    super.key,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: '$label, $subtitle',
      onTap: onTap,
      child: InkWell(
        borderRadius: Rad.rowRadius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Sp.xs,
            vertical: Sp.s,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: type.bodyStrong),
              const SizedBox(height: Sp.hair),
              Text(
                subtitle,
                style: type.meta.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
