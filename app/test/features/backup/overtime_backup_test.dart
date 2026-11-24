import 'dart:convert';
import 'dart:io';

import 'package:cuadrante/core/database/app_database.dart';
import 'package:cuadrante/features/backup/data/backup_repository.dart';
import 'package:cuadrante/features/backup/domain/backup_codec.dart';
import 'package:cuadrante/features/backup/domain/backup_data.dart';
import 'package:cuadrante/features/backup/domain/backup_errors.dart';
import 'package:cuadrante/features/backup/domain/restore_summary.dart';
import 'package:cuadrante/features/schedule/data/overtime_store.dart';
import 'package:cuadrante/features/schedule/data/schedule_repository.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'backup_test_support.dart';
import 'golden_dataset_v3.dart';
import 'v3_format.dart';

/// The extra hours in the backup (format version 4, database v7): types,
/// blocks and the base rate travel and come back exactly; a version 3 copy
/// with the old overtime minutes is converted like the database migration.
BackupData _with(
  BackupData d, {
  List<BackupOvertimeType>? types,
  List<BackupOvertimeBlock>? blocks,
  Map<String, String>? settings,
}) => BackupData(
  calendars: d.calendars,
  shiftTypes: d.shiftTypes,
  patterns: d.patterns,
  patternRuns: d.patternRuns,
  dayEntries: d.dayEntries,
  holidays: d.holidays,
  absenceBalances: d.absenceBalances,
  settings: settings ?? d.settings,
  noteAttachments: d.noteAttachments,
  dayTasks: d.dayTasks,
  shiftSwaps: d.shiftSwaps,
  overtimeTypes: types ?? d.overtimeTypes,
  overtimeBlocks: blocks ?? d.overtimeBlocks,
);

/// The golden v3 data as a v7 user would have it: its overtime converted,
/// the built-in «Horas extra» renamed, a type of their own with a fixed rate
/// and blocks of it (past midnight, with a break and a note) in two
/// calendars, and a base rate.
BackupData _v7Data() {
  final base = buildGoldenBackupDataV3().upgradedOvertime();
  return _with(
    base,
    types: [
      for (final t in base.overtimeTypes)
        t.id == overtimeTypeId
            ? BackupOvertimeType.of(t.toType().copyWith(name: 'Extras'))
            : t,
      BackupOvertimeType.of(
        const OvertimeType(
          id: 'ot-guard',
          name: 'Guardia localizada',
          colorValue: 0xFFE5484D,
          rateMode: OvertimeRateMode.fixed,
          hourlyRateCents: 1250,
          countsForGoal: false,
          archived: true,
          sortOrder: 2,
        ),
      ),
    ],
    blocks: [
      ...base.overtimeBlocks,
      BackupOvertimeBlock(
        calendarId: base.calendars.first.id,
        date: const CivilDate(2026, 4, 2),
        id: 'g-1',
        typeId: 'ot-guard',
        startMinute: 22 * 60,
        endMinute: 3 * 60,
        breakMinutes: 30,
        note: 'Aviso de las 23:40',
      ),
      BackupOvertimeBlock(
        calendarId: 'cal-pareja',
        date: const CivilDate(2026, 4, 2),
        id: 'g-2',
        typeId: 'ot-guard',
        startMinute: 8 * 60,
        endMinute: 9 * 60,
      ),
    ],
    settings: {...base.settings, baseHourlyRateKey: jsonEncode(1475)},
  );
}

