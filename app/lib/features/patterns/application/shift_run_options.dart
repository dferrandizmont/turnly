/// One day of a shift inside a cycle, ready to be shown as a "which one"
/// option: the cycle step it selects and everything needed to label it by its
/// run («2.º de 5 · Mañana», «Libre, después de Noche»).
///
/// Pure: no Flutter, no l10n. The screen turns [previousShiftIds] and the
/// shift's name into words through the ARB keys (`patternOccurrence*`).
class ShiftRunOption {
  const ShiftRunOption({
    required this.offset,
    required this.position,
    required this.count,
    required this.runIndex,
    required this.runCount,
    required this.previousShiftIds,
  });

  /// Cycle step (0-based) this option selects.
  final int offset;

  /// 1-based position inside the run (`position` of `count`).
  final int position;

  /// Length of the run (how many consecutive days of the shift).
  final int count;

  /// 0-based index of the run among the runs of this shift, in cycle order.
  final int runIndex;

  /// How many separate runs this shift has in the cycle. 1: no need to say
  /// which run it is.
  final int runCount;

  /// Shift ids of the day just before the run (cyclically), when that day has
  /// a shift other than the run's own; empty otherwise (an empty previous day,
  /// or one that holds only the run's own shift).
  final List<String> previousShiftIds;
}

/// Every day of the cycle that has [shiftId], one option each.
///
/// The days of a shift form *runs*: maximal stretches of consecutive days
/// (the cycle wraps, so a run can cross its end). The options come in cycle
/// order, run by run and, inside a run, from its first day to its last, so
/// the labels «1.º de N», «2.º de N»… read in order.
///
/// A shift with a single run needs no "after" part; with several runs it
/// carries the shift of the day before ([ShiftRunOption.previousShiftIds]),
/// which tells the runs apart («después de Noche»). A run at the very start
/// of the cycle takes the day before it cyclically (the last day); when that
/// day is empty or holds only the run's own shift, the run has no previous
/// shifts (and the screen drops the "after" part).
List<ShiftRunOption> shiftRunOptions(List<List<String>> steps, String shiftId) {
  final length = steps.length;
  if (length == 0) return const [];

  final has = [for (final step in steps) step.contains(shiftId)];
  final total = has.where((present) => present).length;
  if (total == 0) return const [];

  final runs = <List<int>>[];
  if (total == length) {
    // Every day: one run covering the whole cycle.
    runs.add([for (var i = 0; i < length; i++) i]);
  } else {
    for (var start = 0; start < length; start++) {
      // A run starts where the shift is and the day before it has not got it.
      if (!has[start] || has[(start - 1 + length) % length]) continue;
      final run = <int>[];
      var day = start;
      while (has[day]) {
        run.add(day);
        day = (day + 1) % length;
      }
      runs.add(run);
    }
  }

  final runCount = runs.length;
  final options = <ShiftRunOption>[];
  for (var runIndex = 0; runIndex < runs.length; runIndex++) {
    final run = runs[runIndex];
    final previous = _previousShiftIds(steps, run.first, shiftId);
    for (var i = 0; i < run.length; i++) {
      options.add(
        ShiftRunOption(
          offset: run[i],
          position: i + 1,
          count: run.length,
          runIndex: runIndex,
          runCount: runCount,
          previousShiftIds: previous,
        ),
      );
    }
  }
  return options;
}

/// The shifts of the day just before [runStart] (cyclically), when that day
/// holds a shift other than [shiftId]; empty otherwise.
///
/// Only that immediate day is looked at, never a further one: the label says
/// the run comes *after* the shift before it, and walking back past an empty
/// day (or past the run's own shift) could name a shift that actually comes
/// later in the cycle, wrapping around. A run must never be named by its own
/// shift («Mañana, después de Mañana»): an empty day cannot name it, and
/// neither can another run of the same shift.
List<String> _previousShiftIds(
  List<List<String>> steps,
  int runStart,
  String shiftId,
) {
  final length = steps.length;
  final day = (runStart - 1 + length) % length;
  final others = [
    for (final id in steps[day])
      if (id != shiftId) id,
  ];
  return others.isEmpty ? const [] : List.unmodifiable(others);
}
