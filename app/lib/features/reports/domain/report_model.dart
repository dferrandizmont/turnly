import '../../holidays/domain/holiday.dart';
import '../../schedule/domain/schedule_domain.dart';
import '../../summary/domain/month_summary.dart';
import '../../summary/domain/period_hours.dart';
import '../../summary/domain/summary_range.dart';
import 'report_options.dart';

/// Colour of the absences shown as a plain «Ausencia» (a neutral grey, so
/// the shade of the real type, which could tell what it is, never leaves the
/// phone). ARGB.
const int reportNeutralAbsenceColor = 0xFF8A8A93;

/// One shift of a day as the report prints it: already stripped of whatever
/// the [ReportOptions] keep private. [genericAbsence] shifts have no real
/// code or name; the renderers write the localized «Ausencia» instead.
class ReportShift {
  const ReportShift({
    required this.code,
    required this.name,
    required this.colorValue,
    required this.category,
    this.startMinute,
    this.endMinute,
    this.segment2StartMinute,
    this.segment2EndMinute,
    this.location,
    this.genericAbsence = false,
  });

  /// The shift as the user defined it.
  factory ReportShift.of(ShiftType type) => ReportShift(
    code: type.code,
    name: type.name,
    colorValue: type.colorValue,
    category: type.category,
    startMinute: type.startMinute,
    endMinute: type.endMinute,
    segment2StartMinute: type.segment2StartMinute,
    segment2EndMinute: type.segment2EndMinute,
    location: type.location,
  );

  /// A neutral «Ausencia» that says nothing of the real type.
  const ReportShift.genericAbsence()
    : code = '',
      name = '',
      colorValue = reportNeutralAbsenceColor,
      category = ShiftCategory.absence,
      startMinute = null,
      endMinute = null,
      segment2StartMinute = null,
      segment2EndMinute = null,
      location = null,
      genericAbsence = true;

  final String code;
  final String name;
  final int colorValue;
  final ShiftCategory category;

  /// Minutes since 00:00 of the (first) segment; both null without times.
  final int? startMinute;
  final int? endMinute;

  /// Second segment of a split shift; both null without one.
  final int? segment2StartMinute;
  final int? segment2EndMinute;

  /// Where the shift is worked (P9, fila 16): free text the user wrote, or
  /// `null` when the type has no place. It is not a text of the app: the
  /// report writes it as it is.
  final String? location;

  final bool genericAbsence;

  bool get hasTimes => startMinute != null && endMinute != null;
  bool get hasSegment2 =>
      segment2StartMinute != null && segment2EndMinute != null;

  /// Minute of the day where the shift starts / ends (the last segment).
  int? get firstStart => startMinute;
  int? get lastEnd => hasSegment2 ? segment2EndMinute : endMinute;

  /// Whether two shifts print the same (legend de-duplication).
  bool sameLook(ReportShift other) =>
      code == other.code &&
      name == other.name &&
      colorValue == other.colorValue &&
      location == other.location &&
      genericAbsence == other.genericAbsence;
}

/// A block of extra hours of a report day (schema v7): the block (its note
/// only when the options and the day's absences allow notes), its type and
/// what it earns (only when the report shows money and it is paid).
class ReportOvertime {
  const ReportOvertime({
    required this.block,
    required this.type,
    this.amountCents,
  });

  final OvertimeBlock block;
  final OvertimeType type;
  final int? amountCents;

  @override
  bool operator ==(Object other) =>
      other is ReportOvertime &&
      other.block == block &&
      other.type == type &&
      other.amountCents == amountCents;

  @override
  int get hashCode => Object.hash(block, type, amountCents);
}

/// A day of the report.
class ReportDay {
  const ReportDay({
    required this.date,
    this.shifts = const [],
    this.holidayName,
    this.note,
    this.workedMinutes = 0,
    this.overtimeMinutes = 0,
    this.overtimeBlocks = const [],
    this.earlyLeaveMinutes = 0,
    this.extraAmountCents = 0,
  });

  final CivilDate date;
  final List<ReportShift> shifts;

  /// Name of the public holiday, or `null`.
  final String? holidayName;

  /// The note, only when the options include it and the day's absences allow
  /// it. Never blank.
  final String? note;

  /// Paid minutes of the day (shifts and extras, [MonthSummary] definition).
  final int workedMinutes;
  final int overtimeMinutes;

  /// The day's blocks of extra hours, by start (schema v7).
  final List<ReportOvertime> overtimeBlocks;
  final int earlyLeaveMinutes;

  /// Extra money of the day (P9, fila 26: diets, mileage, a bonus; negative
  /// for a deduction), in the minor unit of the currency. `0` when the day
  /// has none.
  final int extraAmountCents;

  bool get isHoliday => holidayName != null;
  bool get isEmpty => shifts.isEmpty && workedMinutes == 0;
}

/// A line of the legend: one kind of shift and the days it appears.
class ReportLegendEntry {
  const ReportLegendEntry({required this.shift, required this.days});

  final ReportShift shift;
  final int days;
}

/// A public holiday inside the report.
class ReportHoliday {
  const ReportHoliday(this.date, this.name);

  final CivilDate date;
  final String name;
}

/// Everything a report prints, computed once from the engine ([Schedule])
/// and the summary ([summarizeRange]) and shared by the PDF and the CSV, so
/// both say the same. Pure Dart: no texts, no fonts, no files.
class ReportModel {
  const ReportModel({
    required this.calendarName,
    required this.range,
    required this.options,
    required this.days,
    required this.legend,
    required this.holidays,
    required this.summary,
    required this.hours,
  });

  /// Name of the calendar (may be empty: the renderer then uses a fallback).
  final String calendarName;
  final SummaryRange range;
  final ReportOptions options;
  final List<ReportDay> days;
  final List<ReportLegendEntry> legend;
  final List<ReportHoliday> holidays;

