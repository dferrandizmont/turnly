import 'package:flutter/material.dart';

import '../../../core/icons/app_icons.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/buttons.dart';
import '../domain/calendar.dart';
import '../domain/calendar_comparison.dart';
import 'calendar_dot.dart';

/// The sheet that picks the calendars to compare (P12): between
/// [minComparedCalendars] and [maxComparedCalendars].
///
/// It returns the ids picked, in the order they were picked, or null when it
/// is dismissed without applying anything. The choice is not written: it
/// lives in the screen that opened the sheet.
Future<List<String>?> showCompareCalendarsSheet(
  BuildContext context, {
  required List<Calendar> calendars,
  required List<String> selectedIds,
}) => showAppSheet<List<String>>(
  context: context,
  padded: true,
  builder: (ctx) => CompareCalendarsSheet(
    calendars: calendars,
    selectedIds: selectedIds,
  ),
);

/// The list of the calendars of the user, with the ones being compared
/// checked. A calendar is added or taken away with a tap; the sheet refuses
/// to go below two or above six and says why.
class CompareCalendarsSheet extends StatefulWidget {
  const CompareCalendarsSheet({
    super.key,
    required this.calendars,
    required this.selectedIds,
  });

  /// Every calendar the user has (the archived ones are not offered).
  final List<Calendar> calendars;

  /// The ids being compared, in the order they were picked.
  final List<String> selectedIds;

  @override
  State<CompareCalendarsSheet> createState() => _CompareCalendarsSheetState();
}

class _CompareCalendarsSheetState extends State<CompareCalendarsSheet> {
  late final List<String> _selected = [...widget.selectedIds];

  /// Why the last tap was refused (null when it was not).
  String? _warning;

  void _toggle(Calendar calendar) {
    final l10n = context.l10n;
    setState(() {
      if (_selected.contains(calendar.id)) {
        if (_selected.length <= minComparedCalendars) {
          _warning = l10n.compareSheetMinWarning;
          return;
        }
        _selected.remove(calendar.id);
      } else {
        if (_selected.length >= maxComparedCalendars) {
          _warning = l10n.compareSheetMaxWarning;
          return;
        }
        _selected.add(calendar.id);
      }
      _warning = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final type = context.type;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.comparePickTitle, style: type.headline),
        ),
        const SizedBox(height: Sp.xs),
        Text(
          l10n.compareSheetHint,
          style: type.meta.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: Sp.m),
        for (final calendar in widget.calendars)
          _CalendarChoice(
            key: ValueKey('compare-sheet-row-${calendar.id}'),
            calendar: calendar,
            selected: _selected.contains(calendar.id),
            onTap: () => _toggle(calendar),
          ),
        if (_warning != null) ...[
          const SizedBox(height: Sp.s),
          Semantics(
            liveRegion: true,
            child: Text(
              _warning!,
              key: const ValueKey('compare-sheet-warning'),
              style: type.meta.copyWith(color: colors.danger),
            ),
          ),
        ],
        const SizedBox(height: Sp.l),
        PrimaryButton(
          key: const ValueKey('compare-sheet-done'),
          label: l10n.compareSheetDone,
          onPressed: () => Navigator.of(context).pop(_selected),
        ),
      ],
    );
  }
}

/// One calendar of the sheet: its colour, its name and whether it is being
/// compared.
class _CalendarChoice extends StatelessWidget {
  const _CalendarChoice({
    super.key,
    required this.calendar,
    required this.selected,
    required this.onTap,
  });

  final Calendar calendar;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      excludeSemantics: true,
      label: calendar.name,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: Rad.rowRadius,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Sp.xs,
              vertical: Sp.s,
            ),
            child: Row(
              children: [
                CalendarDot(
                  colorValue: calendar.colorValue,
                  size: CalendarDot.rowSize,
                ),
                const SizedBox(width: Sp.m),
                Expanded(
                  child: Text(
                    calendar.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: selected ? type.bodyStrong : type.body,
                  ),
                ),
                // The row is the button: the check only says which ones are
                // being compared.
                if (selected)
                  Icon(
                    AppIcons.check,
                    color: colors.accentStrong,
                    weight: 600,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