void main() {
  const codec = BackupCodec();
  late AppDatabase db;
  late BackupRepository repository;

  setUp(() {
    db = openMemoryDatabase();
    final dir = makeTempDir('overtime-backup');
    repository = makeRepository(db, Directory(p.join(dir.path, 'safety')));
  });
  tearDown(() => db.close());

  group('format version 4', () {
    test('types, blocks and the base rate go and come back exactly', () async {
      final data = _v7Data();
      expect(() => data.validate(), returnsNormally);
      final bytes = codec.encode(
        data,
        appVersion: testAppVersion,
        exportedAt: DateTime.utc(2026, 11, 12, 10),
      );
      final file = codec.decode(bytes);
      expect(file.schemaVersion, 4);
      expect(file.data, data);
      final json = readEnvelope(bytes)['data']! as Map<String, Object?>;
      expect(json['overtimeTypes'], hasLength(3));
      expect(json['overtimeBlocks'], hasLength(5));
      for (final e in json['dayEntries']! as List) {
        expect((e as Map).containsKey('overtimeMinutes'), isFalse);
      }

      await repository.restore(file.data);
      expect(await repository.readAll(), data);
      final schedule = (await ScheduleRepository(db).load('cal-pareja'))
          .schedule;
      expect(schedule.baseHourlyRateCents, 1475);
      expect(
        schedule.resolve(const CivilDate(2026, 4, 2)).overtimeBlocks.single.id,
        'g-2',
      );
      expect(schedule.overtimeTypeById(overtimeTypeId)?.name, 'Extras');
      expect(schedule.overtimeTypeById('ot-guard')?.archived, isTrue);
    });

    test('«Probar restauración» passes and matches the live data', () async {
      await repository.restore(_v7Data());
      final bytes = codec.encode(
        await repository.readAll(),
        appVersion: testAppVersion,
        exportedAt: DateTime.utc(2026, 11, 12, 10),
      );
      final result = await repository.verifyRestore(
        bytes,
        today: const CivilDate(2026, 4, 1),
      );
      expect(result, isA<VerificationPassed>());
      expect((result as VerificationPassed).matchesLive, isTrue);
    });

    test('data that never used the extra hours stays as it was', () async {
      final data = buildGoldenBackupDataV3();
      final plain = BackupData(
        calendars: data.calendars,
        shiftTypes: data.shiftTypes,
        patterns: data.patterns,
        patternRuns: data.patternRuns,
        holidays: data.holidays,
      );
      expect(plain.upgradedOvertime(), same(plain));
      final json = plain.toJson();
      expect(json.containsKey('overtimeTypes'), isFalse);
      expect(json.containsKey('overtimeBlocks'), isFalse);
      await repository.restore(plain);
      // The database has the two built-in types; the copy does not carry
      // them.
      expect(await OvertimeStore(db).types(), defaultOvertimeTypes);
      expect(await repository.readAll(), plain);
    });

    test('a block of a missing type, a bad block or a repeated type is a '
        'corrupt file', () {
      final data = _v7Data();
      final block = data.overtimeBlocks.last;
      BackupOvertimeBlock changed({String? typeId, int? breakMinutes}) =>
          BackupOvertimeBlock(
            calendarId: block.calendarId,
            date: block.date,
            id: block.id,
            typeId: typeId ?? block.typeId,
            startMinute: block.startMinute,
            endMinute: block.endMinute,
            breakMinutes: breakMinutes ?? block.breakMinutes,
          );
      for (final bad in [
        _with(
          data,
          blocks: [
            ...data.overtimeBlocks,
            changed(typeId: 'x'),
          ],
        ),
        _with(
          data,
          blocks: [
            for (final b in data.overtimeBlocks)
              b == block ? changed(breakMinutes: 60) : b,
          ],
        ),
        _with(data, types: [...data.overtimeTypes, data.overtimeTypes.first]),
        _with(
          data,
          blocks: [
            ...data.overtimeBlocks,
            BackupOvertimeBlock(
              calendarId: 'nope',
              date: block.date,
              id: 'z',
              typeId: block.typeId,
              startMinute: 0,
              endMinute: 60,
            ),
          ],
        ),
      ]) {
        expect(() => bad.validate(), throwsA(isA<CorruptBackup>()));
      }
    });

    test('rejects a version newer than this reader supports', () {
      final bytes = codec.encode(
        _v7Data(),
        appVersion: testAppVersion,
        exportedAt: DateTime.utc(2026, 11, 12, 10),
      );
      expect(readEnvelope(bytes)['schemaVersion'], 4);
      // The same rule, one version up: this build refuses a version 5.
      final envelope = readEnvelope(bytes)..['schemaVersion'] = 6;
      expect(
        () => codec.decode(gzipEnvelope(envelope)),
        throwsA(isA<NewerFormatVersion>()),
      );
    });
  });

  group('a version 3 copy with the old overtime minutes', () {
    test('restores with them as blocks, like the database migration', () async {
      final old = buildGoldenBackupDataV3();
      final file = codec.decode(v3File(old));
      expect(file.schemaVersion, 3);
      expect(file.data, old);
      expect(file.data.overtimeBlocks, isEmpty);

      await repository.restore(file.data);
      final restored = await repository.readAll();
      expect(restored, old.upgradedOvertime());
      expect(
        restored.dayEntries.every((e) => e.overtimeMinutes == null),
        isTrue,
      );
      expect(
        restored.overtimeTypes.map((t) => t.toType()),
        unorderedEquals(defaultOvertimeTypes),
      );

      final blocks = {
        for (final b in restored.overtimeBlocks)
          '${b.calendarId}|${b.date.toIso()}': b,
      };
      expect(blocks.keys, {
        'main|2026-03-12',
        'main|2026-03-14',
        'cal-pareja|2026-03-12',
      });
      for (final b in blocks.values) {
        expect(b.typeId, overtimeTypeId);
        expect(b.id, legacyOvertimeBlockId(b.date));
        expect(b.breakMinutes, 0);
        final day = old.toSchedule(b.calendarId).resolve(b.date);
        expect(
          b.startMinute,
          (lastWorkEndMinute(day) ?? legacyFreeDayOvertimeStart) % 1440,
        );
        expect(b.toBlock().paidMinutes, day.overtimeMinutes);
      }

      // Every day of every calendar keeps its extra minutes.
      for (final calendar in old.calendars) {
        final before = old.toSchedule(calendar.id);
        final after = restored.toSchedule(calendar.id);
        for (
          var d = const CivilDate(2026, 1, 1);
          !d.isAfter(const CivilDate(2027, 12, 31));
          d = d.addDays(1)
        ) {
          expect(
            after.resolve(d).overtimeMinutes,
            before.resolve(d).overtimeMinutes,
          );
        }
      }
    });

    test('«Probar restauración» passes on it', () async {
      final result = await repository.verifyRestore(
        v3File(buildGoldenBackupDataV3()),
        today: const CivilDate(2026, 4, 1),
      );
      expect(result, isA<VerificationPassed>());
    });

    test('writing it again gives version 4 with the blocks', () {
      final old = buildGoldenBackupDataV3();
      final again = codec.decode(
        codec.encode(
          old,
          appVersion: testAppVersion,
          exportedAt: DateTime.utc(2026, 11, 12, 10),
        ),
      );
      expect(again.schemaVersion, 4);
      expect(again.data, old.upgradedOvertime());
      expect(again.data.overtimeBlocks, hasLength(3));
    });

    test('old minutes in a version 4 file (no writer does it) are converted '
        'too, never refused', () async {
      final old = buildGoldenBackupDataV3();
      final json = old.toJson()
        ..['overtimeTypes'] = [
          for (final t in defaultOvertimeTypes)
            BackupOvertimeType.of(t).toJson(),
        ]
        ..['overtimeBlocks'] = <Object?>[];
      final bytes = gzipEnvelope({
        'format': BackupCodec.formatName,
        'schemaVersion': 4,
        'appVersion': testAppVersion,
        'exportedAt': '2026-11-12T10:00:00Z',
        'data': json,
        'checksum': BackupCodec.checksumOfJson(json),
      });
      final file = codec.decode(bytes);
      await repository.restore(file.data);
      expect(
        (await repository.readAll()).overtimeBlocks,
        old.upgradedOvertime().overtimeBlocks,
      );
    });

    test('the restore summary counts the same days', () {
      final old = buildGoldenBackupDataV3();
      expect(
        BackupCounts.of(old.upgradedOvertime()).dayEntries,
        BackupCounts.of(old).dayEntries,
      );
    });
  });
}
