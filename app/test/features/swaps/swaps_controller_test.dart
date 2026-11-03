import 'package:cuadrante/core/database/database_provider.dart';
import 'package:cuadrante/core/providers.dart';
import 'package:cuadrante/features/calendar/application/schedule_controller.dart';
import 'package:cuadrante/features/calendars/domain/calendar.dart';
import 'package:cuadrante/features/schedule/application/schedule_providers.dart';
import 'package:cuadrante/features/schedule/data/schedule_snapshot.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/features/swaps/application/swaps_controller.dart';
import 'package:cuadrante/features/swaps/application/swaps_providers.dart';
import 'package:cuadrante/features/swaps/domain/shift_swap.dart';
import 'package:cuadrante/features/swaps/domain/swap_ledger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_storage.dart';

final _now = DateTime(2026, 11, 2, 12);

/// The rotation of the tests: a morning and a night, one of each.
const _start = CivilDate(2026, 11, 2);
const _night = CivilDate(2026, 11, 3);
const _morningAgain = CivilDate(2026, 11, 4);

ShiftType _type(String key) => shiftTemplateByKey(key).toShiftType(key);

Schedule _schedule() => Schedule(
  shiftTypes: [_type('morning'), _type('night')],
  patterns: const [
    Pattern(id: 'p', name: 'P', steps: [
      ['morning'],
      ['night'],
    ]),
  ],
  runs: const [
    PatternRun(id: 'run-1', patternId: 'p', startDate: _start, seq: 1),
  ],
);

