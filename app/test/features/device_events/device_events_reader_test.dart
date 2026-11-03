import 'package:cuadrante/features/calendar_export/domain/device_calendar_api.dart';
import 'package:cuadrante/features/calendar_export/domain/export_events.dart';
import 'package:cuadrante/features/device_events/data/device_events_reader.dart';
import 'package:cuadrante/features/schedule/domain/civil_date.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_device_calendar.dart';

void main() {
  group('isTurnlyCalendar', () {
    test('is the calendar Turnly writes, by name', () {
      expect(
        isTurnlyCalendar(const DeviceCalendarInfo(id: '1', name: 'Turnly')),
        isTrue,
      );
      expect(
        isTurnlyCalendar(const DeviceCalendarInfo(id: '1', name: ' Turnly ')),
        isTrue,
      );
      expect(
        isTurnlyCalendar(const DeviceCalendarInfo(id: '1', name: 'Trabajo')),
        isFalse,
      );
    });
  });

  group('isTurnlyEvent', () {
    test('is an event that carries the Turnly tag', () {
      expect(
        isTurnlyEvent(
          DeviceEvent(
            instanceId: '1',
            calendarId: 'c',
            title: 'Mañana · M',
            description:
                '$exportMarkerLine\n'
                '${exportTag('main', const CivilDate(2026, 10, 19), 'm', 0)}',
            start: DateTime(2026, 10, 19, 6),
            end: DateTime(2026, 10, 19, 14),
          ),
        ),
        isTrue,
      );
      expect(
        isTurnlyEvent(
          DeviceEvent(
            instanceId: '2',
            calendarId: 'c',
            title: 'Dentista',
            start: DateTime(2026, 10, 19, 9),
            end: DateTime(2026, 10, 19, 10),
          ),
        ),
        isFalse,
      );
      // Text that merely quotes a tag is not ours.
      expect(
        isTurnlyEvent(
          DeviceEvent(
            instanceId: '3',
            calendarId: 'c',
            title: 'Nota',
            description:
                'mira\n'
                '${exportTag('main', const CivilDate(2026, 10, 19), 'm', 0)}',
            start: DateTime(2026, 10, 19, 9),
            end: DateTime(2026, 10, 19, 10),
          ),
        ),
        isFalse,
      );
    });
  });

  group('selectableCalendars', () {
    test('leaves out the Turnly calendar and the hidden ones', () async {
      final phone = FakeDeviceCalendar();
      phone.addCalendar('Turnly');
      phone.addCalendar('Oculto', hidden: true);
      final work = phone.addCalendar('Trabajo', readOnly: true);
      final home = phone.addCalendar('Casa');
      final list = await selectableCalendars(phone);
      expect(list.map((c) => c.id), [work, home]);
    });

    test('a phone with no calendars gives none', () async {
      expect(await selectableCalendars(FakeDeviceCalendar()), isEmpty);
    });
  });

  group('readDeviceEventMonth', () {
    test('reads the month asked for and needs a chosen calendar', () async {
      final phone = FakeDeviceCalendar();
      final work = phone.addCalendar('Trabajo');
      phone.addSimpleEvent(
        work,
        'Dentista',
        DateTime(2026, 10, 19, 9),
        DateTime(2026, 10, 19, 10),
      );
      final events = await readDeviceEventMonth(
        phone,
        calendarIds: [work],
        dayInMonth: const CivilDate(2026, 10, 15),
      );
      expect(events.map((e) => e.title), ['Dentista']);
      expect(phone.eventListings, 1);
    });

    test('nothing read with no calendar chosen', () async {
      final phone = FakeDeviceCalendar();
      phone.addCalendar('Trabajo');
      final events = await readDeviceEventMonth(
        phone,
        calendarIds: const [],
        dayInMonth: const CivilDate(2026, 10, 15),
      );
      expect(events, isEmpty);
      expect(phone.eventListings, 0);
    });

    test('drops cancelled events and the ones Turnly wrote', () async {
      final phone = FakeDeviceCalendar();
      final work = phone.addCalendar('Trabajo');
      phone.addSimpleEvent(
        work,
        'Dentista',
        DateTime(2026, 10, 19, 9),
        DateTime(2026, 10, 19, 10),
      );
      phone.addEvent(
        DeviceEvent(
          instanceId: 'x',
          calendarId: work,
          title: 'Cancelado',
          start: DateTime(2026, 10, 20, 9),
          end: DateTime(2026, 10, 20, 10),
          cancelled: true,
        ),
      );
      phone.addSimpleEvent(
        work,
        'Mañana · M',
        DateTime(2026, 10, 21, 6),
        DateTime(2026, 10, 21, 14),
        description:
            '$exportMarkerLine\n'
            '${exportTag('main', const CivilDate(2026, 10, 21), 'm', 0)}',
      );
      final events = await readDeviceEventMonth(
        phone,
        calendarIds: [work],
        dayInMonth: const CivilDate(2026, 10, 15),
      );
      expect(events.map((e) => e.title), ['Dentista']);
    });

    test('only the month: an event of the next one is left out', () async {
      final phone = FakeDeviceCalendar();
      final work = phone.addCalendar('Trabajo');
      phone.addSimpleEvent(
        work,
        'Noviembre',
        DateTime(2026, 11, 1, 9),
        DateTime(2026, 11, 1, 10),
      );
      final events = await readDeviceEventMonth(
        phone,
        calendarIds: [work],
        dayInMonth: const CivilDate(2026, 10, 15),
      );
      expect(events, isEmpty);
    });
  });
}
