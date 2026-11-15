import '../../schedule/domain/schedule_domain.dart';

/// A run clipped to the selected period. Ties keep the earliest run.
class WorkStreak {
  const WorkStreak(this.from, this.to);

  final CivilDate from;
  final CivilDate to;
  int get days => to.differenceInDays(from) + 1;
}

/// Only days with a work shift extend a run (the same DayKind as off_outlook).
/// Rest, absence and unrecorded days break it, even with overtime blocks.
WorkStreak? longestWorkStreak(Iterable<ResolvedDay> days) {
  WorkStreak? best;
  CivilDate? start;
  CivilDate? previous;
  for (final day in days) {
    if (day.kind != DayKind.work) {
      start = null;
      previous = null;
      continue;
    }
    if (previous == null || day.date.differenceInDays(previous) != 1) {
      start = day.date;
    }
    final run = WorkStreak(start!, day.date);
    if (best == null || run.days > best.days) best = run;
    previous = day.date;
  }
  return best;
}
