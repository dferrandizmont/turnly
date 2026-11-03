import 'package:cuadrante/core/database/app_database.dart';
import 'package:cuadrante/features/absences/data/absence_carry_over_store.dart';
import 'package:cuadrante/features/absences/domain/absence_balance.dart';
import 'package:cuadrante/features/schedule/domain/civil_date.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_storage.dart';

void main() {
  group('AbsenceCarryOverStore', () {
    late AppDatabase db;
    late AbsenceCarryOverStore store;

    setUp(() {
      db = openMemoryDatabase();
      addTearDown(db.close);
      store = AbsenceCarryOverStore(db);
    });

    test('without a row there is no expiry', () async {
      expect(await store.load(), isEmpty);
    });

    test('an expiry is written and read back', () async {
      await store.setExpiry(2027, 'vac', const CivilDate(2027, 3, 31));
      expect(await store.load(), {
        absenceCarryOverExpiryKey(2027, 'vac'): const CivilDate(2027, 3, 31),
      });
    });

    test('several series and years live together', () async {
      await store.setExpiry(2027, 'vac', const CivilDate(2027, 3, 31));
      await store.setExpiry(2027, 'moscosos', const CivilDate(2027, 6, 30));
      await store.setExpiry(2028, 'vac', const CivilDate(2028, 3, 31));
      expect(await store.load(), {
        '2027:vac': const CivilDate(2027, 3, 31),
        '2027:moscosos': const CivilDate(2027, 6, 30),
        '2028:vac': const CivilDate(2028, 3, 31),
      });
    });

    test('the same series is kept apart by calendar (L1)', () async {
      await store.setExpiry(
        2027,
        'vac',
        const CivilDate(2027, 3, 31),
        calendarId: 'main',
      );
      await store.setExpiry(
        2027,
        'vac',
        const CivilDate(2027, 4, 30),
        calendarId: 'other',
      );
      expect(await store.load(), {
        'main|2027:vac': const CivilDate(2027, 3, 31),
        'other|2027:vac': const CivilDate(2027, 4, 30),
      });
    });

    test('clearing with a calendar also clears the old key (L1)', () async {
      await store.setExpiry(2027, 'vac', const CivilDate(2027, 3, 31));
      await store.setExpiry(2027, 'vac', null, calendarId: 'main');
      expect(await store.load(), isEmpty);
    });

    test('an expiry is cleared', () async {
      await store.setExpiry(2027, 'vac', const CivilDate(2027, 3, 31));
      await store.setExpiry(2027, 'vac', null);
      expect(await store.load(), isEmpty);
      final rows = await db.select(db.settings).get();
      expect(rows, isEmpty, reason: 'the row goes when nothing is left');
    });

    test('clearing one expiry keeps the others', () async {
      await store.setExpiry(2027, 'vac', const CivilDate(2027, 3, 31));
      await store.setExpiry(2027, 'moscosos', const CivilDate(2027, 6, 30));
      await store.setExpiry(2027, 'vac', null);
      expect(await store.load(), {
        '2027:moscosos': const CivilDate(2027, 6, 30),
      });
    });

    test('a value that is not a date is ignored', () async {
      await db
          .into(db.settings)
          .insert(
            SettingsCompanion.insert(
              key: AbsenceCarryOverStore.settingsKey,
              value: '{"2027:vac": "not a date", "2027:other": "2027-03-31"}',
            ),
          );
      expect(await store.load(), {'2027:other': const CivilDate(2027, 3, 31)});
    });

    test('a row that is not JSON is ignored', () async {
      await db
          .into(db.settings)
          .insert(
            SettingsCompanion.insert(
              key: AbsenceCarryOverStore.settingsKey,
              value: 'not json at all',
            ),
          );
      expect(await store.load(), isEmpty);
    });
  });
}
