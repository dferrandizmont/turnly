import 'package:collection/collection.dart';

import 'civil_date.dart';
import 'overtime.dart';
import 'shift_type.dart' show maxStoredMoneyCents;

const _listEq = ListEquality<String>();
const _stepsEq = ListEquality<List<String>>(ListEquality<String>());

/// Repeating cycle: one step per day, each with 0..n shift type ids (an empty
/// step is a day without shift).
class Pattern {
  const Pattern({required this.id, required this.name, required this.steps});

  final String id;
  final String name;

  /// Must not be empty.
  final List<List<String>> steps;

  int get lengthDays => steps.length;

  @override
  bool operator ==(Object other) =>
      other is Pattern &&
      other.id == id &&
      other.name == name &&
      _stepsEq.equals(other.steps, steps);

  @override
  int get hashCode => Object.hash(id, name, _stepsEq.hash(steps));

  @override
  String toString() => 'Pattern($id, $lengthDays days)';
}

/// A [Pattern] applied from [startDate] to [endDate] (inclusive, `null` = open).
class PatternRun {
  const PatternRun({
    required this.id,
    required this.patternId,
    required this.startDate,
    required this.seq,
    this.endDate,
    this.stepOffset = 0,
  });

  final String id;
  final String patternId;
  final CivilDate startDate;
  final CivilDate? endDate;

  /// Cycle step that falls on [startDate].
  final int stepOffset;

  /// Creation order; when runs overlap the highest wins (on equal [seq] the
  /// one listed last wins).
  final int seq;

  bool covers(CivilDate d) =>
      !d.isBefore(startDate) && (endDate == null || !d.isAfter(endDate!));

  /// Cycle step on [d] (always in `0..lengthDays-1`); only meaningful when
  /// [covers] is true.
  int stepIndexOn(CivilDate d, int lengthDays) =>
      (stepOffset + d.differenceInDays(startDate)) % lengthDays;

  PatternRun copyWith({
    String? id,
    String? patternId,
    CivilDate? startDate,
    CivilDate? endDate,
    int? stepOffset,
    int? seq,
    bool clearEndDate = false,
  }) => PatternRun(
    id: id ?? this.id,
    patternId: patternId ?? this.patternId,
    startDate: startDate ?? this.startDate,
    endDate: clearEndDate ? null : endDate ?? this.endDate,
    stepOffset: stepOffset ?? this.stepOffset,
    seq: seq ?? this.seq,
  );

  @override
  bool operator ==(Object other) =>
      other is PatternRun &&
      other.id == id &&
      other.patternId == patternId &&
      other.startDate == startDate &&
      other.endDate == endDate &&
      other.stepOffset == stepOffset &&
      other.seq == seq;

  @override
  int get hashCode =>
      Object.hash(id, patternId, startDate, endDate, stepOffset, seq);

  @override
  String toString() => 'PatternRun($id, $patternId, $startDate..$endDate)';
}

/// Manual exception for one day.
///
/// Besides the optional shift override it holds what the user attached to the
/// day: a [note] with an optional reminder, and the extra or missing minutes
/// of the day's work. All of it is stored **only on days the user touched**
/// (rules and exceptions, never a row per day).
class DayEntry {
  const DayEntry({
    required this.date,
    this.shiftTypeIds,
    this.note,
    this.noteReminderMinute,
    this.overtimeMinutes,
    this.overtimeBlocks = const [],
    this.earlyLeaveMinutes,
    this.extraAmountCents,
  }) : assert(
         noteReminderMinute == null ||
             (noteReminderMinute >= 0 && noteReminderMinute < 1440),
         'The reminder is a minute of the day (0-1439)',
       ),
       assert(overtimeMinutes == null || overtimeMinutes >= 0),
       assert(earlyLeaveMinutes == null || earlyLeaveMinutes >= 0),
       assert(
         extraAmountCents == null ||
             (extraAmountCents >= -maxStoredMoneyCents &&
                 extraAmountCents <= maxStoredMoneyCents),
       );

  final CivilDate date;

  /// `null` = does not replace the pattern (e.g. note only); `[]` = empty day
  /// even if the pattern says otherwise; `[a, b]` = replaces it, in that order.
  final List<String>? shiftTypeIds;
  final String? note;

  /// Minute of this civil day (0-1439) at which the note rings as a reminder
  /// (docs/paridad.md, A1). `null` = no reminder.
  final int? noteReminderMinute;

  /// Extra minutes worked this day (>= 0, A6). `null` = none.
  ///
  /// The old form of the extra hours: since schema v7 they are
  /// [overtimeBlocks] and nothing in the app writes this any more. Only data
  /// from before (a backup of format 3, an unmigrated row) can still carry
  /// it, and it counts as it always did until it is converted
  /// (`legacyOvertimeBlock`).
  final int? overtimeMinutes;

