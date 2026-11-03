import 'package:cuadrante/features/calendar/application/schedule_controller.dart';
import 'package:cuadrante/features/calendars/application/calendars_controller.dart';
import 'package:cuadrante/features/calendars/application/compare_providers.dart';
import 'package:cuadrante/features/calendars/domain/calendar.dart';
import 'package:cuadrante/features/calendars/domain/calendar_comparison.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _work = ShiftType(
  id: 'work',
  code: 'M',
  name: 'Mañana',
  colorValue: 0xFFF5A524,
  category: ShiftCategory.work,
  startMinute: 6 * 60,
  endMinute: 14 * 60,
);
const _rest = ShiftType(
  id: 'rest',
  code: 'L',
  name: 'Libre',
  colorValue: 0xFFE4E4E7,
  category: ShiftCategory.rest,
);

/// A schedule made of single-day entries, every other day empty.
Schedule _days(Map<CivilDate, List<String>> days) => Schedule(
  shiftTypes: const [_work, _rest],
  entries: {
    for (final e in days.entries)
      e.key: DayEntry(date: e.key, shiftTypeIds: e.value),
  },
);

CivilDate _oct(int day) => CivilDate(2026, 10, day);

/// The first calendar works the 3rd and the 10th; the second one rests the
/// 3rd and the 10th and the 17th; the third one rests the 17th and the 24th.
final _scheduleA = _days({
  _oct(3): ['work'],
  _oct(10): ['work'],
});
final _scheduleB = _days({
  _oct(3): ['rest'],
  _oct(10): ['rest'],
  _oct(17): ['rest'],
});
final _scheduleC = _days({
  _oct(17): ['rest'],
  _oct(24): ['rest'],
});

const _c1 = Calendar(id: 'c1', name: 'Uno', colorValue: 1, sortOrder: 0);
const _c2 = Calendar(id: 'c2', name: 'Dos', colorValue: 2, sortOrder: 1);
const _c3 = Calendar(id: 'c3', name: 'Tres', colorValue: 3, sortOrder: 2);
const _c4 = Calendar(id: 'c4', name: 'Cuatro', colorValue: 4, sortOrder: 3);

/// The calendars of the app, without touching the database.
class _FixedCalendars extends CalendarsController {
  _FixedCalendars(this.fixed);

  final CalendarsState fixed;

  @override
  Future<CalendarsState> build() async => fixed;
}

/// The calendar on screen, without touching the database.
class _FixedSchedule extends ScheduleController {
  _FixedSchedule(this.calendarId);

  final String calendarId;

  @override
  ScheduleState build() =>
      ScheduleState(schedule: Schedule(), calendarId: calendarId);
}

