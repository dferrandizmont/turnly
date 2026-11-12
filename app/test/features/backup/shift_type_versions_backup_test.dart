import 'dart:io';

import 'package:cuadrante/core/database/app_database.dart';
import 'package:cuadrante/features/backup/domain/backup_codec.dart';
import 'package:cuadrante/features/backup/domain/backup_data.dart';
import 'package:cuadrante/features/backup/domain/backup_errors.dart';
import 'package:cuadrante/features/backup/domain/restore_summary.dart';
import 'package:cuadrante/features/backup/domain/schedule_fingerprint.dart';
import 'package:cuadrante/features/schedule/data/schedule_repository.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'backup_test_support.dart';
import 'golden_dataset_v3.dart';

/// The golden v3 data with the night changed «only from today on» twice:
/// it had other hours up to 31 Mar and another rate up to 30 Jun.
Map<String, Object?> _versionsJson() => {
  'pastVersions': [
    {
      'until': '2026-03-31',
      'category': 'work',
      'startMinute': 21 * 60,
      'endMinute': 5 * 60,
      'hourlyRateCents': 1000,
      'createdAt': 1767254400000,
    },
    {
      'until': '2026-06-30',
      'category': 'work',
      'startMinute': 22 * 60,
      'endMinute': 6 * 60,
      'nightOverride': true,
      'paidMinutes': 450,
      'fixedPlusCents': 0,
      'createdAt': 1767254400001,
    },
  ],
};

BackupData _withVersions([Map<String, Object?>? versions]) {
  final json = buildGoldenBackupDataV3().toJson();
  final types = json['shiftTypes']! as List;
  final night = types.firstWhere(
    (t) => (t as Map)['id'] == 'night',
  ) as Map<String, Object?>;
  night.addAll(versions ?? _versionsJson());
  return BackupData.fromJson(json);
}

void main() {
  const codec = BackupCodec();
  late AppDatabase db;
  late Directory dir;

  setUp(() {
    db = openMemoryDatabase();
    addTearDown(db.close);
    dir = makeTempDir('type-versions-backup');
  });

  test(
    'versions survive codec, database, safety copy and verification',
    () async {
      final data = _withVersions();
      final night = data.shiftTypes.firstWhere((t) => t.id == 'night');
      expect(night.pastVersions, hasLength(2));
      final repo = makeRepository(db, dir);
      final bytes = codec.encode(
        data,
        appVersion: 'test',
        exportedAt: DateTime.utc(2026, 11, 1),
      );
      final file = codec.decode(bytes);
      expect(file.schemaVersion, 4);
      expect(file.data, data.upgradedOvertime());
      await repo.restore(file.data);
      expect(await repo.readAll(), data.upgradedOvertime());

      final loaded = (await ScheduleRepository(db).load('main')).schedule;
      expect(loaded.versionsOf('night'), night.toVersions());
      final march = loaded.shiftTypeOn('night', const CivilDate(2026, 3, 31))!;
      expect(march.startMinute, 21 * 60);
      expect(march.hourlyRateCents, 1000);
      expect(march.icon, ShiftIcon.moon, reason: 'the look is always current');
      final june = loaded.shiftTypeOn('night', const CivilDate(2026, 4, 1))!;
      expect(june.nightOverride, isTrue);
      expect(june.paidMinutes, 450);
      expect(june.fixedPlusCents, 0);
      expect(
        loaded.shiftTypeOn('night', const CivilDate(2026, 7, 1)),
        same(loaded.shiftTypeById('night')),
      );

      expect(
        await repo.verifyRestore(bytes, today: const CivilDate(2026, 11, 1)),
        isA<VerificationPassed>(),
      );

      // Restoring another file first saves these versions in the safety copy.
      await repo.restore(buildGoldenBackupDataV3());
      expect(
        (await ScheduleRepository(db).load('main')).schedule.shiftTypeVersions,
        isEmpty,
      );
      final safety = dir.listSync().whereType<File>().map(
        (f) => codec.decode(f.readAsBytesSync()).data,
      );
      expect(safety.any((d) => d == data.upgradedOvertime()), isTrue);
    },
  );

  test('a type without versions writes no key: old canonical bytes stay', () {
    final plain = buildGoldenBackupDataV3();
    expect(
      (plain.toJson()['shiftTypes']! as List).every(
        (t) => !(t as Map).containsKey('pastVersions'),
      ),
      isTrue,
    );
    final old = codec.decode(
      File('test/fixtures/golden_backup/golden_v3.cuadrante').readAsBytesSync(),
    );
    expect(old.data.shiftTypes.every((t) => t.pastVersions.isEmpty), isTrue);
    expect(BackupCodec.checksumOf(old.data), old.checksum);
    // Only the set keys of a version are written.
    final json = _withVersions().toJson();
    final night = (json['shiftTypes']! as List).firstWhere(
      (t) => (t as Map)['id'] == 'night',
    ) as Map;
    final first = (night['pastVersions'] as List).first as Map;
    expect(first.keys, {
      'until',
      'category',
      'startMinute',
      'endMinute',
      'hourlyRateCents',
      'createdAt',
    });
  });

  test('versions belong to equality and the fingerprint', () {
    final plain = buildGoldenBackupDataV3();
    final versioned = _withVersions();
    expect(versioned, isNot(plain));
    const from = CivilDate(2026, 1, 1);
    const to = CivilDate(2026, 12, 31);
    expect(
      scheduleFingerprint(versioned, from: from, to: to),
      isNot(scheduleFingerprint(plain, from: from, to: to)),
    );
    expect(
      versioned.toSchedule().versionsOf('night'),
      versioned.shiftTypes.firstWhere((t) => t.id == 'night').toVersions(),
    );
    // Sanitizing a sound keeps the versions.
    expect(
      versioned
          .sanitized()
          .shiftTypes
          .firstWhere((t) => t.id == 'night')
          .pastVersions,
      hasLength(2),
    );
  });

  test('invalid versions are refused before restoring', () async {
    for (final bad in <Map<String, Object?>>[
      {
        'pastVersions': [
          {
            'until': '2026-03-31',
            'category': 'work',
            'startMinute': 60,
            'createdAt': 1,
          },
        ],
      },
      {
        'pastVersions': [
          {'until': '2026-03-31', 'category': 'work', 'createdAt': 1},
          {'until': '2026-03-31', 'category': 'rest', 'createdAt': 2},
        ],
      },
      {
        'pastVersions': [
          {
            'until': '2026-03-31',
            'category': 'work',
            'hourlyRateCents': maxHourlyRateCents + 1,
            'createdAt': 1,
          },
        ],
      },
    ]) {
      expect(
        () => _withVersions(bad).validate(),
        throwsA(isA<CorruptBackup>()),
        reason: '$bad',
      );
    }
    for (final malformed in <Map<String, Object?>>[
      {'pastVersions': 'nope'},
      {
        'pastVersions': [
          {'until': 'yesterday', 'category': 'work', 'createdAt': 1},
        ],
      },
      {
        'pastVersions': [
          {'until': '2026-03-31', 'category': 'holiday', 'createdAt': 1},
        ],
      },
    ]) {
      expect(
        () => _withVersions(malformed),
        throwsA(isA<FormatException>()),
        reason: '$malformed',
      );
    }
  });
}