  /// The extra hours of the day (schema v7): blocks that start on [date],
  /// in order of start. Empty = none.
  final List<OvertimeBlock> overtimeBlocks;

  /// Minutes the user left before the end of the shift (>= 0, A6). `null` =
  /// none.
  final int? earlyLeaveMinutes;

  /// Extra money of this day (allowances, a bonus; negative for a
  /// deduction), in the minor unit of the currency. `null` = none; 0 is the
  /// same as none. Schema v6 (the summary adds it from P9).
  final int? extraAmountCents;

  /// Whether [minute] is a valid [noteReminderMinute].
  static bool isReminderMinute(int minute) => minute >= 0 && minute < 1440;

  /// Nothing worth storing: no override, no note, no reminder, no extra or
  /// missing minutes and no extra amount (0 is the same as none). An entry
  /// whose only content is a reminder, overtime, early leave or an extra
  /// amount is **not** empty.
  bool get isEmpty =>
      shiftTypeIds == null &&
      (note == null || note!.isEmpty) &&
      noteReminderMinute == null &&
      (overtimeMinutes ?? 0) == 0 &&
      overtimeBlocks.isEmpty &&
      (earlyLeaveMinutes ?? 0) == 0 &&
      (extraAmountCents ?? 0) == 0;

  DayEntry copyWith({
    List<String>? shiftTypeIds,
    String? note,
    int? noteReminderMinute,
    int? overtimeMinutes,
    List<OvertimeBlock>? overtimeBlocks,
    int? earlyLeaveMinutes,
    int? extraAmountCents,
    bool clearShiftTypeIds = false,
    bool clearNote = false,
    bool clearNoteReminder = false,
    bool clearOvertime = false,
    bool clearEarlyLeave = false,
    bool clearExtraAmount = false,
  }) => DayEntry(
    date: date,
    overtimeBlocks: overtimeBlocks ?? this.overtimeBlocks,
    shiftTypeIds: clearShiftTypeIds ? null : shiftTypeIds ?? this.shiftTypeIds,
    note: clearNote ? null : note ?? this.note,
    noteReminderMinute: clearNoteReminder
        ? null
        : noteReminderMinute ?? this.noteReminderMinute,
    overtimeMinutes: clearOvertime
        ? null
        : overtimeMinutes ?? this.overtimeMinutes,
    earlyLeaveMinutes: clearEarlyLeave
        ? null
        : earlyLeaveMinutes ?? this.earlyLeaveMinutes,
    extraAmountCents: clearExtraAmount
        ? null
        : extraAmountCents ?? this.extraAmountCents,
  );

  /// The same entry with its shift override replaced by [ids] (`null` = no
  /// override). Everything else the day holds stays.
  DayEntry withShiftTypeIds(List<String>? ids) => DayEntry(
    date: date,
    shiftTypeIds: ids,
    overtimeBlocks: overtimeBlocks,
    note: note,
    noteReminderMinute: noteReminderMinute,
    overtimeMinutes: overtimeMinutes,
    earlyLeaveMinutes: earlyLeaveMinutes,
    extraAmountCents: extraAmountCents,
  );

  @override
  bool operator ==(Object other) =>
      other is DayEntry &&
      other.date == date &&
      other.note == note &&
      other.noteReminderMinute == noteReminderMinute &&
      other.overtimeMinutes == overtimeMinutes &&
      const ListEquality<OvertimeBlock>().equals(
        other.overtimeBlocks,
        overtimeBlocks,
      ) &&
      other.earlyLeaveMinutes == earlyLeaveMinutes &&
      other.extraAmountCents == extraAmountCents &&
      (shiftTypeIds == null
          ? other.shiftTypeIds == null
          : other.shiftTypeIds != null &&
                _listEq.equals(other.shiftTypeIds, shiftTypeIds));

  @override
  int get hashCode => Object.hash(
    date,
    note,
    noteReminderMinute,
    overtimeMinutes,
    const ListEquality<OvertimeBlock>().hash(overtimeBlocks),
    earlyLeaveMinutes,
    extraAmountCents,
    shiftTypeIds == null ? null : _listEq.hash(shiftTypeIds),
  );

  @override
  String toString() =>
      'DayEntry($date, $shiftTypeIds, $note'
      '${noteReminderMinute == null ? '' : ', reminder $noteReminderMinute'}'
      '${overtimeMinutes == null ? '' : ', overtime $overtimeMinutes'}'
      '${overtimeBlocks.isEmpty ? '' : ', blocks $overtimeBlocks'}'
      '${earlyLeaveMinutes == null ? '' : ', early $earlyLeaveMinutes'}'
      '${extraAmountCents == null ? '' : ', extra $extraAmountCents'})';
}
