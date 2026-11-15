import 'package:flutter/material.dart';

import '../../../core/format/app_date_format.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/choice_grid.dart';
import '../../../core/widgets/choice_pill.dart';
import '../../calendar/presentation/shift_badge.dart';
import '../../calendar/presentation/shift_format.dart';
import '../../schedule/domain/schedule_domain.dart';

/// Shared by first use and the rotation wizard, directly below the date.
class RotationStartConfirmation extends StatelessWidget {
  const RotationStartConfirmation({super.key, required this.start});

  final CivilDate start;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Sp.s),
    child: Semantics(
      liveRegion: true,
      child: Text(
        context.l10n.patternStartConfirmation(
          AppDateFormat.of(context)
              .weekdayDayMonth(DateTime(start.year, start.month, start.day)),
        ),
        style: context.type.meta,
      ),
    ),
  );
}

/// The work shift of a simple work/rest rotation, separate from its offset.
class RotationWorkShiftPicker extends StatelessWidget {
  const RotationWorkShiftPicker({
    super.key,
    required this.shifts,
    required this.selectedId,
    required this.onChanged,
  });

  final List<ShiftType> shifts;
  final String selectedId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final format = AppDateFormat.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.patternWorkShiftTitle,
          style: context.type.bodyStrong,
        ),
        const SizedBox(height: Sp.m),
        ChoiceGrid.pills(
          leadingSize: Disc.s,
          pills: [
            for (final shift in shifts)
              ChoicePill(
                key: ValueKey('rotation-work-${shift.id}'),
                label: shift.name,
                detail: shift.timeRange(format),
                selected: shift.id == selectedId,
                expand: true,
                compact: true,
                radius: Rad.inputRadius,
                leading: ShiftBadge(shift: shift, size: Disc.s),
                onTap: () => onChanged(shift.id),
              ),
          ],
        ),
        const SizedBox(height: Sp.section),
      ],
    );
  }
}
