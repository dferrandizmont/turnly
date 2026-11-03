import 'package:cuadrante/features/calendar_export/domain/device_calendar_api.dart';
import 'package:cuadrante/features/device_events/domain/device_event_month.dart';
import 'package:cuadrante/features/device_events/domain/device_events_permission.dart';
import 'package:cuadrante/features/device_events/domain/device_events_settings.dart';
import 'package:cuadrante/features/schedule/domain/civil_date.dart';
import 'package:flutter_test/flutter_test.dart';

/// An event of the phone, with sensible defaults.
DeviceEvent ev(
  String title,
  DateTime start,
  DateTime end, {
  String id = 'e',
  String calendarId = 'work',
  bool allDay = false,
  String? description,
  int? color,
}) => DeviceEvent(
  instanceId: id,
  calendarId: calendarId,
  title: title,
  description: description,
  start: start,
  end: end,
  allDay: allDay,
  colorValue: color,
);

DeviceCalendarInfo cal(String id, String name, {int? color}) =>
    DeviceCalendarInfo(id: id, name: name, colorValue: color);

String iso(List<CivilDate> days) => days.map((d) => d.toIso()).join(',');

void main() {
  group('eventDays', () {
    test('all-day: the end is exclusive at midnight (Android)', () {
      expect(
        iso(
          eventDays(
            ev(
              'Vacaciones',
              DateTime(2026, 10, 19),
              DateTime(2026, 10, 22),
              allDay: true,
            ),
          ),
        ),
        '2026-10-19,2026-10-20,2026-10-21',
      );
    });

    test('all-day: an end inside the last day still covers it (iOS)', () {
      expect(
        iso(
          eventDays(
            ev(
              'Vacaciones',
              DateTime(2026, 10, 19),
              DateTime(2026, 10, 21, 23, 59, 59),
              allDay: true,
            ),
          ),
        ),
        '2026-10-19,2026-10-20,2026-10-21',
      );
    });

    test('all-day with no length is one day', () {
      expect(
        iso(
          eventDays(
            ev(
              'X',
              DateTime(2026, 10, 19),
              DateTime(2026, 10, 19),
              allDay: true,
            ),
          ),
        ),
        '2026-10-19',
      );
    });

    test('a timed event inside one day is one day', () {
      expect(
        iso(
          eventDays(
            ev('Cena', DateTime(2026, 10, 19, 21), DateTime(2026, 10, 19, 22)),
          ),
        ),
        '2026-10-19',
      );
    });

    test('a timed event past midnight reaches the next day', () {
      expect(
        iso(
          eventDays(
            ev(
              'Guardia',
              DateTime(2026, 10, 19, 22),
              DateTime(2026, 10, 20, 6),
            ),
          ),
        ),
        '2026-10-19,2026-10-20',
      );
    });

    test('a timed event ending exactly at midnight does not', () {
      expect(
        iso(
          eventDays(
            ev('Fiesta', DateTime(2026, 10, 19, 20), DateTime(2026, 10, 20)),
          ),
        ),
        '2026-10-19',
      );
    });

    test('a zero-length timed event is one day', () {
      expect(
        iso(
          eventDays(
            ev('Aviso', DateTime(2026, 10, 19, 9), DateTime(2026, 10, 19, 9)),
          ),
        ),
        '2026-10-19',
      );
    });

    test('is clipped to the month asked for', () {
      final long = ev(
        'Excedencia',
        DateTime(2026, 9, 28),
        DateTime(2026, 11, 3),
        allDay: true,
      );
      const from = CivilDate(2026, 10, 1);
      const to = CivilDate(2026, 10, 31);
      expect(iso(eventDays(long, from: from, to: to)), iso(_range(from, to)));
    });
  });

  group('groupMonthEvents', () {
    final calendars = {
      'work': cal('work', 'Trabajo', color: 0xFF00FF00),
      'home': cal('home', 'Casa'),
    };

    test('puts the all-day events first and the timed ones in order', () {
      final month = groupMonthEvents(const CivilDate(2026, 10, 1), [
        ev('Cena', DateTime(2026, 10, 20, 21), DateTime(2026, 10, 20, 22)),
        ev(
          'Cumple',
          DateTime(2026, 10, 20),
          DateTime(2026, 10, 21),
          allDay: true,
        ),
        ev('Médico', DateTime(2026, 10, 20, 9), DateTime(2026, 10, 20, 10)),
      ], calendars);
      final day = month.day(const CivilDate(2026, 10, 20));
      expect(day.allDay.map((e) => e.title), ['Cumple']);
      expect(day.timed.map((e) => e.title), ['Médico', 'Cena']);
      expect(day.events.first.title, 'Cumple');
      expect(day.count, 3);
    });

    test('takes the calendar name and falls back to its colour', () {
      final month = groupMonthEvents(const CivilDate(2026, 10, 1), [
        ev('Cena', DateTime(2026, 10, 20, 21), DateTime(2026, 10, 20, 22)),
      ], calendars);
      final event = month.day(const CivilDate(2026, 10, 20)).timed.single;
      expect(event.calendarName, 'Trabajo');
      expect(event.colorValue, 0xFF00FF00);
    });

    test('the event colour wins over the calendar one', () {
      final month = groupMonthEvents(const CivilDate(2026, 10, 1), [
        ev(
          'Cena',
          DateTime(2026, 10, 20, 21),
          DateTime(2026, 10, 20, 22),
          color: 0xFFFF0000,
        ),
      ], calendars);
      expect(
        month.day(const CivilDate(2026, 10, 20)).timed.single.colorValue,
        0xFFFF0000,
      );
    });

    test('a continuation past the month is clipped but keeps its time', () {
      final month = groupMonthEvents(const CivilDate(2026, 10, 1), [
        ev('Guardia', DateTime(2026, 9, 30, 22), DateTime(2026, 10, 1, 6)),
      ], calendars);
      final first = month.day(const CivilDate(2026, 10, 1));
      expect(first.timed.single.title, 'Guardia');
      expect(month.days.containsKey(const CivilDate(2026, 9, 30)), isFalse);
      expect(month.isEmpty, isFalse);
    });

    test('a month with nothing is empty and any day answers empty', () {
      final month = groupMonthEvents(
        const CivilDate(2026, 10, 1),
        const [],
        calendars,
      );
      expect(month.isEmpty, isTrue);
      expect(month.day(const CivilDate(2026, 10, 15)).isEmpty, isTrue);
    });
  });

  group('deviceEventsPermissionOf', () {
    test('granted with and without calendars', () {
      expect(
        deviceEventsPermissionOf(CalendarAccess.granted, hasCalendars: true),
        DeviceEventsPermission.granted,
      );
      expect(
        deviceEventsPermissionOf(CalendarAccess.granted, hasCalendars: false),
        DeviceEventsPermission.noCalendars,
      );
    });

    test('not asked, denied, restricted and write-only', () {
      expect(
        deviceEventsPermissionOf(
          CalendarAccess.notDetermined,
          hasCalendars: false,
        ),
        DeviceEventsPermission.notAsked,
      );
      expect(
        deviceEventsPermissionOf(CalendarAccess.denied, hasCalendars: true),
        DeviceEventsPermission.denied,
      );
      expect(
        deviceEventsPermissionOf(CalendarAccess.restricted, hasCalendars: true),
        DeviceEventsPermission.restricted,
      );
      // «Add only» cannot read: it is a refusal for this feature.
      expect(
        deviceEventsPermissionOf(CalendarAccess.writeOnly, hasCalendars: true),
        DeviceEventsPermission.denied,
      );
    });
  });

  group('DeviceEventsSettings', () {
    test('makes the round trip through JSON', () {
      const settings = DeviceEventsSettings(calendarIds: ['3', 'home']);
      expect(DeviceEventsSettings.fromJson(settings.toJson()), settings);
      expect(settings.isOn, isTrue);
      expect(DeviceEventsSettings.none.isOn, isFalse);
    });

    test('anything unreadable reads as nothing chosen', () {
      expect(
        DeviceEventsSettings.fromJson({
          'calendarIds': ['3', 7, '', 'x'],
        }),
        const DeviceEventsSettings(calendarIds: ['3', 'x']),
      );
      expect(
        DeviceEventsSettings.fromJson({'calendarIds': 'todos'}),
        DeviceEventsSettings.none,
      );
    });

    test('drops repeated ids on the way in too', () {
      expect(
        DeviceEventsSettings.fromJson({
          'calendarIds': ['3', 'home', '3', '', 'home'],
        }),
        const DeviceEventsSettings(calendarIds: ['3', 'home']),
      );
    });
  });
}

/// Every day from [from] to [to], both included.
List<CivilDate> _range(CivilDate from, CivilDate to) => [
  for (var d = from; !d.isAfter(to); d = d.addDays(1)) d,
];
