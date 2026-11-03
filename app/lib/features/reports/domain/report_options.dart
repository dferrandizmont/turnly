/// What a report does with the absences (vacations, personal days, sick
/// leave...). The app cannot tell a medical leave from a holiday, so every
/// absence is treated as possibly health data (`docs/informes.md`).
enum ReportAbsenceMode {
  /// The day looks empty: no mark, no legend entry, no count, no note.
  hidden,

  /// The day says only «Ausencia», in a neutral colour, without the name of
  /// the type, its colour or its note. **The default.**
  generic,

  /// The day shows the type as the user named it (and its note, when notes
  /// are included). Only when the person asks for it.
  detailed,
}

/// The choices of the report sheet. The defaults are the private ones.
class ReportOptions {
  const ReportOptions({
    this.includeNotes = false,
    this.absences = ReportAbsenceMode.generic,
    this.includeEarnings = false,
    this.weekStart = 1,
  }) : assert(weekStart == 1 || weekStart == 7);

  /// The note of each day (a list under the grid in the PDF, a column in the
  /// CSV). Notes of absence days follow [absences].
  final bool includeNotes;

  final ReportAbsenceMode absences;

  /// The estimated pay in the totals of the PDF (needs hourly rates or
  /// pluses on the shift types).
  final bool includeEarnings;

  /// First day of the weeks of the PDF grid: 1 (Monday) or 7 (Sunday), like
  /// the month screen.
  final int weekStart;

  ReportOptions copyWith({
    bool? includeNotes,
    ReportAbsenceMode? absences,
    bool? includeEarnings,
    int? weekStart,
  }) => ReportOptions(
    includeNotes: includeNotes ?? this.includeNotes,
    absences: absences ?? this.absences,
    includeEarnings: includeEarnings ?? this.includeEarnings,
    weekStart: weekStart ?? this.weekStart,
  );

  @override
  bool operator ==(Object other) =>
      other is ReportOptions &&
      other.includeNotes == includeNotes &&
      other.absences == absences &&
      other.includeEarnings == includeEarnings &&
      other.weekStart == weekStart;

  @override
  int get hashCode =>
      Object.hash(includeNotes, absences, includeEarnings, weekStart);
}
