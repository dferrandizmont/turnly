import 'package:cuadrante/core/format/app_date_format.dart';
import 'package:cuadrante/features/alarms/domain/alarm_planner.dart';
import 'package:cuadrante/features/alarms/domain/alarm_settings.dart';
import 'package:cuadrante/features/alarms/domain/alarm_strings.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// The texts of the notifications carry the times already written: 24 h or
/// 12 h as the person chose (Ajustes › Apariencia › Formato de hora).
String _title(String name, String start) => 'Turno de $name a las $start';
String _dayBeforeTitle(String name, String start) =>
    'Mañana: turno de $name a las $start';
String _body(String name, String start, String end) =>
    '$name: de $start a $end';

AlarmStrings _strings({String Function(int)? clock}) => AlarmStrings(
  title: _title,
  body: _body,
  channelName: 'Alarmas de turno',
  channelDescription: 'Descripción',
  dayBeforeTitle: _dayBeforeTitle,
  snoozeAction: 'Posponer 10 min',
  awakeAction: 'Ya estoy despierto',
  testTitle: 'Prueba',
  testBody: 'Cuerpo de prueba',
  reminderTitle: 'Recordatorio',
  reminderEmptyBody: 'Tienes un recordatorio para hoy',
  reminderChannelName: 'Recordatorios de notas',
  reminderChannelDescription: 'Descripción',
  clock: clock,
);

const _night = ShiftType(
  id: 'night',
  code: 'N',
  name: 'Noche',
  colorValue: 0xFF336699,
  category: ShiftCategory.work,
  startMinute: 22 * 60,
  endMinute: 6 * 60,
);

const _split = ShiftType(
  id: 'split',
  code: 'P',
  name: 'Partido',
  colorValue: 0xFF336699,
  category: ShiftCategory.work,
  startMinute: 9 * 60,
  endMinute: 13 * 60,
  segment2StartMinute: 17 * 60,
  segment2DurationMinutes: 4 * 60,
);

const _today = CivilDate(2026, 10, 19);

Schedule _schedule(String id) => Schedule(
  shiftTypes: [_night, _split],
  entries: {
    _today.addDays(1): DayEntry(date: _today.addDays(1), shiftTypeIds: [id]),
  },
);

List<PlannedAlarm> _plan(Schedule schedule, AlarmStrings strings) => planAlarms(
  schedule: schedule,
  settings: AlarmSettings(
    enabled: true,
    byShiftType: {
      for (final id in ['night', 'split'])
        id: const AlarmTypeSettings(
          enabled: true,
          minutesBefore: 60,
          dayBefore: true,
        ),
    },
  ),
  now: DateTime(2026, 10, 19, 12),
  strings: strings,
);

String _plain(String text) => text.replaceAll(' ', ' ');

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  group('AlarmStrings.time', () {
    test('without a clock: 24 h', () {
      final s = _strings();
      expect(s.time(22 * 60), '22:00');
      expect(s.time(6 * 60 + 5), '06:05');
      expect(s.time(1440), '00:00');
      expect(s.time(-60), '23:00');
    });

    test('with a clock: what it says, the minute wrapped into the day', () {
      final s = _strings(clock: (m) => 'm$m');
      expect(s.time(30), 'm30');
      expect(s.time(1500), 'm60');
    });

    test('alarmClock of an AppDateFormat', () {
      final h24 = alarmClock(const AppDateFormat('en_US'));
      final h12 = alarmClock(const AppDateFormat('en_US', true));
      expect(h24(22 * 60), '22:00');
      expect(_plain(h12(22 * 60)), '10:00 PM');
      expect(_plain(h12(6 * 60 + 30)), '6:30 AM');
      expect(_plain(h12(0)), '12:00 AM');
    });
  });

  group('the planned notifications', () {
    test('24 h: as before', () {
      final alarms = _plan(_schedule('night'), _strings());
      final shift = alarms.firstWhere((a) => a.kind == AlarmKind.shift);
      expect(shift.title, 'Turno de Noche a las 22:00');
      expect(shift.body, 'Noche: de 22:00 a 06:00');
      final before = alarms.firstWhere((a) => a.kind == AlarmKind.dayBefore);
      expect(before.title, 'Mañana: turno de Noche a las 22:00');
    });

    test('12 h: the start and the end in the title and the body', () {
      final alarms = _plan(
        _schedule('night'),
        _strings(clock: alarmClock(const AppDateFormat('en_US', true))),
      );
      final shift = alarms.firstWhere((a) => a.kind == AlarmKind.shift);
      expect(_plain(shift.title), 'Turno de Noche a las 10:00 PM');
      expect(_plain(shift.body), 'Noche: de 10:00 PM a 6:00 AM');
      final before = alarms.firstWhere((a) => a.kind == AlarmKind.dayBefore);
      expect(_plain(before.title), 'Mañana: turno de Noche a las 10:00 PM');
    });

    test('12 h: both segments of a split shift', () {
      final alarms = _plan(
        _schedule('split'),
        _strings(clock: alarmClock(const AppDateFormat('en_US', true))),
      );
      final texts = [
        for (final a in alarms)
          if (a.kind == AlarmKind.shift) _plain(a.body),
      ];
      expect(texts, [
        'Partido: de 9:00 AM a 1:00 PM',
        'Partido: de 5:00 PM a 9:00 PM',
      ]);
    });
  });
}
