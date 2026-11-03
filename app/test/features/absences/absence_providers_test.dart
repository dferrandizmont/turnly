import 'package:cuadrante/core/providers.dart';
import 'package:cuadrante/features/absences/application/absence_providers.dart';
import 'package:cuadrante/features/absences/data/absence_balances_repository.dart';
import 'package:cuadrante/features/absences/domain/absence_balance.dart';
import 'package:cuadrante/features/absences/domain/absence_status.dart';
import 'package:cuadrante/features/calendar/application/schedule_controller.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_storage.dart';

final _now = DateTime(2026, 10, 19, 12);

/// The balances of a year, read through the provider.
void main() {
  late TestStorage storage;
  late ProviderContainer container;

  setUp(() async {
    storage = await TestStorage.open(now: _now);
    addTearDown(storage.close);
    container = ProviderContainer(
      overrides: [
        ...storage.overrides,
        clockProvider.overrideWithValue(() => _now),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<List<AbsenceBalanceStatus>> balances(int year) async =>
      container.read(absenceBalancesProvider(year).future);

  AbsenceBalancesController controller() =>
      container.read(absenceBalancesProvider(2026).notifier);

  /// A balance of the vacations of 2026, counting the days of the type
  /// `vacation` (the demo data has it).
  const balance2026 = AbsenceBalance(
    year: 2026,
    type: 'vac',
    name: 'Vacaciones',
    allowedDays: 22,
    shiftTypeQuarters: {'vacation': 4},
  );

  test('without balances there is nothing', () async {
    expect(await balances(2026), isEmpty);
  });

  test('the days used come from the calendar on screen', () async {
    await controller().save(balance2026);
    // The demo data has two vacation days (today + 8 and + 9) and one more
    // in the past.
    container.read(scheduleControllerProvider.notifier).setDayShifts(
      const CivilDate(2026, 10, 5),
      const ['vacation'],
    );

    final statuses = await balances(2026);
    expect(statuses, hasLength(1));
    final status = statuses.single;
    expect(status.calendarId, 'main');
    expect(status.allowedDays, 22);
    expect(status.usedDays, 3);
    expect(status.enjoyedDays, 1, reason: 'the day of the 5th');
    expect(status.plannedDays, 2, reason: 'the two of the demo');
    expect(status.remainingDays, 19);
    expect(status.displayName, 'Vacaciones');
  });

  test('a balance of another year does not mix with it', () async {
    await controller().save(balance2026);
    await controller().save(
      const AbsenceBalance(year: 2027, type: 'vac', allowedDays: 22),
    );
    expect(await balances(2027), hasLength(1));
    expect((await balances(2027)).single.usedDays, 0);
  });

  test('the days of the year before are carried', () async {
    await controller().save(
      const AbsenceBalance(
        year: 2025,
        type: 'vac',
        allowedDays: 22,
        shiftTypeQuarters: {'vacation': 4},
      ),
    );
    await controller().save(
      const AbsenceBalance(
        year: 2026,
        type: 'vac',
        allowedDays: 22,
        carryOver: true,
        shiftTypeQuarters: {'vacation': 4},
      ),
    );
    final status = (await balances(2026)).single;
    expect(status.carriedDays, 22);
    expect(status.availableDays, 44);
  });

  test('the carried days expire the day the store says', () async {
    await controller().save(
      const AbsenceBalance(year: 2025, type: 'vac', allowedDays: 22),
    );
    await controller().save(
      const AbsenceBalance(
        year: 2026,
        type: 'vac',
        allowedDays: 22,
        carryOver: true,
      ),
    );
    await controller().setCarryOverExpiry(
      2026,
      'vac',
      const CivilDate(2026, 12, 31),
    );
    var status = (await balances(2026)).single;
    expect(status.expiredDays, 0);
    expect(status.warnings, [
      const CarryOverExpiring(days: 22, expiryDate: CivilDate(2026, 12, 31)),
    ]);

    // The day passes: the carried days are lost.
    await controller().setCarryOverExpiry(
      2026,
      'vac',
      const CivilDate(2026, 1, 31),
    );
    status = (await balances(2026)).single;
    expect(status.expiredDays, 22);
    expect(status.remainingDays, 22);
  });

  test('a balance is deleted', () async {
    await controller().save(balance2026);
    expect(await balances(2026), hasLength(1));
    expect(await controller().delete(2026, 'vac'), isTrue);
    expect(await balances(2026), isEmpty);
  });

  test('the balances of one calendar can be asked for', () async {
    await controller().save(balance2026);
    expect(
      await container.read(
        absenceBalancesForCalendarProvider((calendarId: 'main', year: 2026))
            .future,
      ),
      hasLength(1),
    );
    expect(
      await container.read(
        absenceBalancesForCalendarProvider((calendarId: 'other', year: 2026))
            .future,
      ),
      isEmpty,
    );
  });

  test('the row is stamped and keeps the day it was created', () async {
    final repository = AbsenceBalancesRepository(storage.database);
    await controller().save(balance2026);
    final first = await repository.find(2026, 'vac');
    expect(first?.createdAt, isNotNull);
    expect(first?.updatedAt, isNotNull);

    await controller().save(balance2026.copyWith(allowedDays: 23));
    final second = await repository.find(2026, 'vac');
    expect(second?.createdAt, first?.createdAt);
    expect(second?.updatedAt, first?.updatedAt, reason: 'the same clock');
    expect(second?.allowedDays, 23);
  });

  test('a new series has its own key', () {
    final first = AbsenceBalancesRepository.newSeriesId();
    final second = AbsenceBalancesRepository.newSeriesId();
    expect(first, isNotEmpty);
    expect(first, isNot(second));
  });
}