void main() {
  ProviderContainer makeContainer({
    List<Calendar> calendars = const [_c1, _c2, _c3, _c4],
    String activeId = 'c1',
  }) {
    final container = ProviderContainer(
      overrides: [
        compareScheduleProvider('c1').overrideWith((ref) async => _scheduleA),
        compareScheduleProvider('c2').overrideWith((ref) async => _scheduleB),
        compareScheduleProvider('c3').overrideWith((ref) async => _scheduleC),
        compareScheduleProvider('c4').overrideWith((ref) async => _scheduleA),
        calendarsControllerProvider.overrideWith(
          () => _FixedCalendars(
            CalendarsState(calendars: calendars, primaryId: activeId),
          ),
        ),
        scheduleControllerProvider.overrideWith(() => _FixedSchedule(activeId)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('CompareRequest', () {
    test('two requests with the same calendars and days are the same', () {
      final a = CompareRequest(
        calendars: const [_c1, _c2],
        from: _oct(1),
        to: _oct(31),
      );
      final b = CompareRequest(
        calendars: const [_c1, _c2],
        from: _oct(1),
        to: _oct(31),
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.calendarCount, 2);
    });

    test('the order of the calendars matters', () {
      final a = CompareRequest(
        calendars: const [_c1, _c2],
        from: _oct(1),
        to: _oct(31),
      );
      final b = CompareRequest(
        calendars: const [_c2, _c1],
        from: _oct(1),
        to: _oct(31),
      );
      expect(a, isNot(b));
    });

    test('the days matter', () {
      final a = CompareRequest(
        calendars: const [_c1, _c2],
        from: _oct(1),
        to: _oct(31),
      );
      final b = CompareRequest(
        calendars: const [_c1, _c2],
        from: _oct(1),
        to: _oct(30),
      );
      expect(a, isNot(b));
    });

    test('the month request covers the whole month', () {
      final request = CompareRequest.month(
        calendars: const [_c1, _c2],
        month: _oct(15),
      );
      expect(request.from, _oct(1));
      expect(request.to, _oct(31));
      expect(request.to, request.from.lastDayOfMonth);
    });

    test('the month request of February of a leap year has 29 days', () {
      final request = CompareRequest.month(
        calendars: const [_c1, _c2],
        month: const CivilDate(2028, 2, 10),
      );
      expect(request.from, const CivilDate(2028, 2, 1));
      expect(request.to, const CivilDate(2028, 2, 29));
    });

    test('it says which calendars and which days it asks for', () {
      final request = CompareRequest.month(
        calendars: const [_c1, _c2],
        month: _oct(1),
      );
      expect(request.toString(), contains('c1, c2'));
      expect(request.toString(), contains('2026-10-01..2026-10-31'));
    });

    test('more than six calendars are cut to the first six', () {
      final many = [
        for (var i = 0; i < 8; i++)
          Calendar(id: 'c$i', name: 'C$i', colorValue: i, sortOrder: i),
      ];
      final request = CompareRequest(
        calendars: many,
        from: _oct(1),
        to: _oct(31),
      );
      expect(request.calendarCount, maxComparedCalendars);
      expect(request.calendars.map((c) => c.id), [
        'c0',
        'c1',
        'c2',
        'c3',
        'c4',
        'c5',
      ]);
      final month = CompareRequest.month(calendars: many, month: _oct(1));
      expect(month.calendarCount, maxComparedCalendars);
    });
  });

  group('ComparedSelection', () {
    test('two selections with the same ids are the same', () {
      expect(
        ComparedSelection(['c1', 'c2']),
        ComparedSelection(['c1', 'c2']),
      );
      expect(
        ComparedSelection(['c1', 'c2']).hashCode,
        ComparedSelection(['c1', 'c2']).hashCode,
      );
    });

    test('the order of the ids matters', () {
      expect(
        ComparedSelection(['c1', 'c2']),
        isNot(ComparedSelection(['c2', 'c1'])),
      );
    });
  });

  group('comparedCalendarsProvider', () {
    test('with nothing picked it opens on the calendar on screen and the '
        'next one', () async {
      final container = makeContainer(activeId: 'c2');
      await container.read(calendarsControllerProvider.future);
      final chosen = container.read(
        comparedCalendarsProvider(ComparedSelection([])),
      );
      expect(chosen.map((c) => c.id), ['c2', 'c3']);
    });

    test('the picked calendars come first, in the order they were picked',
        () async {
      final container = makeContainer();
      await container.read(calendarsControllerProvider.future);
      final chosen = container.read(
        comparedCalendarsProvider(ComparedSelection(['c3', 'c2'])),
      );
      expect(chosen.map((c) => c.id), ['c3', 'c2']);
    });

    test('an unknown id is dropped', () async {
      final container = makeContainer();
      await container.read(calendarsControllerProvider.future);
      final chosen = container.read(
        comparedCalendarsProvider(ComparedSelection(['gone', 'c4'])),
      );
      expect(
        chosen.map((c) => c.id),
        ['c4', 'c1'],
        reason: 'the unknown id is dropped and the screen calendar tops it up',
      );
    });

    test('at most six calendars are compared', () async {
      final many = [
        for (var i = 0; i < 8; i++)
          Calendar(id: 'c$i', name: 'C$i', colorValue: i, sortOrder: i),
      ];
      final container = makeContainer(calendars: many);
      await container.read(calendarsControllerProvider.future);
      final chosen = container.read(
        comparedCalendarsProvider(
          ComparedSelection([for (var i = 0; i < 8; i++) 'c$i']),
        ),
      );
      expect(chosen, hasLength(maxComparedCalendars));
      expect(chosen.map((c) => c.id), ['c0', 'c1', 'c2', 'c3', 'c4', 'c5']);
    });

    test('with a single calendar there is only that one', () async {
      final container = makeContainer(calendars: const [_c1]);
      await container.read(calendarsControllerProvider.future);
      final chosen = container.read(
        comparedCalendarsProvider(ComparedSelection([])),
      );
      expect(chosen.map((c) => c.id), ['c1']);
    });
  });

  group('multiComparisonProvider', () {
    test('it compares the schedules of the calendars asked for', () async {
      final container = makeContainer();
      final request = CompareRequest.month(
        calendars: const [_c1, _c2, _c3],
        month: _oct(1),
      );
      final comparison = await container.read(
        multiComparisonProvider(request).future,
      );
      expect(comparison.calendars.map((c) => c.id), ['c1', 'c2', 'c3']);
      expect(comparison.days, hasLength(31));
      expect(comparison.days.first.date, _oct(1));
      expect(comparison.days.last.date, _oct(31));
      // The 3rd: the first works, the second rests and the third has nothing.
      final third = comparison.days[2];
      expect(third.workingIndexes, [0]);
      expect(third.freeIndexes, [1]);
      expect(
        third.hasUnrecorded,
        isFalse,
        reason: 'the first one works, so the day is busy, not unrecorded',
      );
      // The 17th: the first has nothing, the second and the third rest.
      final seventeenth = comparison.days[16];
      expect(seventeenth.workingIndexes, isEmpty);
      expect(seventeenth.freeIndexes, [1, 2]);
      expect(seventeenth.hasUnrecorded, isTrue);
      // The 24th: only the third one rests, the others have nothing.
      expect(comparison.days[23].freeIndexes, [2]);
      // No day is free in the three.
      expect(comparison.commonFreeCount, 0);
    });

    test('the same request gives the same comparison', () async {
      final container = makeContainer();
      final request = CompareRequest.month(
        calendars: const [_c1, _c2],
        month: _oct(1),
      );
      final first = await container.read(
        multiComparisonProvider(request).future,
      );
      final second = await container.read(
        multiComparisonProvider(request).future,
      );
      expect(first.days.length, second.days.length);
      expect(first.commonFreeDays, second.commonFreeDays);
    });

    test('it reads the days of the range, not only the month', () async {
      final container = makeContainer();
      final request = CompareRequest(
        calendars: const [_c1, _c2],
        from: const CivilDate(2026, 9, 28),
        to: const CivilDate(2026, 11, 4),
      );
      final comparison = await container.read(
        multiComparisonProvider(request).future,
      );
      expect(comparison.days, hasLength(38));
      expect(comparison.days.first.date, const CivilDate(2026, 9, 28));
      expect(comparison.days.last.date, const CivilDate(2026, 11, 4));
      final october = comparison.forMonth(_oct(1));
      expect(october.days, hasLength(31));
      expect(october.from, _oct(1));
      expect(october.to, _oct(31));
    });

    test('the days everybody is free are counted and listed', () async {
      final container = makeContainer();
      // The first calendar works the 3rd and the 10th and the second one
      // rests them, but neither of them has the 24th and the 25th: there is
      // no day free in the two.
      final request = CompareRequest.month(
        calendars: const [_c1, _c2],
        month: _oct(1),
      );
      final comparison = await container.read(
        multiComparisonProvider(request).future,
      );
      expect(comparison.commonFreeDays, isEmpty);
      expect(comparison.commonFreeCount, 0);
      expect(comparison.commonFreeWeekendCount, 0);
    });
  });
}
