import 'package:collection/collection.dart';

import '../../patterns/domain/pattern_application.dart';
import '../../schedule/domain/schedule_domain.dart';
import 'range_editing.dart';

/// What the detail of a day can do with the rotations of the calendar
/// (`docs/motor-de-turnos.md`, «Rotación desde el día»): which rotation rules
/// the day (under a change by hand, if there is one) and which of the three
/// actions make sense on it. Pure; see [rotationDayOf].
class RotationDay {
  const RotationDay({
    required this.date,
    this.run,
    this.pattern,
    this.stepIndex,
    this.canEndHere = false,
    this.ended,
    this.endedPattern,
    this.resumeUntil,
  });

  final CivilDate date;

  /// The rotation that rules [date] (the one of the highest `seq` that
  /// covers it), its pattern and the step of the cycle that falls on [date].
  /// `null` on a day without rotation.
  final PatternRun? run;
  final Pattern? pattern;
  final int? stepIndex;

  /// «Empezar la rotación aquí»: [run] starts over on [date], which becomes
  /// the first day of the cycle. Not offered when [date] already is the
  /// first day of the cycle: nothing would change.
  bool get canRestart => run != null && stepIndex != 0;

  /// «Último día de esta rotación»: [run] ends on [date]. Not offered when
  /// it already ends there.
  final bool canEndHere;

  /// On a day without rotation, the last rotation that ended before [date]
  /// (the latest end; the highest `seq` between two that end together) and
  /// its pattern: «Empezar tu rotación aquí» takes it up again. `null` when
  /// the day has a rotation or none has ended before it.
  final PatternRun? ended;
  final Pattern? endedPattern;

  /// The last day [ended] would cover when it is taken up on [date]: the day
  /// before the next rotation starts, or `null` (no end) when none does.
  final CivilDate? resumeUntil;

  bool get canResume => ended != null;

  bool get hasActions => canRestart || canEndHere || canResume;
}

/// The rotation of [date] in [schedule] and what can be done with it.
RotationDay rotationDayOf(Schedule schedule, CivilDate date) {
  final day = schedule.resolvePattern(date);
  final run = day.runId == null
      ? null
      : schedule.runs.firstWhereOrNull((r) => r.id == day.runId);
  if (run != null) {
    return RotationDay(
      date: date,
      run: run,
      pattern: schedule.patternById(run.patternId),
      stepIndex: day.stepIndex,
      canEndHere: run.endDate != date,
    );
  }

  PatternRun? ended;
  CivilDate? nextStart;
  for (final r in schedule.runs) {
    final pattern = schedule.patternById(r.patternId);
    // The engine ignores a run without pattern or without days.
    if (pattern == null || pattern.steps.isEmpty) continue;
    if (r.startDate.isAfter(date)) {
      if (nextStart == null || r.startDate.isBefore(nextStart)) {
        nextStart = r.startDate;
      }
      continue;
    }
    final end = r.endDate;
    if (end == null || !end.isBefore(date)) continue;
    final best = ended;
    if (best == null ||
        end.isAfter(best.endDate!) ||
        (end == best.endDate && r.seq > best.seq)) {
      ended = r;
    }
  }
  return RotationDay(
    date: date,
    ended: ended,
    endedPattern: ended == null ? null : schedule.patternById(ended.patternId),
    resumeUntil: ended == null ? null : nextStart?.addDays(-1),
  );
}

/// «Empezar la rotación aquí»: the rotation that rules [date] starts over on
/// [date] (first day of its cycle), as ONE undoable step. It is the same as
/// applying its pattern from [date] (`applyPattern`): the rotation is cut at
/// `date - 1`, the days before do not change and the days changed by hand
/// stay as they are. A rotation with an end keeps it.
///
/// As when a pattern is applied without an end, a rotation that started after
/// [date] on top of this one is removed (see [restartCoversOtherRuns], which
/// the confirmation uses to say so). [seq], [postNightAuto] and [palette] are
/// those of [planPatternApplication].
///
/// `null` when no rotation rules [date] or [date] already is the first day
/// of the cycle.
PatternApplication? planRestartRun(
  Schedule schedule,
  CivilDate date, {
  required int seq,
  bool postNightAuto = false,
  Iterable<ShiftType>? palette,
}) {
  final day = rotationDayOf(schedule, date);
  final run = day.run;
  final pattern = day.pattern;
  if (run == null || pattern == null || !day.canRestart) return null;
  final plan = _planDayRotation(
    schedule,
    PatternRequest(pattern: pattern, from: date, until: run.endDate),
    seq: seq,
    postNightAuto: postNightAuto,
    palette: palette,
  );
  // Without an end `applyPattern` has already cut the rotation at `date - 1`.
  // With one it leaves the old rotation whole under the new one: cut it too,
  // so it does not come back if the new one is ended or removed later.
  if (run.endDate == null) return plan;
  final runsAfter = [
    for (final r in plan.change.runsAfter ?? plan.schedule.runs)
      if (r.id == run.id) r.copyWith(endDate: date.addDays(-1)) else r,
  ];
  return PatternApplication(
    schedule: plan.schedule.copyWith(runs: runsAfter),
    change: ScheduleChange(
      patch: plan.change.patch,
      runsBefore: plan.change.runsBefore,
      runsAfter: runsAfter,
    ),
    newTypes: plan.newTypes,
    newPattern: plan.newPattern,
    postNightDays: plan.postNightDays,
  );
}

