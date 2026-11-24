import 'dart:io';

import 'package:cuadrante/core/database/app_database.dart';
import 'package:cuadrante/features/calendars/data/calendars_repository.dart';
import 'package:cuadrante/features/schedule/data/schedule_repository.dart';
import 'package:drift/native.dart';
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
import 'package:cuadrante/features/swaps/domain/swap_schedule_plan.dart';
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
    Pattern(
      id: 'p',
      name: 'P',
      steps: [
        ['morning'],
        ['night'],
      ],
    ),
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
  Future<ScheduleChange?> apply(ShiftSwap swap) =>
      swaps().applyToCalendar(swap);
  Future<Map<CivilDate, List<String>?>> records(ShiftSwap swap) async => {
    for (final row
        in await container.read(swapAppliedStoreProvider).before(swap.id))
      row.date: row.previousShiftTypeIds,
  };

  Future<ShiftSwap> register({CivilDate? returnDate = _morningAgain}) =>
      swaps().register(
        colleague: 'Marta',
        date: _start,
        direction: SwapDirection.theyOwe,
        givenShiftTypeIds: const ['morning'],
        receivedShiftTypeIds: const ['night'],
        returnDate: returnDate,
      );

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

      final step = await apply(swap);
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
      await apply(swap);
      expect(state().entries[_start]?.shiftTypeIds, isEmpty);
      await flush();

      final step = await swaps().undoFromCalendar(swap);
      expect(step, isNotNull);
      expect(state().entries[_start], isNull);
      await flush();
      final stored = await storage.repository.load(mainCalendarId);
      expect(stored.schedule.entries[_start], isNull);
    });

    test(
      'reapplying after Mark returned keeps the original dates and overrides',
      () async {
        final swap = await register(returnDate: null);
        await apply(swap);
        await swaps().markReturned(swap.id, _morningAgain);
        final completed = (await currentLedger()).swaps.single;
        await apply(completed);
        expect(await records(swap), {_start: null, _morningAgain: null});

        schedule().setShiftOnDays([_start], 'morning');
        await apply(completed);
        expect(await records(swap), {_start: null, _morningAgain: null});
        await swaps().undoFromCalendar(completed);
        expect(state().entries, isEmpty);
      },
    );

    test(
      'without a record, unapplying leaves matching handmade overrides alone',
      () async {
        schedule().clearDays([_start]);
        schedule().setShiftOnDays([_morningAgain], 'night');
        final swap = await register();
        final before = state().entries;
        expect(await apply(swap), isNull);
        expect(await swaps().undoFromCalendar(swap), isNull);
        expect(state().entries, before);
        final sameDay = await register(returnDate: _start);
        expect(await swaps().undoFromCalendar(sameDay), isNull);
        expect(state().entries, before);
      },
    );

    test(
      'undo and redo of an unapply keep the exact record in both directions',
      () async {
        schedule().doubleShiftOnDays([_morningAgain], 'night');
        final before = state().entries[_morningAgain];
        final swap = await register();
        await apply(swap);
        final step = await swaps().undoFromCalendar(swap);
        expect(await records(swap), isEmpty);
        expect(state().entries[_morningAgain], before);
        expect(schedule().undoIfLast(step!), isTrue);
        await flush();
        expect(await records(swap), {
          _start: null,
          _morningAgain: ['morning', 'night'],
        });
        expect(schedule().redo(), isTrue);
        await flush();
        expect(await records(swap), isEmpty);
        expect(state().entries[_morningAgain], before);
        expect(schedule().undo(), isTrue);
        await flush();
        await swaps().undoFromCalendar(swap);
        expect(state().entries[_morningAgain], before);
      },
    );

    test('failure inserting the second application row rolls back the days and first row', () async {
      final swap = await register();
      await storage.database.customStatement("""
        CREATE TRIGGER fail_swap_record BEFORE INSERT ON swap_applications
        WHEN NEW.date = '2026-11-04'
        BEGIN SELECT RAISE(ABORT, 'test failure'); END
      """);
      await expectLater(apply(swap), throwsA(anything));
      expect(await records(swap), isEmpty);
      expect(
        (await storage.repository.load(mainCalendarId)).schedule.entries,
        isEmpty,
      );
      expect(state().entries, isEmpty);
      expect(schedule().undo(), isFalse);
    });

    test(
      'duplicate application while the first is queued is ignored',
      () async {
        final swap = await register();
        final first = apply(swap);
        final duplicate = apply(swap);
        expect(await duplicate, isNull);
        expect(await first, isNotNull);
        expect(await records(swap), hasLength(2));
        expect(schedule().undo(), isTrue);
        expect(schedule().undo(), isFalse);
      },
    );

    for (final applyEdit in [false, true]) {
      test('editing with switch $applyEdit keeps a later hand edit', () async {
        final swap = await register();
        await apply(swap);
        schedule().clearDays([_morningAgain]);
        var skipped = const <CivilDate>[];

        final step = await swaps().save(
          swap.copyWith(returnDate: _night),
          apply: applyEdit,
          onSkipped: (days) => skipped = days,
        );

        expect(step, isNotNull);
        expect(skipped, [_morningAgain]);
        expect(state().entries[_morningAgain]?.shiftTypeIds, isEmpty);
        expect(
          state().entries[_start]?.shiftTypeIds,
          applyEdit ? isEmpty : null,
        );
        expect(await records(swap), containsPair(_morningAgain, null));
        expect(
          (await storage.repository.load(mainCalendarId))
              .schedule
              .entries[_morningAgain]
              ?.shiftTypeIds,
          isEmpty,
        );
      });

      test(
        'editing an applied swap with switch $applyEdit is one undo step',
        () async {
          schedule().doubleShiftOnDays([_morningAgain], 'night');
          final handmade = state().entries[_morningAgain];
          final swap = await register();
          await apply(swap);
          final afterOriginal = state().entries;
          final originalRecords = await records(swap);
          final edited = swap.copyWith(
            date: _night,
            givenShiftTypeIds: ['night'],
          );
          final step = await swaps().save(edited, apply: applyEdit);
          expect(step, isNotNull);
          expect(state().entries[_start], isNull);
          expect(
            state().entries[_night]?.shiftTypeIds,
            applyEdit ? isEmpty : isNull,
          );
          expect(
            state().entries[_morningAgain],
            applyEdit ? isNot(handmade) : handmade,
          );
          expect(await records(swap), applyEdit ? hasLength(2) : isEmpty);

          expect(schedule().undoIfLast(step!), isTrue);
          await flush();
          expect(
            await container.read(shiftSwapsRepositoryProvider).byId(swap.id),
            swap,
          );
          expect(state().entries, afterOriginal);
          expect(await records(swap), originalRecords);
          expect(schedule().redo(), isTrue);
          await flush();
          expect(
            await container.read(shiftSwapsRepositoryProvider).byId(swap.id),
            edited,
          );
        },
      );
    }

    test(
      'a swap is not applied over a day another applied swap holds',
      () async {
        final older = await register();
        final newer = await swaps().register(
          colleague: 'Luis',
          date: _night,
          direction: SwapDirection.iOwe,
          returnDate: _morningAgain,
          receivedShiftTypeIds: const ['morning', 'night'],
        );
        await apply(older);
        final shown = state().entries;
        final olderRecords = await records(older);

        await expectLater(
          apply(newer),
          throwsA(
            isA<SwapApplyConflict>()
                .having((e) => e.claim.date, 'date', _morningAgain)
                .having((e) => e.claim.swapId, 'swapId', older.id)
                .having((e) => e.claim.colleague, 'colleague', 'Marta'),
          ),
        );
        await flush();
        expect(state().entries, shown);
        expect(
          (await storage.repository.load(mainCalendarId)).schedule.entries,
          shown,
        );
        expect(await records(newer), isEmpty);
        expect(await records(older), olderRecords);

        // The history is untouched: undo takes the older swap off, and then
        // the newer one can be applied.
        expect(schedule().undo(), isTrue);
        await flush();
        expect(state().entries, isEmpty);
        expect(await apply(newer), isNotNull);
        expect(await records(newer), {_morningAgain: null});
      },
    );

    test(
      'saving a new swap that would apply over another one saves nothing',
      () async {
        final older = await register();
        await apply(older);
        final shown = state().entries;
        final draft = ShiftSwap(
          id: swaps().newId(),
          calendarId: mainCalendarId,
          date: _night,
          colleague: 'Luis',
          direction: SwapDirection.iOwe,
          returnDate: _morningAgain,
          receivedShiftTypeIds: const ['morning'],
          createdAt: 1,
          updatedAt: 1,
        );

        await expectLater(
          swaps().save(draft, apply: true, isNew: true),
          throwsA(isA<SwapApplyConflict>()),
        );
        await flush();
        expect(
          await container.read(shiftSwapsRepositoryProvider).byId(draft.id),
          isNull,
        );
        expect(state().entries, shown);
        expect(await records(older), hasLength(2));
        // Without applying, the swap is saved as usual.
        expect(await swaps().save(draft, isNew: true), isNull);
        expect(
          await container.read(shiftSwapsRepositoryProvider).byId(draft.id),
          draft,
        );
      },
    );

    test(
      'a swap is refused while a later edit of its day is still queued',
      () async {
        const note = 'Llevar las llaves';
        final swap = await register(returnDate: null);
        Future<DayEntry?> reloaded() async =>
            (await storage.repository.load(mainCalendarId))
                .schedule
                .entries[_start];

        // The swap is queued first; the note is shown at once and its
        // whole-day write waits behind the swap.
        final applying = apply(swap);
        schedule().setNote(_start, note);
        await expectLater(applying, throwsStateError);
        await flush();

        expect(state().entries[_start]?.shiftTypeIds, isNull);
        expect(state().entries[_start]?.note, note);
        expect(await reloaded(), state().entries[_start]);
        expect(await records(swap), isEmpty);

        // With the queue quiet, applying again keeps the note.
        expect(await apply(swap), isNotNull);
        expect(state().entries[_start]?.shiftTypeIds, isEmpty);
        expect(state().entries[_start]?.note, note);
        expect(await reloaded(), state().entries[_start]);
        expect(await records(swap), {_start: null});
      },
    );

    test(
      'two swaps with a note queued between them run in queue order',
      () async {
        const note = 'Llevar las llaves';
        final first = await register(returnDate: null);
        final second = await swaps().register(
          colleague: 'Luis',
          date: _night,
          direction: SwapDirection.theyOwe,
          givenShiftTypeIds: const ['night'],
        );
        Future<Map<CivilDate, DayEntry>> stored() async =>
            (await storage.repository.load(mainCalendarId)).schedule.entries;

        final applyingFirst = apply(first);
        schedule().setNote(_night, note);
        final applyingSecond = apply(second);
        final steps = await Future.wait([applyingFirst, applyingSecond]);
        await flush();

        expect(steps, everyElement(isNotNull));
        expect(state().entries[_start]?.shiftTypeIds, isEmpty);
        expect(state().entries[_night]?.shiftTypeIds, isEmpty);
        expect(state().entries[_night]?.note, note);
        expect(await stored(), state().entries);
        expect(await records(first), {_start: null});
        expect(await records(second), {_night: null});

        // Undo goes back step by step: the second swap, the first, the note.
        expect(schedule().undo(), isTrue);
        await flush();
        expect(state().entries[_night]?.shiftTypeIds, isNull);
        expect(state().entries[_night]?.note, note);
        expect(await records(second), isEmpty);
        expect(schedule().undo(), isTrue);
        await flush();
        expect(state().entries[_start], isNull);
        expect(await records(first), isEmpty);
        expect(schedule().undo(), isTrue);
        await flush();
        expect(state().entries, isEmpty);
        expect(await stored(), isEmpty);
      },
    );

    test('undoing a removal while another swap waits never leaves two swaps on '
        'a day', () async {
      final a = await register(returnDate: null);
      await apply(a);
      final removal = await swaps().remove(a.id);
      expect(removal, isNotNull);
      final b = await swaps().register(
        colleague: 'Luis',
        date: _night,
        direction: SwapDirection.iOwe,
        returnDate: _start,
        receivedShiftTypeIds: const ['night'],
      );

      // B is queued first; the removal's Undo, which brings back A's
      // record of the same day without changing any day, right behind it.
      final applying = apply(b);
      expect(schedule().undoIfLast(removal!), isTrue);
      try {
        await applying;
      } catch (_) {}
      await flush();

      final claims = await container
          .read(swapAppliedStoreProvider)
          .claims(mainCalendarId);
      expect(claims.where((claim) => claim.date == _start), hasLength(1));
      expect(
        (await storage.repository.load(mainCalendarId)).schedule.entries,
        state().entries,
      );
    });

    test(
      'a later edit that clears one day refuses the whole two-day swap',
      () async {
        final swap = await register();
        final applying = apply(swap);
        // Shown at once, written after the swap's job.
        schedule().clearDays([_start]);
        await expectLater(applying, throwsStateError);
        await flush();

        expect(await records(swap), isEmpty);
        expect(state().entries[_start]?.shiftTypeIds, isEmpty);
        expect(state().entries[_morningAgain], isNull);
        expect(
          (await storage.repository.load(mainCalendarId)).schedule.entries,
          state().entries,
        );
      },
    );

    test('an undo of a moved swap waiting behind its own apply keeps every '
        'changed day recorded', () async {
      final swap = await register(returnDate: null);
      await apply(swap);
      expect(state().entries[_start]?.shiftTypeIds, isEmpty);
      // Moved to Tuesday with the switch off: Monday comes back.
      final moved = swap.copyWith(date: _night, givenShiftTypeIds: ['night']);
      final step = await swaps().save(moved);
      expect(step, isNotNull);
      expect(state().entries[_start], isNull);
      expect(await records(swap), isEmpty);

      // «Aplicar» on the card, then the notice's «Deshacer» right behind.
      final applying = apply(moved);
      expect(schedule().undoIfLast(step!), isTrue);
      try {
        await applying;
      } catch (_) {}
      await flush();

      // Every day the swap changed has its record, and memory matches disk.
      final stored = await container
          .read(shiftSwapsRepositoryProvider)
          .byId(swap.id);
      final recorded = await records(swap);
      for (final date in [_start, _night]) {
        final changed = state().entries[date]?.shiftTypeIds?.isEmpty ?? false;
        expect(
          recorded.containsKey(date),
          changed,
          reason: '$date changed: $changed',
        );
      }
      expect(stored?.date, _start);
      expect(recorded, {_start: null});
      expect(state().entries[_night], isNull);
      expect(
        (await storage.repository.load(mainCalendarId)).schedule.entries,
        state().entries,
      );
    });

    test(
      'distinct swaps queued together use the schedule in queue order',
      () async {
        final first = await register(returnDate: null);
        final second = await swaps().register(
          colleague: 'Luis',
          date: _night,
          direction: SwapDirection.theyOwe,
          givenShiftTypeIds: const ['night'],
        );
        final steps = await Future.wait([apply(first), apply(second)]);
        expect(steps, everyElement(isNotNull));
        expect(state().entries[_start]?.shiftTypeIds, isEmpty);
        expect(state().entries[_night]?.shiftTypeIds, isEmpty);
        expect(await records(first), {_start: null});
        expect(await records(second), {_night: null});
      },
    );

    test('a timestamp-only save leaves undo and redo alone', () async {
      final swap = await register();
      schedule().clearDays([_start]);
      expect(schedule().undo(), isTrue);

      expect(
        await swaps().save(swap.copyWith(updatedAt: swap.updatedAt + 1)),
        isNull,
      );
      expect(schedule().undo(), isFalse);
      expect(schedule().redo(), isTrue);
      expect((await currentLedger()).swaps.single, swap);
    });

    test('restore and remove keeps the swap when a date conflicts', () async {
      final swap = await register();
      await apply(swap);
      schedule().setShiftOnDays([_morningAgain], 'morning');
      final before = state().entries;
      final applicationRows = await records(swap);
      var skipped = const <CivilDate>[];
      expect(
        await swaps().remove(
          swap.id,
          restoreCalendar: true,
          onSkipped: (days) => skipped = days,
        ),
        isNull,
      );
      expect(skipped, [_morningAgain]);
      expect(await records(swap), applicationRows);
      expect(state().entries, before);
      expect((await currentLedger()).swaps.single, swap);
    });

    for (final restore in [false, true]) {
      test(
        'remove with restore $restore is one step including the records',
        () async {
          final swap = await register();
          await apply(swap);
          final applied = state().entries;
          final originalRecords = await records(swap);
          final step = await swaps().remove(swap.id, restoreCalendar: restore);
          expect(await records(swap), isEmpty);
          expect((await currentLedger()).swaps, isEmpty);
          expect(state().entries, restore ? isEmpty : applied);
          expect(schedule().undoIfLast(step!), isTrue);
          await flush();
          expect(state().entries, applied);
          expect(await records(swap), originalRecords);
          expect(
            await container.read(shiftSwapsRepositoryProvider).byId(swap.id),
            swap,
          );
          expect(schedule().redo(), isTrue);
          await flush();
          expect(await records(swap), isEmpty);
        },
      );
    }

    test(
      'removing an archived calendar cascades to applied swap rows',
      () async {
        final repo = CalendarsRepository(storage.database);
        final other = await repo.create(
          name: 'Trabajo',
          colorValue: 0xff123456,
        );
        await schedule().switchCalendar(other.id);
        schedule().setShiftOnDays([_start], 'morning');
        final swap = await register(returnDate: null);
        expect(await apply(swap), isNotNull);
        await schedule().switchCalendar(mainCalendarId);
        await repo.archive(other.id);
        await repo.deleteArchived(other.id);
        expect(await records(swap), isEmpty);
        expect(
          await container.read(shiftSwapsRepositoryProvider).byId(swap.id),
          isNull,
        );
      },
    );

    test(
      'unapplying filters deleted types and preserves explicitly empty days',
      () async {
        final orphan = shiftTemplateByKey('afternoon')
            .toShiftType('deleted-type');
        await storage.repository.saveShiftType(orphan);
        await schedule().reload();
        schedule().doubleShiftOnDays([_morningAgain], orphan.id);
        final swap = await register();
        await apply(swap);
        expect(
          await storage.repository.deleteShiftTypeIfUnused(orphan.id),
          isTrue,
        );
        await schedule().reload();
        await swaps().undoFromCalendar(swap);
        expect(state().entries[_morningAgain]?.shiftTypeIds, ['morning']);

        schedule().clearDays([_morningAgain]);
        await apply(swap);
        await swaps().undoFromCalendar(swap);
        expect(state().entries[_morningAgain]?.shiftTypeIds, isEmpty);
      },
    );

    test(
      'a file database reopened on a new connection restores the override',
      () async {
        final dir = makeTempDir('swap-restart');
        final file = File.fromUri(dir.uri.resolve('swaps.sqlite'));
        var db = AppDatabase(NativeDatabase(file));
        var repo = ScheduleRepository(db);
        final type = _type('night');
        await repo.saveShiftType(type);
        await repo.saveShiftType(_type('morning'));
        final handMade = DayEntry(
          date: _morningAgain,
          shiftTypeIds: const ['morning'],
        );
        await repo.apply(
          mainCalendarId,
          ScheduleChange(
            patch: EntriesPatch({_morningAgain: EntryChange(null, handMade)}),
          ),
        );

        Future<ProviderContainer> openSession() async {
          final snapshot = await repo.load(mainCalendarId);
          return ProviderContainer(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              initialScheduleProvider.overrideWithValue(snapshot),
              clockProvider.overrideWithValue(() => _now),
            ],
          );
        }

        var session = await openSession();
        var controller = session.read(swapLedgerProvider.notifier);
        final swap = await controller.register(
          colleague: 'Marta',
          date: _start,
          direction: SwapDirection.theyOwe,
          returnDate: _morningAgain,
          receivedShiftTypeIds: [type.id],
        );
        expect(await controller.applyToCalendar(swap), isNotNull);
        session.dispose();
        await db.close();

        db = AppDatabase(NativeDatabase(file));
        addTearDown(db.close);
        repo = ScheduleRepository(db);
        session = await openSession();
        addTearDown(session.dispose);
        controller = session.read(swapLedgerProvider.notifier);
        expect(await controller.undoFromCalendar(swap), isNotNull);
        expect(
          (await repo.load(mainCalendarId)).schedule.entries[_morningAgain],
          handMade,
        );
      },
    );

    test('a change of another calendar is not applied', () async {
      final swap = await swaps().register(
        colleague: 'Marta',
        date: _start,
        direction: SwapDirection.theyOwe,
        givenShiftTypeIds: const ['morning'],
      );
      final other = swap.copyWith(calendarId: 'other');
      expect(await apply(other), isNull);
      expect(state().entries[_start], isNull);
    });

    test('a change that changes nothing is not applied', () async {
      final swap = await swaps().register(
        colleague: 'Marta',
        date: _night,
        direction: SwapDirection.theyOwe,
        givenShiftTypeIds: const ['morning'],
      );
      expect(await apply(swap), isNull);
      expect(state().entries[_night], isNull);
    });
  });
}
