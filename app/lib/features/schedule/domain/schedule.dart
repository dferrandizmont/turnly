import 'package:collection/collection.dart';

import 'civil_date.dart';
import 'pattern.dart';
import 'shift_type.dart';
import 'shift_type_history.dart';

enum DaySource { override, pattern, none }

class ResolvedDay {
  const ResolvedDay({
    required this.date,
    this.shifts = const [],
    this.source = DaySource.none,
    this.runId,
    this.stepIndex,
    this.note,
    this.overtimeMinutes = 0,
    this.earlyLeaveMinutes = 0,
  });

  final CivilDate date;
  final List<ShiftType> shifts;
  final DaySource source;

  /// Run and cycle step that produced [shifts]; only when [source] is
  /// [DaySource.pattern].
  final String? runId;
  final int? stepIndex;
  final String? note;

  /// Extra minutes worked this day (docs/paridad.md, A6); 0 = none. They
  /// belong to the day, not to a shift, and are kept whatever the shifts are.
  final int overtimeMinutes;

  /// Minutes the user left before the end of the day's shifts (A6); 0 = none.
  final int earlyLeaveMinutes;

  /// The day carries extra or missing minutes (the small «+» of the cell).
  bool get hasExtras => overtimeMinutes > 0 || earlyLeaveMinutes > 0;

  bool get isEmpty => shifts.isEmpty;

  List<String> get shiftIds => [for (final s in shifts) s.id];
}

/// Immutable rules + exceptions model. Never stores one row per day.
class Schedule {
  Schedule({
    Iterable<ShiftType> shiftTypes = const [],
    Iterable<Pattern> patterns = const [],
    Iterable<PatternRun> runs = const [],
    Map<CivilDate, DayEntry> entries = const {},
    Map<String, List<ShiftTypeVersion>> shiftTypeVersions = const {},
  }) : shiftTypes = List.unmodifiable(shiftTypes),
       patterns = List.unmodifiable(patterns),
       runs = List.unmodifiable(runs),
       entries = Map.unmodifiable(entries),
       shiftTypeVersions = Map.unmodifiable({
         for (final MapEntry(:key, :value) in shiftTypeVersions.entries)
           if (value.isNotEmpty)
             key: List<ShiftTypeVersion>.unmodifiable(sortedVersions(value)),
       });

  final List<ShiftType> shiftTypes;
  final List<Pattern> patterns;
  final List<PatternRun> runs;
  final Map<CivilDate, DayEntry> entries;

  /// Earlier terms of the shift types changed «only from today on», by type
  /// id, each list sorted by `until` (`shift_type_history.dart`). A type
  /// without versions has always had its current terms. [shiftTypes] always
  /// hold the **current** terms; [resolve] gives each day the terms it had.
  final Map<String, List<ShiftTypeVersion>> shiftTypeVersions;

  late final Map<String, ShiftType> _typeById = {
    for (final t in shiftTypes) t.id: t,
  };

  late final Map<String, Pattern> _patternById = {
    for (final p in patterns) p.id: p,
  };

  /// Runs with a known pattern, highest `seq` first (ties: last listed first).
  late final List<(PatternRun, Pattern)> _activeRuns = () {
    final list = <(PatternRun, Pattern)>[
      for (final r in runs.reversed)
        if (_patternById[r.patternId] case final p? when p.steps.isNotEmpty)
          (r, p),
    ];
    mergeSort(list, compare: (a, b) => b.$1.seq.compareTo(a.$1.seq));
    return list;
  }();

  /// The shift type [id] with its **current** terms (the editor, the
  /// palette). What a given day used is [shiftTypeOn].
  ShiftType? shiftTypeById(String id) => _typeById[id];

  /// The shift type [id] with the terms it had on [day].
  ShiftType? shiftTypeOn(String id, CivilDate day) {
    final type = _typeById[id];
    if (type == null) return null;
    final history = shiftTypeVersions[id];
    return history == null ? type : shiftTypeAsOf(type, history, day);
  }

  /// The earlier versions of [id] (sorted), empty when it has none.
  List<ShiftTypeVersion> versionsOf(String id) =>
      shiftTypeVersions[id] ?? const [];

