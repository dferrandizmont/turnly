import 'dart:io';

import 'package:cuadrante/core/database/app_database.dart';
import 'package:cuadrante/features/absences/data/absence_working_days_store.dart';
import 'package:cuadrante/features/absences/domain/absence_balance.dart';
import 'package:cuadrante/features/summary/data/pay_rules_store.dart';
import 'package:cuadrante/features/summary/domain/overtime_cap.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../backup/backup_test_support.dart';
import '../../support/test_storage.dart' show TestStorage;

/// The closing day, the cap of the overtime and the balances counted in
/// working days live in the `settings` table: they are read back, a bad value
/// is «none», and they travel in the backup and come back with a restore.
void main() {
  group('PayRulesStore', () {
    late AppDatabase db;
    late PayRulesStore store;

    setUp(() {
      db = openMemoryDatabase();
      store = PayRulesStore(db);
    });
    tearDown(() => db.close());

    Future<void> write(String key, String json) => db
        .into(db.settings)
        .insertOnConflictUpdate(
          SettingsCompanion(key: Value(key), value: Value(json)),
        );

    test('nothing stored: the calendar month and no cap', () async {
      expect(await store.load(), PayRules.none);
    });

    test('saves, reads and clears both rules', () async {
      await store.setClosingDay(20);
      await store.setOvertimeCap(const OvertimeCap(OvertimeCapPeriod.year, 80));
      expect(
        await store.load(),
        const PayRules(
          closingDay: 20,
          overtimeCap: OvertimeCap(OvertimeCapPeriod.year, 80),
        ),
      );
      await store.setClosingDay(null);
      await store.setOvertimeCap(null);
      expect(await store.load(), PayRules.none);
      expect(await db.select(db.settings).get(), isEmpty);
    });

    test('refuses a value out of range', () async {
      expect(() => store.setClosingDay(31), throwsArgumentError);
      expect(() => store.setClosingDay(0), throwsArgumentError);
      expect(
        () => store.setOvertimeCap(const OvertimeCap(OvertimeCapPeriod.month, 0)),
        throwsArgumentError,
      );
    });

    test('a hand-edited bad value is none', () async {
      await write(PayRulesStore.closingDayKey, '45');
      await write(PayRulesStore.overtimeCapKey, '{"period":"week"}');
      expect(await store.load(), PayRules.none);
      await write(PayRulesStore.closingDayKey, 'not json');
      expect((await store.load()).closingDay, isNull);
    });
  });

  group('AbsenceWorkingDaysStore', () {
    late AppDatabase db;
    late AbsenceWorkingDaysStore store;

    setUp(() {
      db = openMemoryDatabase();
      store = AbsenceWorkingDaysStore(db);
    });
    tearDown(() => db.close());

    test('marks and unmarks a balance', () async {
      expect(await store.load(), isEmpty);
      await store.set(2027, 'vac', 'main', workingDaysOnly: true);
      await store.set(2027, 'free', 'main', workingDaysOnly: true);
      expect(await store.load(), {
        absenceCarryOverExpiryKey(2027, 'vac', 'main'),
        absenceCarryOverExpiryKey(2027, 'free', 'main'),
      });
      await store.set(2027, 'vac', 'main', workingDaysOnly: false);
      await store.set(2027, 'free', 'main', workingDaysOnly: false);
      expect(await store.load(), isEmpty);
      expect(await db.select(db.settings).get(), isEmpty);
    });
  });

  group('the backup', () {
    late Directory dir;
    late Directory safety;

    setUp(() {
      dir = makeTempDir('pay-rules-backup');
      safety = Directory(p.join(dir.path, 'backups'));
    });

    test('carries the payroll rules and the working-day balances', () async {
      final storage = await TestStorage.open(now: DateTime(2026, 11, 6, 12));
      addTearDown(storage.close);
      final rules = PayRulesStore(storage.database);
      await rules.setClosingDay(20);
      await rules.setOvertimeCap(const OvertimeCap(OvertimeCapPeriod.month, 15));
      await AbsenceWorkingDaysStore(
        storage.database,
      ).set(2026, 'vac', 'main', workingDaysOnly: true);

      final data = await makeRepository(storage.database, safety).readAll();
      expect(data.settings[PayRulesStore.closingDayKey], '20');
      expect(data.settings, contains(PayRulesStore.overtimeCapKey));
      expect(data.settings, contains(AbsenceWorkingDaysStore.settingsKey));

      final restored = openMemoryDatabase();
      addTearDown(restored.close);
      await makeRepository(restored, safety).restore(data);

      expect(
        await PayRulesStore(restored).load(),
        const PayRules(
          closingDay: 20,
          overtimeCap: OvertimeCap(OvertimeCapPeriod.month, 15),
        ),
      );
      expect(await AbsenceWorkingDaysStore(restored).load(), {
        absenceCarryOverExpiryKey(2026, 'vac', 'main'),
      });
    });
  });
}
