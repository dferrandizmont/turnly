import 'dart:convert';

import 'package:cuadrante/features/backup/domain/backup_data.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';

import 'golden_dataset_v3.dart';

/// Exported by the build that wrote `golden_v4.cuadrante`.
final goldenV4ExportedAt = DateTime.utc(2027, 2, 10, 9, 45);

/// The reference dataset of format version 4 (`golden_v4.cuadrante`,
/// database v7): the version 3 data with its overtime as blocks, plus
/// - the built-in «Horas extra» renamed and recoloured (so the types travel),
/// - a type of the user's with a fixed rate that does not count for the goal,
///   archived, and another one with a multiplier of ×1,75,
/// - blocks past midnight, with a break and a note, two on the same day and
///   one in the second calendar,
/// - a base hourly rate.
///
/// Fixed like the other ones: no clock, no randomness.
BackupData buildGoldenBackupDataV4() {
  final base = buildGoldenBackupDataV3().upgradedOvertime();
  const night = OvertimeType(
    id: 'ot-guard',
    name: 'Guardia localizada',
    colorValue: 0xFFE5484D,
    rateMode: OvertimeRateMode.fixed,
    hourlyRateCents: 1250,
    countsForGoal: false,
    archived: true,
    sortOrder: 2,
  );
  const holiday = OvertimeType(
    id: 'ot-festivo',
    name: 'Festivo trabajado',
    colorValue: 0xFF30A46C,
    rateMode: OvertimeRateMode.multiplier,
    multiplierBasisPoints: 17500,
    sortOrder: 3,
  );
  return BackupData(
    calendars: base.calendars,
    shiftTypes: base.shiftTypes,
    patterns: base.patterns,
    patternRuns: base.patternRuns,
    dayEntries: base.dayEntries,
    holidays: base.holidays,
    absenceBalances: base.absenceBalances,
    settings: {...base.settings, baseHourlyRateKey: jsonEncode(1475)},
    noteAttachments: base.noteAttachments,
    dayTasks: base.dayTasks,
    shiftSwaps: base.shiftSwaps,
    overtimeTypes: [
      for (final t in base.overtimeTypes)
        t.id == overtimeTypeId
            ? BackupOvertimeType.of(
                t.toType().copyWith(name: 'Extras', colorValue: 0xFF8E7CC3),
              )
            : t,
      BackupOvertimeType.of(night),
      BackupOvertimeType.of(holiday),
    ],
    overtimeBlocks: [
      ...base.overtimeBlocks,
      const BackupOvertimeBlock(
        calendarId: 'main',
        date: CivilDate(2026, 4, 2),
        id: 'g-1',
        typeId: 'ot-guard',
        startMinute: 22 * 60,
        endMinute: 3 * 60,
        breakMinutes: 30,
        note: 'Aviso de las 23:40',
      ),
      const BackupOvertimeBlock(
        calendarId: 'main',
        date: CivilDate(2026, 4, 2),
        id: 'f-1',
        typeId: 'ot-festivo',
        startMinute: 8 * 60,
        endMinute: 12 * 60,
      ),
      const BackupOvertimeBlock(
        calendarId: 'cal-pareja',
        date: CivilDate(2026, 4, 2),
        id: 'o-1',
        typeId: otherWorkTypeId,
        startMinute: 17 * 60,
        endMinute: 19 * 60 + 30,
        note: 'Clases',
      ),
    ],
  );
}