  /// Whether a day in `[from, before)` (from the beginning when [from] is
  /// null) shows the shift type [id]: what has to be true for an edit of its
  /// current terms to change a day already gone. Exact: it resolves the
  /// candidate days (overrides and the days of the rotations whose pattern
  /// uses [id]), so a rotation step that never came, or a day covered by a
  /// newer rotation or an override, does not count.
  bool showsShiftTypeBetween(
    String id, {
    CivilDate? from,
    required CivilDate before,
  }) {
    bool inRange(CivilDate d) =>
        d.isBefore(before) && (from == null || !d.isBefore(from));
    for (final date in entries.keys) {
      if (inRange(date) && resolve(date).shiftIds.contains(id)) return true;
    }
    final last = before.addDays(-1);
    for (final run in runs) {
      final pattern = _patternById[run.patternId];
      if (pattern == null || !pattern.steps.any((s) => s.contains(id))) {
        continue;
      }
      var day = from != null && from.isAfter(run.startDate)
          ? from
          : run.startDate;
      final end = run.endDate != null && run.endDate!.isBefore(last)
          ? run.endDate!
          : last;
      for (; !day.isAfter(end); day = day.addDays(1)) {
        if (resolve(day).shiftIds.contains(id)) return true;
      }
    }
    return false;
  }

  Pattern? patternById(String id) => _patternById[id];

  /// Effective shifts of [d]: override > highest-seq run > empty.
  ResolvedDay resolve(CivilDate d) {
    final entry = entries[d];
    final ids = entry?.shiftTypeIds;
    if (ids == null) return _fromPattern(d, entry);
    return ResolvedDay(
      date: d,
      shifts: _lookup(ids, d),
      source: DaySource.override,
      note: entry!.note,
      overtimeMinutes: entry.overtimeMinutes ?? 0,
      earlyLeaveMinutes: entry.earlyLeaveMinutes ?? 0,
    );
  }

  /// What [d] would be without its manual override (the note and the extra
  /// or missing minutes are kept).
  ResolvedDay resolvePattern(CivilDate d) => _fromPattern(d, entries[d]);

  /// One [ResolvedDay] per day in `[from, to]`, both included.
  List<ResolvedDay> resolveRange(CivilDate from, CivilDate to) {
    final n = to.differenceInDays(from) + 1;
    if (n <= 0) return const [];
    return [for (var i = 0; i < n; i++) resolve(from.addDays(i))];
  }

  Schedule copyWith({
    Iterable<ShiftType>? shiftTypes,
    Iterable<Pattern>? patterns,
    Iterable<PatternRun>? runs,
    Map<CivilDate, DayEntry>? entries,
    Map<String, List<ShiftTypeVersion>>? shiftTypeVersions,
  }) => Schedule(
    shiftTypes: shiftTypes ?? this.shiftTypes,
    patterns: patterns ?? this.patterns,
    runs: runs ?? this.runs,
    entries: entries ?? this.entries,
    shiftTypeVersions: shiftTypeVersions ?? this.shiftTypeVersions,
  );

  ResolvedDay _fromPattern(CivilDate d, DayEntry? entry) {
    final note = entry?.note;
    final overtime = entry?.overtimeMinutes ?? 0;
    final earlyLeave = entry?.earlyLeaveMinutes ?? 0;
    for (final (run, pattern) in _activeRuns) {
      if (!run.covers(d)) continue;
      final step = run.stepIndexOn(d, pattern.lengthDays);
      return ResolvedDay(
        date: d,
        shifts: _lookup(pattern.steps[step], d),
        source: DaySource.pattern,
        runId: run.id,
        stepIndex: step,
        note: note,
        overtimeMinutes: overtime,
        earlyLeaveMinutes: earlyLeave,
      );
    }
    return ResolvedDay(
      date: d,
      note: note,
      overtimeMinutes: overtime,
      earlyLeaveMinutes: earlyLeave,
    );
  }

  /// The types of [ids] with the terms they had on [day]. Unknown ids
  /// (deleted types) are skipped.
  List<ShiftType> _lookup(List<String> ids, CivilDate day) {
    if (shiftTypeVersions.isEmpty) {
      return [for (final id in ids) ?_typeById[id]];
    }
    return [for (final id in ids) ?shiftTypeOn(id, day)];
  }
}
