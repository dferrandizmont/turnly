import 'package:cuadrante/core/providers.dart';
import 'package:cuadrante/core/router.dart';
import 'package:cuadrante/features/calendar/application/schedule_controller.dart';
import 'package:cuadrante/features/calendars/data/calendars_repository.dart';
import 'package:cuadrante/features/calendars/domain/calendar.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/features/summary/domain/month_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_storage.dart';
import '../calendar/harness.dart';
import 'shift_types_screen_test.dart';

final _now = DateTime(2026, 10, 19, 12);
const _today = CivilDate(2026, 10, 19);

// Demo data: «correturnos» (21 days, M×5 L×2 T×5 L×2 N×5 L×2) from Monday
// 13 Jul, so 28 Sep-2 Oct and 19-23 Oct are nights. Guardia 24 h is used
// nowhere.
const _pastNight = CivilDate(2026, 9, 28);
const _todayNight = _today;

Finder _key(String key) => find.byKey(ValueKey(key));

void main() {
  group('the controller', () {
    late TestStorage storage;
    late ProviderContainer container;
    late CalendarsRepository calendars;

    ScheduleController controller() =>
        container.read(scheduleControllerProvider.notifier);
    ScheduleState state() => container.read(scheduleControllerProvider);
    ShiftType night() => state().schedule.shiftTypeById('night')!;
    ShiftType longNight() =>
        night().copyWith(endMinute: 8 * 60, hourlyRateCents: 1500);

    Future<Schedule> stored(String calendarId) async {
      await controller().pendingWrites;
      return (await storage.repository.load(calendarId)).schedule;
    }

    /// A second calendar with the same rotation from 1 Sep (nights 28 Sep
    /// and 19 Oct, like the main one).
    Future<String> secondCalendar() async {
      final id = (await calendars.create(name: 'Pareja', colorValue: 1)).id;
      await storage.repository.apply(
        id,
        ScheduleChange(
          runsBefore: const [],
          runsAfter: [
            PatternRun(
              id: 'pareja-run',
              patternId: 'correturnos',
              startDate: const CivilDate(2026, 7, 13),
              seq: await storage.repository.nextRunSeq(),
            ),
          ],
        ),
      );
      return id;
    }

    setUp(() async {
      storage = await TestStorage.open(now: _now);
      addTearDown(storage.close);
      calendars = CalendarsRepository(storage.database);
      container = ProviderContainer(
        overrides: [
          ...storage.overrides,
          clockProvider.overrideWithValue(() => _now),
        ],
      );
      addTearDown(() async {
        await controller().pendingWrites;
        container.dispose();
      });
    });

    test(
      'asks only for hours or money on a type already on days gone',
      () async {
        // Cosmetic: never.
        expect(
          await controller().shiftTypeEditChangesPast(
            night().copyWith(name: 'Nocturno', colorValue: 0xFF000000),
            _today,
          ),
          isFalse,
        );
        // Hours of a type on days gone: yes.
        expect(
          await controller().shiftTypeEditChangesPast(longNight(), _today),
          isTrue,
        );
        // Nothing gone uses the guard.
        final guard = state().schedule.shiftTypeById('guard24')!;
        expect(
          await controller().shiftTypeEditChangesPast(
            guard.copyWith(hourlyRateCents: 2000),
            _today,
          ),
          isFalse,
        );
        // Painted today or later: still nothing gone.
        controller().setDayShifts(_today, ['guard24']);
        controller().setDayShifts(_today.addDays(3), ['guard24']);
        expect(
          await controller().shiftTypeEditChangesPast(
            guard.copyWith(hourlyRateCents: 2000),
            _today,
          ),
          isFalse,
        );
        // A new type is never used.
        expect(
          await controller().shiftTypeEditChangesPast(
            guard.copyWith(id: 'brand-new'),
            _today,
          ),
          isFalse,
        );
      },
    );

    test(
      'a day gone in another calendar (even an archived one) counts',
      () async {
        final other = await secondCalendar();
        await storage.repository.apply(
          other,
          ScheduleChange(
            patch: EntriesPatch({
              const CivilDate(2026, 10, 1): EntryChange(
                null,
                const DayEntry(
                  date: CivilDate(2026, 10, 1),
                  shiftTypeIds: ['guard24'],
                ),
              ),
            }),
          ),
        );
        final guard = state().schedule.shiftTypeById('guard24')!;
        final edited = guard.copyWith(hourlyRateCents: 2000);
        expect(
          await controller().shiftTypeEditChangesPast(edited, _today),
          isTrue,
        );
        await calendars.archive(other);
        expect(
          await controller().shiftTypeEditChangesPast(edited, _today),
          isTrue,
        );
      },
    );

    test('«Solo a partir de hoy»: the past keeps hours and money in every '
        'calendar, today and after get the new ones', () async {
      final other = await secondCalendar();
      final before = state().schedule;
      final septemberBefore = summarizeMonth(before, _pastNight);
      final old = night();

      controller().saveShiftType(longNight(), onlyFrom: _today);

      void check(Schedule s, String reason) {
        final past = s.resolve(_pastNight).shifts.single;
        expect(past.id, 'night', reason: reason);
        expect(past.endMinute, old.endMinute, reason: reason);
        expect(past.hourlyRateCents, old.hourlyRateCents, reason: reason);
        final now = s.resolve(_todayNight).shifts.single;
        expect(now.endMinute, 8 * 60, reason: reason);
        expect(now.hourlyRateCents, 1500, reason: reason);
        expect(s.shiftTypeById('night'), longNight(), reason: reason);
      }

      check(state().schedule, 'memory');
      final septemberAfter = summarizeMonth(state().schedule, _pastNight);
      for (final (a, b) in [
        (septemberAfter.workedMinutes, septemberBefore.workedMinutes),
        (septemberAfter.nightMinutes, septemberBefore.nightMinutes),
        (septemberAfter.shiftsWorked, septemberBefore.shiftsWorked),
        (septemberAfter.earningsCents, septemberBefore.earningsCents),
      ]) {
        expect(a, b, reason: 'a month already worked does not change');
      }
      expect(
        summarizeMonth(state().schedule, _today).workedMinutes,
        greaterThan(summarizeMonth(before, _today).workedMinutes),
      );
      final main = await stored(mainCalendarId);
      check(main, 'stored');
      expectSameSchedule(main, state().schedule);
      check(await stored(other), 'other calendar');
      // The palette offers the one type, with its new terms.
      expect(
        [
          for (final t in state().palette)
            if (t.id == 'night') t,
        ],
        [longNight()],
      );
      // Switching calendars keeps the versions.
      await controller().switchCalendar(other);
      check(state().schedule, 'other calendar on screen');
    });

    test('«Corregir en todos los días» rewrites the past, as before', () async {
      controller().saveShiftType(longNight());
      final s = state().schedule;
      expect(s.resolve(_pastNight).shifts.single.endMinute, 8 * 60);
      expect(s.versionsOf('night'), isEmpty);
      expectSameSchedule(await stored(mainCalendarId), s);
    });

    test('after a change from today on, correcting reaches back to that day '
        'only', () async {
      controller().saveShiftType(longNight(), onlyFrom: _today);
      expect(
        await controller().shiftTypeEditChangesPast(
          longNight().copyWith(hourlyRateCents: 1600),
          _today,
        ),
        isFalse,
        reason: 'no day gone has the new terms yet',
      );
      // Tomorrow, today is gone with the new terms.
      expect(
        await controller().shiftTypeEditChangesPast(
          longNight().copyWith(hourlyRateCents: 1600),
          _today.addDays(1),
        ),
        isTrue,
      );
      controller().saveShiftType(longNight().copyWith(hourlyRateCents: 1600));
      final s = state().schedule;
      expect(s.resolve(_pastNight).shifts.single.hourlyRateCents, isNull);
      expect(s.resolve(_pastNight).shifts.single.endMinute, 6 * 60);
      expect(s.resolve(_todayNight).shifts.single.hourlyRateCents, 1600);
      expectSameSchedule(await stored(mainCalendarId), s);
    });

    test('the undo history keeps working: it only talks about days', () async {
      const day = CivilDate(2026, 10, 24);
      controller().setDayShifts(day, ['guard24']);
      expect(state().canUndo, isTrue);
      controller().saveShiftType(longNight(), onlyFrom: _today);
      expect(state().canUndo, isTrue);
      controller().undo();
      expect(
        state().schedule.resolve(day).shiftIds,
        isNot(contains('guard24')),
      );
      expect(state().schedule.versionsOf('night'), hasLength(1));
      expect(
        state().schedule.resolve(_pastNight).shifts.single.endMinute,
        6 * 60,
      );
      controller().redo();
      expect(state().schedule.resolve(day).shiftIds, ['guard24']);
      expectSameSchedule(await stored(mainCalendarId), state().schedule);
    });
  });

  group('the form', () {
    Future<void> openNight(WidgetTester tester) async {
      await pumpCalendar(tester);
      await openShiftTypes(tester);
      await tapKey(tester, 'shift-row-night');
    }

    testWidgets('a new rate on a type on days gone asks; «Solo a partir de '
        'hoy» keeps the past', (tester) async {
      await openNight(tester);
      await typeInto(tester, 'shift-rate', '15');
      await save(tester);
      expect(find.text('¿A qué días afecta el cambio?'), findsOneWidget);
      expect(find.text('Solo a partir de hoy'), findsOneWidget);
      expect(find.text('Corregir en todos los días'), findsOneWidget);
      await tapKey(tester, 'shift-scope-from-today');
      final s = stateOf(tester).schedule;
      expect(s.shiftTypeById('night')!.hourlyRateCents, 1500);
      expect(s.resolve(_pastNight).shifts.single.hourlyRateCents, isNull);
      expect(s.versionsOf('night').single.until, _today.addDays(-1));
      final stored = await storedSnapshot(tester);
      expect(stored.schedule.versionsOf('night'), s.versionsOf('night'));
      expect(_key('shift-save'), findsNothing, reason: 'the form closed');
    });

    testWidgets('cancelling saves nothing and stays in the form', (
      tester,
    ) async {
      await openNight(tester);
      await typeInto(tester, 'shift-rate', '15');
      await save(tester);
      await tapKey(tester, 'shift-scope-cancel');
      expect(_key('shift-save'), findsOneWidget);
      expect(
        stateOf(tester).schedule.shiftTypeById('night')!.hourlyRateCents,
        isNull,
      );
      expect(stateOf(tester).schedule.versionsOf('night'), isEmpty);
    });

    testWidgets('a change of name or colour does not ask', (tester) async {
      await openNight(tester);
      await typeInto(tester, 'shift-name', 'Nocturno');
      await save(tester);
      expect(_key('shift-scope-from-today'), findsNothing);
      expect(stateOf(tester).schedule.shiftTypeById('night')!.name, 'Nocturno');
      expect(
        (await storedSnapshot(tester)).schedule.shiftTypeById('night')!.name,
        'Nocturno',
      );
    });

    testWidgets('Q22: name, colour and 24 h hours survive choosing every day', (
      tester,
    ) async {
      await openNight(tester);
      await setTime(tester, 'shift-start', 8, 0);
      await setTime(tester, 'shift-end', 8, 0);
      const violet = 0xFF7950F2;
      await tapKey(tester, 'shift-color-${violet.toRadixString(16)}');
      await typeInto(tester, 'shift-name', 'Noche larga');
      await save(tester);
      expect(_key('shift-scope-every-day'), findsOneWidget);
      // The draft must remain uncommitted until the person chooses.
      expect(stateOf(tester).schedule.shiftTypeById('night')!.name, 'Noche');
      await tapKey(tester, 'shift-scope-every-day');
      final stored = (await storedSnapshot(tester)).schedule;
      final edited = stored.shiftTypeById('night')!;
      expect(edited.name, 'Noche larga');
      expect(edited.colorValue, violet);
      expect(edited.durationMinutes, 1440);
      expect(stored.resolve(_pastNight).shifts.single.name, 'Noche larga');
      expect(stored.resolve(_pastNight).shifts.single.durationMinutes, 1440);
      expect(_key('shift-save'), findsNothing);
    });

    testWidgets('a type not on any day gone does not ask', (tester) async {
      await pumpCalendar(tester);
      await openShiftTypes(tester);
      await tapKey(tester, 'shift-row-guard24');
      await typeInto(tester, 'shift-rate', '20');
      await save(tester);
      expect(_key('shift-scope-from-today'), findsNothing);
      expect(
        stateOf(tester).schedule.shiftTypeById('guard24')!.hourlyRateCents,
        2000,
      );
    });

    testWidgets('the dialog fits at 320 dp with text x2', (tester) async {
      await pumpCalendar(tester, size: const Size(320, 700), textScale: 2.0);
      appContainer(tester)
          .read(routerProvider)
          .go('${AppRoutes.shiftTypes}/editar/night');
      await tester.pumpAndSettle();
      await typeInto(tester, 'shift-rate', '15');
      await save(tester);
      expect(_key('shift-scope-every-day'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(_key('shift-scope-every-day'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(_key('shift-scope-from-today'));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(_key('shift-scope-from-today')),
        matchesSemantics(
          label:
              'Solo a partir de hoy, Ha cambiado tu jornada o tu precio: '
              'los días pasados se quedan como estaban.',
          isButton: true,
          hasTapAction: true,
        ),
      );
    });
  });
}
