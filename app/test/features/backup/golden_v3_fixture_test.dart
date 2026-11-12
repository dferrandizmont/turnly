import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cuadrante/features/backup/domain/backup_codec.dart';
import 'package:cuadrante/features/backup/domain/backup_data.dart';
import 'package:cuadrante/features/backup/domain/restore_summary.dart';
import 'package:cuadrante/features/backup/domain/schedule_fingerprint.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/features/summary/domain/month_summary.dart';
import 'package:flutter_test/flutter_test.dart';

import 'backup_test_support.dart';
import 'golden_dataset.dart';
import 'golden_dataset_v3.dart';
import 'v3_format.dart';
import '../../support/v6_database.dart' show monthsFacts;

/// Format back-compat for version 3 (release 0.6.0): `golden_v3.cuadrante`
/// was written once by version 3 of the format and is checked in. Every
/// future build must keep reading it, with the same checksum and the same
/// 730 resolved days **in every calendar**, and restore it exactly.
///
/// To regenerate it (only when the dataset or the format is deliberately
/// versioned; never to make a failing test pass):
/// `flutter test test/features/backup/golden_v3_fixture_test.dart
///  --dart-define=REGENERATE_GOLDEN=true`
const _regenerate = bool.fromEnvironment('REGENERATE_GOLDEN');

const _dir = 'test/fixtures/golden_backup';
final _fixture = File('$_dir/golden_v3.cuadrante');
final _expected = File('$_dir/golden_v3.expected.json');

const _appVersion = '0.6.0';