  /// The aggregate of the whole period, with the definitions of the summary.
  final MonthSummary summary;

  /// Worked / planned hours split at today.
  final PeriodHours hours;

  /// Whether the absences are counted and listed at all.
  bool get showsAbsences => options.absences != ReportAbsenceMode.hidden;

  /// Estimated pay, only when the options include it and there is one.
  int? get earningsCents =>
      options.includeEarnings ? summary.earningsCents : null;

  /// The extra money of the days of the period (P9, fila 26): diets,
  /// mileage, bonuses. It is already inside [earningsCents] (the estimate of
  /// the summary adds it up), but the reports show it on its own line.
  int get extraAmountCents => summary.extraAmountCents;

  /// Days that carry a note (to list them under the grid).
  List<ReportDay> get notedDays => [
    for (final d in days)
      if (d.note != null) d,
  ];
}

/// Builds the [ReportModel] of [range] for [schedule].
///
/// [holidays] are the holidays of the user's place; [today] splits worked
/// from planned hours. Absence days follow [ReportOptions.absences] (see
/// [ReportAbsenceMode]); the notes of a day with an absence are kept only
/// when the absences are `detailed`, because a note on a sick-leave day can
/// be about health.
///
/// [range] must be valid (1 to 366 days).
ReportModel buildReport({
  required Schedule schedule,
  required SummaryRange range,
  required String calendarName,
  required Map<CivilDate, Holiday> holidays,
  required CivilDate today,
  ReportOptions options = const ReportOptions(),
}) {
  assert(range.isValid, 'The report range must be 1 to 366 days');
  final holidayDates = holidays.keys.toSet();
  final summary = summarizeRange(
    schedule,
    range.from,
    range.to,
    holidays: holidayDates,
  );
  final hours = splitPeriodHours(schedule, range.from, range.to, today);
  final mode = options.absences;

  final days = <ReportDay>[];
  for (final resolved in schedule.resolveRange(range.from, range.to)) {
    final date = resolved.date;
    final hasAbsence = resolved.shifts.any(
      (s) => s.category == ShiftCategory.absence,
    );

    final shifts = <ReportShift>[];
    var genericAdded = false;
    for (final type in resolved.shifts) {
      if (type.category != ShiftCategory.absence) {
        shifts.add(ReportShift.of(type));
        continue;
      }
      switch (mode) {
        case ReportAbsenceMode.hidden:
          break;
        case ReportAbsenceMode.generic:
          if (!genericAdded) {
            shifts.add(const ReportShift.genericAbsence());
            genericAdded = true;
          }
        case ReportAbsenceMode.detailed:
          shifts.add(ReportShift.of(type));
      }
    }

    String? note;
    // The notes of the day (and of its extra hours) only when the options
    // and the day's absences allow them.
    final notesShown =
        options.includeNotes &&
        (!hasAbsence || mode == ReportAbsenceMode.detailed);
    if (notesShown) {
      final text = _cleanNote(resolved.note);
      if (text.isNotEmpty) note = text;
    }

    // The paid minutes of one day: the same aggregate as the period, so
    // the days add up to the total.
    final worked = summarizeRange(schedule, date, date).workedMinutes;

    days.add(
      ReportDay(
        date: date,
        shifts: shifts,
        holidayName: holidays[date]?.name,
        note: note,
        workedMinutes: worked,
        overtimeMinutes: resolved.overtimeMinutes,
        overtimeBlocks: [
          for (final b in resolved.overtimeBlocks)
            if (schedule.overtimeTypeById(b.typeId) case final type?)
              ReportOvertime(
                block: notesShown || b.note == null
                    ? b
                    : b.copyWith(clearNote: true),
                type: type,
                amountCents: options.includeEarnings
                    ? overtimeAmountCents(
                        b,
                        type,
                        resolved,
                        schedule.baseHourlyRateCents,
                      )
                    : null,
              ),
        ],
        earlyLeaveMinutes: resolved.earlyLeaveMinutes,
        // The extra money of the day (P9): diets, mileage, a bonus.
        extraAmountCents: schedule.entries[date]?.extraAmountCents ?? 0,
      ),
    );
  }

  final legend = <ReportLegendEntry>[];
  for (final entry in [
    ...summary.workTypes,
    ...summary.restTypes,
    if (mode == ReportAbsenceMode.detailed) ...summary.absenceTypes,
  ]) {
    legend.add(
      ReportLegendEntry(shift: ReportShift.of(entry.type), days: entry.days),
    );
  }
  if (mode == ReportAbsenceMode.generic && summary.absenceDays > 0) {
    legend.add(
      ReportLegendEntry(
        shift: const ReportShift.genericAbsence(),
        days: summary.absenceDays,
      ),
    );
  }

  final reportHolidays = [
    for (final d in days)
      if (d.holidayName != null) ReportHoliday(d.date, d.holidayName!),
  ];

  return ReportModel(
    calendarName: calendarName.trim(),
    range: range,
    options: options,
    days: days,
    legend: legend,
    holidays: reportHolidays,
    summary: summary,
    hours: hours,
  );
}

/// A note as one tidy text: control characters (but not line breaks) removed, tabs as spaces,
/// and trimmed.
String _cleanNote(String? raw) {
  if (raw == null) return '';
  final buffer = StringBuffer();
  for (final unit in raw.runes) {
    final isControl = unit < 0x20 || (unit >= 0x7f && unit < 0xa0);
    if (unit == 0x0a) {
      buffer.writeCharCode(unit);
    } else if (unit == 0x09) {
      buffer.writeCharCode(0x20);
    } else if (!isControl) {
      buffer.writeCharCode(unit);
    }
  }
  return buffer.toString().trim();
}
