import 'dart:io';

import 'package:cuadrante/features/absences/data/absence_carry_over_store.dart';
import 'package:cuadrante/features/absences/domain/absence_balance.dart';
import 'package:cuadrante/features/schedule/domain/civil_date.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../backup/backup_test_support.dart';
import '../../support/test_storage.dart' show TestStorage;

/// The expiry dates of the carried days travel in the backup of safety and
/// come back when it is restored (they live in the `settings` table, which
/// the copy exports and restores whole).
void main() {
  late Directory dir;
  late Directory safety;

  setUp(() {
    dir = makeTempDir('absence-backup');
    safety = Directory(p.join(dir.path, 'backups'));
  });

  test('the expiry dates travel in the copy and come back', () async {
    final storage = await TestStorage.open(now: DateTime(2026, 10, 19, 12));
    addTearDown(storage.close);
    await AbsenceCarryOverStore(storage.database)
        .setExpiry(2027, 'vac', const CivilDate(2027, 3, 31));

    final data = await makeRepository(storage.database, safety).readAll();
    expect(
      data.settings[AbsenceCarryOverStore.settingsKey],
      contains('2027-03-31'),
    );

    final restored = openMemoryDatabase();
    addTearDown(restored.close);
    await makeRepository(restored, safety).restore(data);

    expect(await AbsenceCarryOverStore(restored).load(), {
      absenceCarryOverExpiryKey(2027, 'vac'): const CivilDate(2027, 3, 31),
    });
  });
}
