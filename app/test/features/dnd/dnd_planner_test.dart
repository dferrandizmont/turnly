import 'package:cuadrante/features/alarms/domain/alarm_settings.dart';
import 'package:cuadrante/features/dnd/domain/dnd_planner.dart';
import 'package:cuadrante/features/dnd/domain/dnd_settings.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

ShiftType _type(
  String id,
  String name,
  int startH,
  int endH, {
  ShiftCategory category = ShiftCategory.work,
}) => ShiftType(
  id: id,
  code: id.substring(0, 1).toUpperCase(),
  name: name,
  colorValue: 0xFF336699,
  category: category,
  startMinute: startH * 60,
  endMinute: endH * 60,
);

final _morning = _type('morning', 'Mañana', 6, 14);
final _night = _type('night', 'Noche', 22, 6);
final _absence = _type('absence', 'Vacaciones', 8, 16,
    category: ShiftCategory.absence);

/// A day off: no schedule at all.
final _rest = ShiftType(
  id: 'rest',
  code: 'L',
  name: 'Libre',
  colorValue: 0xFFCCCCCC,
  category: ShiftCategory.rest,
);

/// A split shift («turno partido»): 08:00-12:00 and 16:00-20:00.
final _split = ShiftType(
  id: 'split',
  code: 'P',
  name: 'Partido',
  colorValue: 0xFF336699,
  category: ShiftCategory.work,
  startMinute: 8 * 60,
  endMinute: 12 * 60,
  segment2StartMinute: 16 * 60,
  segment2DurationMinutes: 4 * 60,
);

const _today = CivilDate(2026, 10, 19);

/// Every day listed gets exactly the given shift types (as overrides).
Schedule _schedule(Map<CivilDate, List<String>> days) => Schedule(
  shiftTypes: [_morning, _night, _absence, _rest, _split],
  entries: {
    for (final e in days.entries)
      e.key: DayEntry(date: e.key, shiftTypeIds: e.value),
  },
);

/// The silence is on for the given shift types.
DndSettings _on(List<String> ids, {DndFilter filter = DndFilter.priority}) =>
    DndSettings(
      enabled: true,
      filter: filter,
      byShiftType: {
        for (final id in ids) id: const DndTypeSettings(enabled: true),
      },
    );