void main() {
  const codec = BackupCodec();

  if (_regenerate) {
    test('regenerate the golden v3 fixture', () {
      final data = buildGoldenBackupDataV3();
      final bytes = codec.encode(
        data,
        appVersion: _appVersion,
        exportedAt: goldenV3ExportedAt,
      );
      final fingerprint = scheduleFingerprint(
        data,
        from: goldenFrom,
        to: goldenTo,
      );
      _fixture.parent.createSync(recursive: true);
      _fixture.writeAsBytesSync(bytes);
      _expected.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert({
          'schemaVersion': 3,
          'appVersion': _appVersion,
          'exportedAt': '2027-01-20T08:15:00Z',
          'checksum': BackupCodec.checksumOf(data),
          'fingerprint': {'from': goldenFrom.toIso(), 'to': goldenTo.toIso(), 'days': fingerprint.dayCount, 'calendars': fingerprint.calendarIds, 'digest': fingerprint.digest},
          'counts': {'calendars': data.calendars.length, 'shiftTypes': data.shiftTypes.length, 'patterns': data.patterns.length, 'patternRuns': data.patternRuns.length, 'dayEntries': data.dayEntries.length, 'holidays': data.holidays.length, 'absenceBalances': data.absenceBalances.length, 'settings': data.settings.length},
        })}\n',
      );
    });
    return;
  }

  late Uint8List bytes;
  late Map<String, Object?> expected;

  setUpAll(() {
    bytes = _fixture.readAsBytesSync();
    expected = jsonDecode(_expected.readAsStringSync()) as Map<String, Object?>;
  });

  group('the dataset', () {
    test('has what version 3 adds', () {
      final data = buildGoldenBackupDataV3();
      expect(data.shiftTypes.where((t) => t.icon != null), hasLength(3));
      expect(data.shiftTypes.where((t) => t.alarmSound != null), hasLength(1));
      final split = data.shiftTypes.singleWhere(
        (t) => t.segment2StartMinute != null,
      );
      expect(split.id, 'split');
      expect(split.toShiftType().segment2Problem, isNull);
      expect(
        data.dayEntries.where((e) => e.noteReminderMinute != null),
        hasLength(4),
      );
      expect(
        data.dayEntries.where((e) => e.overtimeMinutes != null),
        hasLength(3),
      );
      expect(
        data.dayEntries.where((e) => e.earlyLeaveMinutes != null),
        hasLength(3),
      );
      // Days whose only content is one of the new fields.
      expect(
        data.dayEntries.where(
          (e) =>
              e.shiftTypeIds == null &&
              e.note == null &&
              (e.noteReminderMinute != null ||
                  e.overtimeMinutes != null ||
                  e.earlyLeaveMinutes != null),
        ),
        hasLength(4),
      );
      expect(() => data.validate(), returnsNormally);
    });

    test('is the same on every call', () {
      expect(buildGoldenBackupDataV3(), buildGoldenBackupDataV3());
    });
  });

  group('golden_v3.cuadrante', () {
    test('is read by this build and matches its recorded checksum', () {
      final file = codec.decode(bytes);
      expect(file.schemaVersion, 3);
      expect(file.appVersion, expected['appVersion']);
      expect(file.exportedAt, goldenV3ExportedAt);
      expect(file.checksum, expected['checksum']);
      expect(BackupCodec.checksumOf(file.data), expected['checksum']);
    });

    test('holds the dataset the generator builds', () {
      expect(codec.decode(bytes).data, buildGoldenBackupDataV3());
    });

    test('keeps the same canonical bytes', () {
      // Rewritten in the form version 3 had: the version 4 writer turns the
      // overtime minutes into blocks, but the data read is byte for byte the
      // same.
      expect(
        Uint8List.fromList(gzip.decode(bytes)),
        v3JsonBytes(
          buildGoldenBackupDataV3(),
          appVersion: _appVersion,
          exportedAt: '2027-01-20T08:15:00Z',
        ),
      );
    });

    test('the version 4 writer gives the same data, with the overtime as '
        'blocks', () {
      final data = buildGoldenBackupDataV3();
      final written = codec.decode(
        codec.encode(
          data,
          appVersion: _appVersion,
          exportedAt: goldenV3ExportedAt,
        ),
      );
      expect(written.schemaVersion, 4);
      expect(written.data, data.upgradedOvertime());
    });

    test('resolves to the same 730 days in every calendar', () {
      final recorded = expected['fingerprint']! as Map<String, Object?>;
      final fingerprint = scheduleFingerprint(
        codec.decode(bytes).data,
        from: CivilDate.parse(recorded['from']! as String),
        to: CivilDate.parse(recorded['to']! as String),
      );
      expect(fingerprint.dayCount, 730);
      expect(fingerprint.calendarIds, recorded['calendars']);
      expect(fingerprint.digest, recorded['digest']);
    });

    test('counts are as recorded', () {
      final counts = BackupCounts.of(codec.decode(bytes).data);
      final recorded = expected['counts']! as Map<String, Object?>;
      expect(counts.calendars, recorded['calendars']);
      expect(counts.shiftTypes, recorded['shiftTypes']);
      expect(counts.patterns, recorded['patterns']);
      expect(counts.patternRuns, recorded['patternRuns']);
      expect(counts.dayEntries, recorded['dayEntries']);
      expect(counts.holidays, recorded['holidays']);
      expect(counts.absenceBalances, recorded['absenceBalances']);
      expect(counts.settings, recorded['settings']);
    });

    test('restored, every month of every calendar counts the same: money, '
        'overtime, night and holiday hours and pluses', () async {
      // The file with pluses per hour on its work shifts (database v6
      // fields, read by the version 3 reader) and holidays on days with
      // overtime after a shift.
      final json = codec.decode(bytes).data.toJson();
      for (final t in json['shiftTypes']! as List) {
        final type = t as Map<String, Object?>;
        if (type['category'] != 'work') continue;
        type['nightPlusCentsPerHour'] = 150;
        type['holidayPlusCentsPerHour'] = 275;
      }
      // The one case that does not count the same (docs/datos.md, «Cómo
      // cuentan»): «Salí antes» on a day whose only work is the overtime
      // (cal-pareja, 2026-03-12: 15 min extra, 5 min early). Before, the
      // early leave ate into the extra; now it only cuts a shift, and there
      // is none. Checked apart, then left out of the comparison.
      final apart = BackupData.fromJson(json).toSchedule('cal-pareja');
      const day = CivilDate(2026, 3, 12);
      final apartBlocks = BackupData.fromJson(json)
          .upgradedOvertime()
          .toSchedule('cal-pareja');
      expect(
        summarizeRange(apartBlocks, day, day).workedMinutes -
            summarizeRange(apart, day, day).workedMinutes,
        5,
      );
      for (final e in json['dayEntries']! as List) {
        final entry = e as Map<String, Object?>;
        if (entry['calendarId'] == 'cal-pareja' &&
            entry['date'] == '2026-03-12') {
          entry.remove('earlyLeaveMinutes');
        }
      }
      final old = BackupData.fromJson(json);
      final holidays = {
        const CivilDate(2026, 3, 14),
        const CivilDate(2026, 3, 15),
        const CivilDate(2026, 12, 25),
      };
      final db = openMemoryDatabase();
      addTearDown(db.close);
      final repository = makeRepository(db, makeTempDir('golden-v3-sums'));
      await repository.restore(old);
      final restored = await repository.readAll();
      expect(restored.overtimeBlocks, hasLength(3));
      for (final calendar in old.calendars) {
        expect(
          monthsFacts(restored.toSchedule(calendar.id), holidays: holidays),
          monthsFacts(old.toSchedule(calendar.id), holidays: holidays),
          reason: calendar.id,
        );
      }
    });

    test('restores exactly: same fingerprint, same tables', () async {
      final dir = makeTempDir('golden-v3');
      final db = openMemoryDatabase();
      addTearDown(db.close);
      final repository = makeRepository(db, dir);

      await repository.restore(codec.decode(bytes).data);

      // The overtime minutes come back as blocks (database v7), as the
      // migration of the database does; everything else is the file.
      final restored = await repository.readAll();
      final upgraded = buildGoldenBackupDataV3().upgradedOvertime();
      expect(restored, upgraded);
      expect(restored.overtimeBlocks, hasLength(3));
      expect(
        restored.dayEntries.every((e) => e.overtimeMinutes == null),
        isTrue,
      );
      expect(
        scheduleFingerprint(restored, from: goldenFrom, to: goldenTo),
        scheduleFingerprint(upgraded, from: goldenFrom, to: goldenTo),
      );
      // The hours of every day are those the file had.
      for (final calendar in restored.calendars) {
        final before = buildGoldenBackupDataV3().toSchedule(calendar.id);
        final after = restored.toSchedule(calendar.id);
        for (var d = goldenFrom; !d.isAfter(goldenTo); d = d.addDays(1)) {
          expect(
            after.resolve(d).overtimeMinutes,
            before.resolve(d).overtimeMinutes,
            reason: '${calendar.id} $d',
          );
        }
      }

      final reference = openMemoryDatabase();
      addTearDown(reference.close);
      await seedDatabase(reference, upgraded);
      expect(await dumpAllTables(db), await dumpAllTables(reference));
    });
  });
}