/// Whether [planRestartRun] on [date] changes days that another rotation
/// rules now: one applied later (higher `seq`) that starts after [date],
/// while the rotation of [date] still lasts. The restarted rotation is the
/// newest one, so it covers (or removes) it.
bool restartCoversOtherRuns(Schedule schedule, CivilDate date) {
  final run = rotationDayOf(schedule, date).run;
  if (run == null) return false;
  final end = run.endDate;
  return schedule.runs.any(
    (r) =>
        r.id != run.id &&
        r.seq > run.seq &&
        schedule.patternById(r.patternId) != null &&
        r.startDate.isAfter(date) &&
        (end == null || !r.startDate.isAfter(end)),
  );
}

/// What [planEndRunOn] gives: the step, the rotation that ends and the one
/// that rules the day after once it has ended (`null` = no rotation).
class RunEndPlan {
  const RunEndPlan({required this.change, required this.run, this.next});

  final ScheduleChange change;
  final PatternRun run;

  /// The rotation that rules the day after the last one: an earlier rotation
  /// that was still running under this one, or one that starts that day.
  final PatternRun? next;
}

/// «Último día de esta rotación»: the rotation that rules [date] ends on
/// [date], as ONE undoable step ([planEndRun] with the day after). The days
/// changed by hand stay. `null` when no rotation rules [date] or it already
/// ends there.
RunEndPlan? planEndRunOn(Schedule schedule, CivilDate date) {
  final run = rotationDayOf(schedule, date).run;
  if (run == null) return null;
  final next = date.addDays(1);
  final change = planEndRun(schedule, run.id, next);
  if (change == null) return null;
  final nextRunId = schedule.apply(change).resolvePattern(next).runId;
  return RunEndPlan(
    change: change,
    run: run,
    next: nextRunId == null
        ? null
        : schedule.runs.firstWhereOrNull((r) => r.id == nextRunId),
  );
}

/// «Empezar tu rotación aquí»: on a day without rotation, the last one that
/// ended before [date] applies again from [date], with [stepOffset] as the
/// day of the cycle that falls on [date], as ONE undoable step. It has no
/// end, unless another rotation starts later: then it lasts until the day
/// before ([RotationDay.resumeUntil]) and that rotation is not touched. The
/// days before [date] and the days changed by hand stay.
///
/// `null` when [date] has a rotation or none has ended before it.
PatternApplication? planResumeRun(
  Schedule schedule,
  CivilDate date, {
  required int seq,
  int stepOffset = 0,
  bool postNightAuto = false,
  Iterable<ShiftType>? palette,
}) {
  final day = rotationDayOf(schedule, date);
  final pattern = day.endedPattern;
  if (pattern == null) return null;
  return _planDayRotation(
    schedule,
    PatternRequest(
      pattern: pattern,
      from: date,
      until: day.resumeUntil,
      stepOffset: stepOffset % pattern.lengthDays,
    ),
    seq: seq,
    postNightAuto: postNightAuto,
    palette: palette,
  );
}

/// Day-detail actions keep every original override, even an empty day or
/// Libre, and never write automatic Saliente outside the announced interval.
PatternApplication _planDayRotation(
  Schedule schedule,
  PatternRequest request, {
  required int seq,
  required bool postNightAuto,
  required Iterable<ShiftType>? palette,
}) => planPatternApplication(
  schedule,
  request,
  seq: seq,
  postNightAuto: postNightAuto,
  palette: palette,
  postNightTargetAllowed: (target) =>
      !target.isBefore(request.from) &&
      (request.until == null || !target.isAfter(request.until!)) &&
      schedule.entries[target]?.shiftTypeIds == null,
);
