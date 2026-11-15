import '../../schedule/domain/civil_date.dart';

enum WeeksPerShiftMode { allDays, weekdays }

/// Monday-first cycle. Weekends use the explicit calendar Libre type.
/// The builder checks the expanded length against its own limit separately.
List<List<String>> weeksPerShift({
  required List<String> shiftIds,
  required List<int> weeks,
  required WeeksPerShiftMode mode,
  required String restShiftId,
}) {
  if (shiftIds.isEmpty || shiftIds.length != weeks.length) {
    throw ArgumentError('Provide one week count per work shift');
  }
  if (weeks.any((count) => count < 1 || count > 8)) {
    throw ArgumentError.value(weeks, 'weeks', 'must be between 1 and 8');
  }
  return List.unmodifiable([
    for (var shift = 0; shift < shiftIds.length; shift++)
      for (var week = 0; week < weeks[shift]; week++)
        for (var day = 0; day < 7; day++)
          List<String>.unmodifiable([
            mode == WeeksPerShiftMode.weekdays && day >= 5
                ? restShiftId
                : shiftIds[shift],
          ]),
  ]);
}

/// Start within the first cycle week, aligned to the real Monday. For example,
/// a Wednesday starts at step 2; the first weekend remains Saturday/Sunday.
int weeksPerShiftStepOffset(CivilDate start) => start.weekday - 1;