void main() {
  late tz.Location madrid;

  setUpAll(() {
    tzdata.initializeTimeZones();
    madrid = tz.getLocation('Europe/Madrid');
  });

  tz.TZDateTime at(int y, int m, int d, int h, [int min = 0]) =>
      tz.TZDateTime(madrid, y, m, d, h, min);

  /// The plan of [days] with the silence on for [ids].
  List<DndWindow> plan(
    Map<CivilDate, List<String>> days,
    List<String> ids, {
    DateTime? now,
    DndFilter filter = DndFilter.priority,
    int horizonDays = dndHorizonDays,
  }) => planDndWindows(
    schedule: _schedule(days),
    settings: _on(ids, filter: filter),
    now: now ?? at(2026, 10, 19, 12),
    location: madrid,
    horizonDays: horizonDays,
  );

  group('a normal shift', () {
    test('gives one window, from the start to the end', () {
      final windows = plan({_today: ['morning']}, ['morning']);
      expect(windows, hasLength(1));
      final window = windows.single;
      expect(window.start, at(2026, 10, 19, 6));
      expect(window.end, at(2026, 10, 19, 14));
      expect(window.duration, const Duration(hours: 8));
      expect(window.shiftTypeIds, ['morning']);
      expect(window.filter, DndFilter.priority);
    });

    test('the window is not active before it starts nor after it ends', () {
      final window = plan({_today: ['morning']}, ['morning']).single;
      expect(window.isActiveAt(at(2026, 10, 19, 5, 59)), isFalse);
      expect(window.isActiveAt(at(2026, 10, 19, 6)), isTrue);
      expect(window.isActiveAt(at(2026, 10, 19, 13, 59)), isTrue);
      expect(window.isActiveAt(at(2026, 10, 19, 14)), isFalse);
    });

    test('the filter of the settings is the one of the window', () {
      final windows = plan(
        {_today: ['morning']},
        ['morning'],
        filter: DndFilter.none,
      );
      expect(windows.single.filter, DndFilter.none);
    });
  });

  group('a night shift', () {
    test('crossing midnight ends the next day', () {
      final windows = plan({_today: ['night']}, ['night']);
      expect(windows, hasLength(1));
      expect(windows.single.start, at(2026, 10, 19, 22));
      expect(windows.single.end, at(2026, 10, 20, 6));
      expect(windows.single.duration, const Duration(hours: 8));
    });

    test('that started yesterday and is still running is planned', () {
      // It is 02:00 of the 20th: the night of the 19th is still going.
      final windows = plan(
        {_today: ['night']},
        ['night'],
        now: at(2026, 10, 20, 2),
      );
      expect(windows, hasLength(1));
      final window = windows.single;
      expect(window.start, at(2026, 10, 19, 22));
      expect(window.end, at(2026, 10, 20, 6));
      // It is running: the device silences the phone at once.
      expect(window.isActiveAt(at(2026, 10, 20, 2)), isTrue);
    });

    test('that already ended is not planned', () {
      final windows = plan(
        {_today: ['night']},
        ['night'],
        now: at(2026, 10, 20, 7),
      );
      expect(windows, isEmpty);
    });
  });

  group('a split shift', () {
    test('gives two windows: the break is not silenced', () {
      final windows = plan(
        {_today: ['split']},
        ['split'],
        now: at(2026, 10, 19, 7),
      );
      expect(windows, hasLength(2));
      expect(windows[0].start, at(2026, 10, 19, 8));
      expect(windows[0].end, at(2026, 10, 19, 12));
      expect(windows[1].start, at(2026, 10, 19, 16));
      expect(windows[1].end, at(2026, 10, 19, 20));
      // They do not touch: the phone is freed between them.
      expect(windows[0].end.isBefore(windows[1].start), isTrue);
    });

    test('the two segments have their own ids', () {
      final windows = plan(
        {_today: ['split']},
        ['split'],
        now: at(2026, 10, 19, 7),
      );
      expect(windows[0].id, isNot(windows[1].id));
    });
  });

  group('overlapping shifts', () {
    test('are merged into one window', () {
      // The morning ends at 14:00 and the night starts at 22:00: they do
      // not overlap, so there are two windows.
      final apart = plan({_today: ['morning', 'night']}, ['morning', 'night']);
      expect(apart, hasLength(2));

      // Two shifts that touch are one window: the phone is freed once.
      final touching = ShiftType(
        id: 't',
        code: 'T',
        name: 'Tarde',
        colorValue: 0xFF336699,
        category: ShiftCategory.work,
        startMinute: 13 * 60,
        endMinute: 15 * 60,
      );
      final windows = planDndWindows(
        schedule: Schedule(
          shiftTypes: [_morning, touching],
          entries: {
            _today: DayEntry(date: _today, shiftTypeIds: ['morning', 't']),
          },
        ),
        settings: _on(['morning', 't']),
        now: at(2026, 10, 19, 0),
        location: madrid,
      );
      expect(windows, hasLength(1));
      expect(windows.single.start, at(2026, 10, 19, 6));
      expect(windows.single.end, at(2026, 10, 19, 15));
      expect(windows.single.shiftTypeIds, containsAll(['morning', 't']));
    });
  });

  group('what is never silenced', () {
    test('an absence (vacation, sick leave) does not silence the phone', () {
      expect(plan({_today: ['absence']}, ['absence']), isEmpty);
    });

    test('a day off does not silence the phone', () {
      expect(plan({_today: ['rest']}, ['rest']), isEmpty);
    });

    test('a shift type without the silence on does not silence it', () {
      expect(plan({_today: ['morning']}, ['night']), isEmpty);
    });

    test('the global switch off silences nothing', () {
      final windows = planDndWindows(
        schedule: _schedule({_today: ['morning']}),
        settings: const DndSettings(
          byShiftType: {'morning': DndTypeSettings(enabled: true)},
        ),
        now: at(2026, 10, 19, 12),
        location: madrid,
      );
      expect(windows, isEmpty);
    });

    test('a shift type with no schedule is skipped', () {
      final noTimes = ShiftType(
        id: 'nt',
        code: 'N',
        name: 'Sin horas',
        colorValue: 0xFF336699,
        category: ShiftCategory.work,
      );
      final windows = planDndWindows(
        schedule: Schedule(
          shiftTypes: [noTimes],
          entries: {
            _today: DayEntry(date: _today, shiftTypeIds: ['nt']),
          },
        ),
        settings: _on(['nt']),
        now: at(2026, 10, 19, 12),
        location: madrid,
      );
      expect(windows, isEmpty);
    });
  });

  group('the weekend', () {
    // 2026-10-19 is a Monday, so these two are the weekend before it.
    final saturday = _today.addDays(-2);
    final sunday = _today.addDays(-1);

    test('a shift on a Saturday silences like any other day', () {
      final windows = plan(
        {saturday: ['morning']},
        ['morning'],
        now: at(2026, 10, 17, 0),
      );
      expect(windows, hasLength(1));
      expect(windows.single.start, at(2026, 10, 17, 6));
      expect(windows.single.end, at(2026, 10, 17, 14));
    });

    test('a shift on a Sunday silences like any other day', () {
      final windows = plan(
        {sunday: ['morning']},
        ['morning'],
        now: at(2026, 10, 18, 0),
      );
      expect(windows, hasLength(1));
      expect(windows.single.start, at(2026, 10, 18, 6));
      expect(windows.single.end, at(2026, 10, 18, 14));
    });

    test('a free weekend silences nothing', () {
      expect(
        plan(
          {saturday: ['rest'], sunday: ['rest']},
          ['rest'],
          now: at(2026, 10, 17, 0),
        ),
        isEmpty,
      );
    });
  });

  group('the horizon', () {
    test('is the one of the shift alarms', () {
      expect(dndHorizonDays, AlarmSettings.defaultHorizonDays);
    });

    test('a shift inside it is planned and one past it is not', () {
      final inside = plan({_today.addDays(dndHorizonDays): ['morning']}, [
        'morning',
      ]);
      expect(inside, hasLength(1));
      final outside = plan({_today.addDays(dndHorizonDays + 1): ['morning']}, [
        'morning',
      ]);
      expect(outside, isEmpty);
    });

    test('can be shortened', () {
      final windows = plan({_today.addDays(3): ['morning']}, ['morning'],
          horizonDays: 2);
      expect(windows, isEmpty);
    });
  });

  group('the daylight-saving hour', () {
    test('a shift of the day the clocks change keeps its wall-clock hour', () {
      // 2026-03-29: 02:00 -> 03:00. A shift that starts at 02:30 starts at
      // 03:30 (the time that does not exist moves forward by the gap).
      const day = CivilDate(2026, 3, 29);
      final windows = planDndWindows(
        schedule: Schedule(
          shiftTypes: [
            ShiftType(
              id: 'gap',
              code: 'G',
              name: 'Madrugada',
              colorValue: 0xFF336699,
              category: ShiftCategory.work,
              startMinute: 2 * 60 + 30,
              endMinute: 6 * 60,
            ),
          ],
          entries: {
            day: DayEntry(date: day, shiftTypeIds: ['gap']),
          },
        ),
        settings: _on(['gap']),
        now: at(2026, 3, 28, 12),
        location: madrid,
      );
      expect(windows, hasLength(1));
      expect(windows.single.start.hour, 3);
      expect(windows.single.start.minute, 30);
      expect(windows.single.end.hour, 6);
    });
  });

  group('the ids', () {
    test('are the same when the plan is made twice', () {
      final first = plan({_today: ['morning', 'night']}, ['morning', 'night']);
      final second = plan({_today: ['morning', 'night']}, ['morning', 'night']);
      expect(
        first.map((w) => w.id).toList(),
        second.map((w) => w.id).toList(),
      );
    });

    test('are different for different windows', () {
      final windows = plan({_today: ['morning', 'night']}, ['morning', 'night']);
      expect(windows[0].id, isNot(windows[1].id));
    });

    test('depend on the instant, not on the zone', () {
      // The same instant, written in two zones: the same id (Madrid is two
      // hours ahead of UTC on that day).
      final madridId = dndWindowId(at(2026, 10, 19, 22));
      final utcId = dndWindowId(tz.TZDateTime.utc(2026, 10, 19, 20));
      expect(utcId, madridId);
      // Another instant: another id.
      expect(
        dndWindowId(tz.TZDateTime.utc(2026, 10, 19, 21)),
        isNot(madridId),
      );
    });
  });
}