void main() {
  late TestStorage storage;
  late ProviderContainer container;

  setUp(() async {
    storage = await TestStorage.open(now: _now, demo: false);
    addTearDown(storage.close);
    // The rotation of the test, stored like the app would.
    final schedule = _schedule();
    await storage.repository.savePattern(schedule.patterns.first);
    await storage.repository.apply(
      mainCalendarId,
      ScheduleChange(runsAfter: schedule.runs),
    );

    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(storage.database),
        initialScheduleProvider.overrideWithValue(
          ScheduleSnapshot.fromSchedule(schedule),
        ),
        clockProvider.overrideWithValue(() => _now),
      ],
    );
    addTearDown(() async {
      await container.read(scheduleControllerProvider.notifier).pendingWrites;
      container.dispose();
    });
  });

  SwapsController swaps() => container.read(swapLedgerProvider.notifier);
  ScheduleController schedule() =>
      container.read(scheduleControllerProvider.notifier);
  Schedule state() => container.read(scheduleControllerProvider).schedule;
  Future<SwapLedger> currentLedger() =>
      container.read(swapLedgerProvider.future);
  Future<void> flush() =>
      container.read(scheduleControllerProvider.notifier).pendingWrites;
  ScheduleChange? apply(ShiftSwap swap) => swaps().applyToCalendar(swap);

  group('SwapsController', () {
    test('registers a change and shows it in the ledger', () async {
      final swap = await swaps().register(
        colleague: ' Marta ',
        date: _start,
        direction: SwapDirection.theyOwe,
        givenShiftTypeIds: const ['morning'],
        note: 'Me cubre la tarde',
      );
      expect(swap.colleague, 'Marta');
      expect(swap.calendarId, mainCalendarId);

      final ledger = await currentLedger();
      expect(ledger.swaps, hasLength(1));
      final balance = ledger.balances.single;
      expect(balance.colleague, 'Marta');
      expect(balance.theyOweMe, 1);
      expect(balance.pendingCount, 1);

      final stored = await container.read(shiftSwapsRepositoryProvider).list();
      expect(stored, hasLength(1));
      expect(stored.single.id, swap.id);
      expect(stored.single.note, 'Me cubre la tarde');
    });

    test('an invalid change writes nothing', () async {
      await expectLater(
        swaps().register(
          colleague: '   ',
          date: _start,
          direction: SwapDirection.theyOwe,
        ),
        throwsArgumentError,
      );
      expect(
        await container.read(shiftSwapsRepositoryProvider).list(),
        isEmpty,
      );
    });

    test('settles a change, reopens it and removes it', () async {
      final swap = await swaps().register(
        colleague: 'Marta',
        date: _start,
        direction: SwapDirection.theyOwe,
        givenShiftTypeIds: const ['morning'],
      );

      await swaps().settle(swap.id);
      var ledger = await currentLedger();
      expect(ledger.pending, isEmpty);
      expect(ledger.settled, hasLength(1));
      expect(ledger.balances.single.net, 0);
      expect(ledger.balances.single.settledCount, 1);

      await swaps().reopen(swap.id);
      ledger = await currentLedger();
      expect(ledger.pending, hasLength(1));
      expect(ledger.balances.single.net, 1);

      await swaps().remove(swap.id);
      ledger = await currentLedger();
      expect(ledger.swaps, isEmpty);
      expect(ledger.balances, isEmpty);
    });

    test('saves an edited change', () async {
      final swap = await swaps().register(
        colleague: 'Marta',
        date: _start,
        direction: SwapDirection.theyOwe,
      );
      await swaps().save(
        swap.copyWith(
          note: 'Me lo devuelve el lunes',
          returnDate: _morningAgain,
          receivedShiftTypeIds: const ['night'],
          updatedAt: 99,
        ),
      );
      final ledger = await currentLedger();
      final edited = ledger.swaps.single;
      expect(edited.note, 'Me lo devuelve el lunes');
      expect(edited.returnDate, _morningAgain);
      expect(edited.receivedShiftTypeIds, ['night']);
      expect(edited.stage, SwapStage.returned);
    });

    test('the changes of a day are the ones of that day and the ones that '
        'come back on it', () async {
      final swap = await swaps().register(
        colleague: 'Marta',
        date: _start,
        direction: SwapDirection.theyOwe,
        givenShiftTypeIds: const ['morning'],
        receivedShiftTypeIds: const ['night'],
        returnDate: _morningAgain,
      );
      await currentLedger();
      expect(container.read(swapsOfDayProvider(_start)), [swap]);
      expect(container.read(swapsOfDayProvider(_morningAgain)), [swap]);
      expect(container.read(swapsOfDayProvider(_night)), isEmpty);
    });

    test('applies a change to the calendar in one undo step', () async {
      final swap = await swaps().register(
        colleague: 'Marta',
        date: _start,
        direction: SwapDirection.theyOwe,
        givenShiftTypeIds: const ['morning'],
        receivedShiftTypeIds: const ['night'],
        returnDate: _morningAgain,
      );

      final step = swaps().applyToCalendar(swap);
      expect(step, isNotNull);
      // The day I gave is free and the day I receive is a night.
      expect(state().entries[_start]?.shiftTypeIds, isEmpty);
      expect(state().entries[_morningAgain]?.shiftTypeIds, const ['night']);
      await flush();

      final stored = await storage.repository.load(mainCalendarId);
      expect(stored.schedule.entries[_start]?.shiftTypeIds, isEmpty);
      expect(stored.schedule.entries[_morningAgain]?.shiftTypeIds, ['night']);

      // ONE undo step brings both days back.
      expect(schedule().undo(), isTrue);
      expect(state().entries[_start], isNull);
      expect(state().entries[_morningAgain], isNull);
      await flush();
      final afterUndo = await storage.repository.load(mainCalendarId);
      expect(afterUndo.schedule.entries[_start], isNull);
      expect(afterUndo.schedule.entries[_morningAgain], isNull);
    });

    test('takes the change back from the calendar', () async {
      final swap = await swaps().register(
        colleague: 'Marta',
        date: _start,
        direction: SwapDirection.theyOwe,
        givenShiftTypeIds: const ['morning'],
      );
      swaps().applyToCalendar(swap);
      expect(state().entries[_start]?.shiftTypeIds, isEmpty);
      await flush();

      final step = swaps().undoFromCalendar(swap);
      expect(step, isNotNull);
      expect(state().entries[_start], isNull);
      await flush();
      final stored = await storage.repository.load(mainCalendarId);
      expect(stored.schedule.entries[_start], isNull);
    });

    test('a change of another calendar is not applied', () async {
      final swap = await swaps().register(
        colleague: 'Marta',
        date: _start,
        direction: SwapDirection.theyOwe,
        givenShiftTypeIds: const ['morning'],
      );
      final other = swap.copyWith(calendarId: 'other');
      expect(apply(other), isNull);
      expect(state().entries[_start], isNull);
    });

    test('a change that changes nothing is not applied', () async {
      final swap = await swaps().register(
        colleague: 'Marta',
        date: _night,
        direction: SwapDirection.theyOwe,
        givenShiftTypeIds: const ['morning'],
      );
      expect(apply(swap), isNull);
      expect(state().entries[_night], isNull);
    });
  });
}
