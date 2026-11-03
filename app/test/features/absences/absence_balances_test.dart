import 'package:cuadrante/core/database/app_database.dart';
import 'package:cuadrante/core/database/converters.dart';
import 'package:cuadrante/features/absences/data/absence_balances_repository.dart';
import 'package:cuadrante/features/absences/domain/absence_balance.dart';
import 'package:cuadrante/features/schedule/domain/civil_date.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_storage.dart';

void main() {
  group('domain', () {
    test('units and quarter steps', () {
      expect(AbsenceUnit.day.days, 1);
      expect(AbsenceUnit.half.days, 0.5);
      expect(AbsenceUnit.quarter.days, 0.25);
      for (final ok in [0.0, 0.25, 1.5, 22.75, -3.25]) {
        expect(isQuarterDays(ok), isTrue, reason: '$ok');
      }
      for (final bad in [0.1, 1.3, double.nan, double.infinity]) {
        expect(isQuarterDays(bad), isFalse, reason: '$bad');
      }
      expect(isWholeUnits(22, AbsenceUnit.day), isTrue);
      expect(isWholeUnits(22.5, AbsenceUnit.day), isFalse);
      expect(isWholeUnits(22.5, AbsenceUnit.half), isTrue);
      expect(isWholeUnits(22.25, AbsenceUnit.half), isFalse);
      expect(isWholeUnits(22.25, AbsenceUnit.quarter), isTrue);
    });

    test('the period defaults to the calendar year', () {
      const year = AbsenceBalance(year: 2027, type: 'v', allowedDays: 22);
      expect(year.start, const CivilDate(2027, 1, 1));
      expect(year.end, const CivilDate(2027, 12, 31));
      expect(year.contains(const CivilDate(2027, 12, 31)), isTrue);
      expect(year.contains(const CivilDate(2028, 1, 1)), isFalse);
      expect(year.displayName, 'v');
      const fiscal = AbsenceBalance(
        year: 2027,
        type: 'v',
        name: 'Vacaciones',
        allowedDays: 22,
        periodStart: CivilDate(2027, 4, 1),
        periodEnd: CivilDate(2028, 3, 31),
      );
      expect(fiscal.contains(const CivilDate(2028, 3, 31)), isTrue);
      expect(fiscal.contains(const CivilDate(2027, 3, 31)), isFalse);
      expect(fiscal.displayName, 'Vacaciones');
    });

    test('problem', () {
      const ok = AbsenceBalance(
        year: 2027,
        type: 'v',
        allowedDays: 22.5,
        unit: AbsenceUnit.half,
        shiftTypeQuarters: {'vac': 4, 'half': 2},
        carryOverMaxDays: 2.25,
        adjustmentDays: -1.75,
      );
      expect(ok.problem, isNull);
      AbsenceBalance balance({
        String type = 'v',
        String? name,
        double allowed = 22,
        AbsenceUnit unit = AbsenceUnit.day,
        CivilDate? start,
        CivilDate? end,
        Map<String, int> quarters = const {},
        double? cap,
        double adjustment = 0,
      }) => AbsenceBalance(
        year: 2027,
        type: type,
        name: name,
        allowedDays: allowed,
        unit: unit,
        periodStart: start,
        periodEnd: end,
        shiftTypeQuarters: quarters,
        carryOverMaxDays: cap,
        adjustmentDays: adjustment,
      );
      expect(balance(type: '').problem, 'empty type');
      expect(balance(name: ' ').problem, 'invalid name');
      expect(balance(allowed: -1).problem, contains('whole units'));
      expect(balance(allowed: 1.5).problem, contains('whole units'));
      expect(
        balance(start: const CivilDate(2027, 1, 1)).problem,
        contains('both'),
      );
      expect(
        balance(
          start: const CivilDate(2027, 5, 1),
          end: const CivilDate(2027, 4, 1),
        ).problem,
        contains('before'),
      );
      expect(balance(quarters: {'vac': 2}).problem, contains('quarters'));
      expect(balance(quarters: {'vac': 0}).problem, contains('quarters'));
      expect(
        balance(unit: AbsenceUnit.quarter, quarters: {'vac': 5}).problem,
        contains('quarters'),
      );
      expect(balance(quarters: {'': 4}).problem, 'empty shift type id');
      expect(balance(cap: -1).problem, 'invalid carry-over cap');
      expect(balance(cap: 0.1).problem, 'invalid carry-over cap');
      expect(balance(adjustment: 0.3).problem, 'invalid adjustment');
    });

    test('copyWith changes what it is given and keeps the rest', () {
      const balance = AbsenceBalance(
        year: 2027,
        type: 'vac',
        name: 'Vacaciones',
        allowedDays: 22,
        calendarId: 'main',
        shiftTypeQuarters: {'vacation': 4},
        carryOver: true,
        carryOverMaxDays: 5,
        adjustmentDays: 1,
        sortOrder: 2,
        createdAt: 10,
        updatedAt: 20,
      );
      final changed = balance.copyWith(allowedDays: 23, carryOver: false);
      expect(changed.allowedDays, 23);
      expect(changed.carryOver, isFalse);
      expect(changed.name, 'Vacaciones');
      expect(changed.calendarId, 'main');
      expect(changed.shiftTypeQuarters, {'vacation': 4});
      expect(changed.createdAt, 10);
      expect(changed.updatedAt, 20);

      final cleared = balance.copyWith(
        clearName: true,
        clearCalendarId: true,
        clearCarryOverMaxDays: true,
      );
      expect(cleared.name, isNull);
      expect(cleared.calendarId, isNull);
      expect(cleared.carryOverMaxDays, isNull);
      expect(cleared.displayName, 'vac');
    });
  });

  test('the quarters map is stored as sorted JSON and read back', () {
    const converter = StringIntMapConverter();
    expect(converter.toSql({'b': 2, 'a': 4}), '{"a":4,"b":2}');
    expect(converter.fromSql('{"b":2,"a":4}'), {'a': 4, 'b': 2});
  });

  group('repository', () {
    late AppDatabase db;
    setUp(() {
      db = openMemoryDatabase();
      addTearDown(db.close);
    });

    test('save, list, find, replace and delete', () async {
      final repo = AbsenceBalancesRepository(db);
      const vacation = AbsenceBalance(
        year: 2027,
        type: 'vac',
        name: 'Vacaciones',
        allowedDays: 22,
        calendarId: 'main',
        shiftTypeQuarters: {'vacation': 4},
        carryOver: true,
        carryOverMaxDays: 5,
        sortOrder: 1,
        createdAt: 1,
        updatedAt: 2,
      );
      const personal = AbsenceBalance(
        year: 2027,
        type: 'moscosos',
        allowedDays: 6.5,
        unit: AbsenceUnit.half,
      );
      const lastYear = AbsenceBalance(year: 2026, type: 'vac', allowedDays: 22);
      for (final b in [vacation, personal, lastYear]) {
        await repo.save(b);
      }
      expect(await repo.list(), [lastYear, personal, vacation]);
      expect(await repo.list(year: 2027), [personal, vacation]);
      expect(await repo.find(2027, 'vac'), vacation);
      expect(await repo.find(2025, 'vac'), isNull);

      const changed = AbsenceBalance(
        year: 2027,
        type: 'vac',
        name: 'Vacaciones',
        allowedDays: 23,
        calendarId: 'main',
      );
      await repo.save(changed);
      expect(await repo.find(2027, 'vac'), changed);
      final row = await (db.select(
        db.absenceBalances,
      )..where((t) => t.type.equals('vac') & t.year.equals(2027))).getSingle();
      expect(row.shiftTypeQuarters, isNull, reason: 'no types = NULL');

      expect(await repo.delete(2027, 'vac'), isTrue);
      expect(await repo.delete(2027, 'vac'), isFalse);
      expect(await repo.list(), [lastYear, personal]);
    });

    test('an invalid balance writes nothing; a missing calendar fails', () async {
      final repo = AbsenceBalancesRepository(db);
      await expectLater(
        repo.save(
          const AbsenceBalance(year: 2027, type: 'v', allowedDays: 0.3),
        ),
        throwsArgumentError,
      );
      await expectLater(
        repo.save(
          const AbsenceBalance(
            year: 2027,
            type: 'v',
            allowedDays: 1,
            calendarId: 'ghost',
          ),
        ),
        throwsA(anything),
      );
      expect(await repo.list(), isEmpty);
    });

    test('a row written before v6 (three columns) reads with defaults', () async {
      await db.customStatement(
        'INSERT INTO absence_balances (year, type, allowed_days) '
        "VALUES (2025, 'old', 1.3)",
      );
      expect(await AbsenceBalancesRepository(db).list(), const [
        AbsenceBalance(year: 2025, type: 'old', allowedDays: 1.3),
      ]);
    });
  });
}
