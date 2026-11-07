import 'package:cuadrante/features/alarms/application/alarm_sync.dart';
import 'package:cuadrante/features/alarms/data/alarm_scheduler.dart';
import 'package:cuadrante/features/alarms/data/local_alarm_scheduler.dart';
import 'package:cuadrante/features/alarms/domain/alarm_planner.dart';
import 'package:cuadrante/features/alarms/domain/alarm_settings.dart';
import 'package:cuadrante/features/alarms/domain/alarm_strings.dart';
import 'package:cuadrante/features/alarms/domain/wall_clock.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;

const _strings = AlarmStrings(
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
  pauseTitle: 'Toca pausa',
  pauseChannelName: 'Avisos de pausa',
  pauseChannelDescription: 'Descripción de la pausa',
);

/// The texts of a build that knows nothing about the pause notice.
const _stringsWithoutPause = AlarmStrings(
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
);

String _title(String name, String start) => 'Turno de $name a las $start';
String _dayBeforeTitle(String name, String start) =>
    'Mañana: turno de $name a las $start';
String _body(String name, String start, String end) =>
    '$name: de $start a $end';

ShiftType _work(
  String id,
  String name,
  int startH,
  int endH, {
  String? sound,
  int startM = 0,
  int? segment2Start,
  int? segment2Duration,
}) => ShiftType(
  id: id,
  code: id.substring(0, 1).toUpperCase(),
  name: name,
  colorValue: 0xFF336699,
  category: ShiftCategory.work,
  startMinute: startH * 60 + startM,
  endMinute: endH * 60,
  alarmSound: sound,
  segment2StartMinute: segment2Start,
  segment2DurationMinutes: segment2Duration,
);

final _day = _work('day', 'Mañana', 6, 14, sound: 'content://media/internal/1');
final _night = _work('night', 'Noche', 22, 6);
final _short = _work('short', 'Corto', 9, 12);

/// 09:00-13:00 and 17:00-21:00: both segments last 4 h.
final _splitEqual = _work(
  'equal',
  'Partido',
  9,
  13,
  segment2Start: 17 * 60,
  segment2Duration: 240,
);

/// 08:00-11:00 and 15:00-20:00: the second segment is the long one.
final _splitSecondLong = _work(
  'second',
  'Largo2',
  8,
  11,
  segment2Start: 15 * 60,
  segment2Duration: 300,
);

/// 08:00-13:00 and 16:00-19:00: the first segment is the long one.
final _splitFirstLong = _work(
  'first',
  'Largo1',
  8,
  13,
  segment2Start: 16 * 60,
  segment2Duration: 180,
);

/// 20:00-23:00 and 01:00-07:00 of the next day: the long segment starts after
/// midnight.
final _splitAfterMidnight = _work(
  'late',
  'Nocturno',
  20,
  23,
  segment2Start: 60,
  segment2Duration: 360,
);

const _vacation = ShiftType(
  id: 'vac',
  code: 'V',
  name: 'Vacaciones',
  colorValue: 0xFFCC3333,
  category: ShiftCategory.absence,
);

const _today = CivilDate(2026, 10, 19);

final _types = [
  _day,
  _night,
  _short,
  _splitEqual,
  _splitSecondLong,
  _splitFirstLong,
  _splitAfterMidnight,
  _vacation,
];

Schedule _schedule(Map<CivilDate, List<String>> days) => Schedule(
  shiftTypes: _types,
  entries: {
    for (final e in days.entries)
      e.key: DayEntry(date: e.key, shiftTypeIds: e.value),
  },
);

AlarmTypeSettings _pause({
  PauseTiming timing = PauseTiming.midShift,
  int after = 240,
  bool alarm = false,
}) => AlarmTypeSettings(
  enabled: alarm,
  minutesBefore: 30,
  pause: PauseAlertSettings(enabled: true, timing: timing, afterMinutes: after),
);

AlarmSettings _settings(
  Map<String, AlarmTypeSettings> types, {
  bool enabled = true,
  Set<CivilDate> skipped = const {},
}) =>
    AlarmSettings(enabled: enabled, byShiftType: types, skippedDates: skipped);

late tz.Location _madrid;

List<PlannedAlarm> _plan(
  Schedule schedule,
  AlarmSettings settings, {
  DateTime? now,
  AlarmStrings strings = _strings,
}) => planAlarms(
  schedule: schedule,
  settings: settings,
  now: now ?? DateTime.utc(2026, 10, 19, 10),
  strings: strings,
  location: _madrid,
);

List<PlannedAlarm> _pauses(List<PlannedAlarm> alarms) =>
    alarms.where((a) => a.kind == AlarmKind.pause).toList();

String _at(PlannedAlarm a) =>
    '${a.fireDate.toIso()} '
    '${(a.fireMinute ~/ 60).toString().padLeft(2, '0')}:'
    '${(a.fireMinute % 60).toString().padLeft(2, '0')}';

DateTime _utc(PlannedAlarm a) => resolveAlarmInstant(a, _madrid).toUtc();

void main() {
  setUp(() => _madrid = defaultAlarmLocation());

  group('PauseAlertSettings', () {
    test('is off, halfway and 4 h by default', () {
      const pause = PauseAlertSettings();
      expect(pause.enabled, isFalse);
      expect(pause.timing, PauseTiming.midShift);
      expect(pause.afterMinutes, 240);
      expect(AlarmTypeSettings.off.pause, PauseAlertSettings.off);
    });

    test('round trips through JSON, with the type', () {
      const settings = AlarmSettings(
        enabled: true,
        byShiftType: {
          'a': AlarmTypeSettings(
            pause: PauseAlertSettings(
              enabled: true,
              timing: PauseTiming.afterStart,
              afterMinutes: 150,
            ),
          ),
          'b': AlarmTypeSettings(
            enabled: true,
            pause: PauseAlertSettings(enabled: true),
          ),
        },
      );
      expect(AlarmSettings.fromJson(settings.toJson()), settings);
      expect(
        AlarmSettings.fromJson(settings.toJson()).forShiftType('a').pause,
        const PauseAlertSettings(
          enabled: true,
          timing: PauseTiming.afterStart,
          afterMinutes: 150,
        ),
      );
    });

    test('a type that never touched it does not grow a key', () {
      expect(const AlarmTypeSettings(enabled: true).toJson().keys, [
        'enabled',
        'minutesBefore',
        'dayBefore',
        'dayBeforeMinute',
      ]);
    });

    test('reads tolerantly: wrong types fall back, the lead is clamped', () {
      expect(
        AlarmTypeSettings.fromJson({'pause': 'yes'}).pause,
        PauseAlertSettings.off,
      );
      final odd = AlarmTypeSettings.fromJson({
        'pause': {'enabled': 'yes', 'timing': 3, 'afterMinutes': 'x'},
      }).pause;
      expect(odd, PauseAlertSettings.off);
      expect(
        AlarmTypeSettings.fromJson({
          'pause': {'enabled': true, 'timing': 'after', 'afterMinutes': 99999},
        }).pause.afterMinutes,
        PauseAlertSettings.maxAfterMinutes,
      );
      expect(
        AlarmTypeSettings.fromJson({
          'pause': {'enabled': true, 'timing': 'after', 'afterMinutes': 1},
        }).pause.afterMinutes,
        PauseAlertSettings.minAfterMinutes,
      );
    });

    test('settings written before the pause notice read as off', () {
      final settings = AlarmSettings.fromJson({
        'version': 2,
        'enabled': true,
        'types': {
          'night': {'enabled': true, 'minutesBefore': 60},
        },
      });
      expect(settings.forShiftType('night').pause, PauseAlertSettings.off);
      expect(settings.forShiftType('night').enabled, isTrue);
    });

    test('a type with only the pause notice makes the alarms active', () {
      final only = _settings({'day': _pause()});
      expect(only.anyActive, isTrue);
      expect(only.forShiftType('day').enabled, isFalse);
      expect(only.forShiftType('day').anyEnabled, isTrue);
      expect(_settings({'day': _pause()}, enabled: false).anyActive, isFalse);
      expect(
        alarmsCanRing(only, [_day]),
        isTrue,
        reason: 'the row of Ajustes says Activadas',
      );
      expect(alarmsCanRing(only, [_vacation]), isFalse);
      expect(
        alarmsCanRing(_settings({'day': _pause()}, enabled: false), [_day]),
        isFalse,
      );
    });
  });

  group('moment of the notice', () {
    final tomorrow = _today.addDays(1);

    test('halfway through a day shift', () {
      final alarms = _pauses(
        _plan(
          _schedule({
            tomorrow: ['day'],
          }),
          _settings({'day': _pause()}),
        ),
      );
      expect(alarms, hasLength(1));
      final pause = alarms.single;
      expect(_at(pause), '2026-10-20 10:00');
      expect(pause.shiftDate, tomorrow);
      expect(pause.shiftTypeId, 'day');
      expect(pause.title, 'Toca pausa');
      expect(pause.body, 'Mañana: de 06:00 a 14:00');
      expect(pause.snoozeLabel, isNull, reason: 'no buttons');
      expect(pause.awakeLabel, isNull);
      expect(pause.sound, isNull, reason: 'a plain notification');
      expect(pause.segment, 0);
    });

    test('some time after the start', () {
      final alarms = _pauses(
        _plan(
          _schedule({
            tomorrow: ['day'],
          }),
          _settings({
            'day': _pause(timing: PauseTiming.afterStart, after: 150),
          }),
        ),
      );
      expect(_at(alarms.single), '2026-10-20 08:30');
    });

    test('a night shift that crosses midnight rings after midnight, on the '
        'day after the shift', () {
      final schedule = _schedule({
        tomorrow: ['night'],
      });
      final mid = _pauses(_plan(schedule, _settings({'night': _pause()})));
      expect(_at(mid.single), '2026-10-21 02:00');
      expect(mid.single.shiftDate, tomorrow);

      final after = _pauses(
        _plan(
          schedule,
          _settings({
            'night': _pause(timing: PauseTiming.afterStart, after: 300),
          }),
        ),
      );
      expect(_at(after.single), '2026-10-21 03:00');
      expect(after.single.shiftDate, tomorrow);

      // Before midnight is still the same day.
      final early = _pauses(
        _plan(
          schedule,
          _settings({
            'night': _pause(timing: PauseTiming.afterStart, after: 90),
          }),
        ),
      );
      expect(_at(early.single), '2026-10-20 23:30');
    });

    test('a time that does not fit inside the shift makes no notice', () {
      final schedule = _schedule({
        tomorrow: ['short'],
      });
      for (final after in [180, 240, 1000]) {
        expect(
          _pauses(
            _plan(
              schedule,
              _settings({
                'short': _pause(timing: PauseTiming.afterStart, after: after),
              }),
            ),
          ),
          isEmpty,
          reason: 'a 3 h shift has no minute $after after its start',
        );
      }
      expect(
        _at(
          _pauses(
            _plan(
              schedule,
              _settings({
                'short': _pause(timing: PauseTiming.afterStart, after: 179),
              }),
            ),
          ).single,
        ),
        '2026-10-20 11:59',
      );
    });

    test('is independent of the alarm before the shift', () {
      final schedule = _schedule({
        tomorrow: ['day'],
      });
      final pauseOnly = _plan(schedule, _settings({'day': _pause()}));
      expect(pauseOnly.map((a) => a.kind), [AlarmKind.pause]);

      final both = _plan(schedule, _settings({'day': _pause(alarm: true)}));
      expect(both.map((a) => a.kind), [AlarmKind.shift, AlarmKind.pause]);
      expect(both.map((a) => a.id).toSet(), hasLength(2));
      // The id is the same every time: replanning replaces, never duplicates.
      expect(
        _plan(
          schedule,
          _settings({'day': _pause(alarm: true)}),
        ).map((a) => a.id),
        both.map((a) => a.id),
      );
    });

    test('one notice per shift of the day', () {
      final alarms = _pauses(
        _plan(
          _schedule({
            tomorrow: ['day', 'night'],
          }),
          _settings({'day': _pause(), 'night': _pause()}),
        ),
      );
      expect(alarms.map(_at), ['2026-10-20 10:00', '2026-10-21 02:00']);
      expect(alarms.map((a) => a.id).toSet(), hasLength(2));
    });

    test('only the types that turned it on get one', () {
      final alarms = _plan(
        _schedule({
          tomorrow: ['day', 'night'],
        }),
        _settings({
          'day': _pause(),
          'night': const AlarmTypeSettings(enabled: true),
        }),
      );
      expect(
        alarms
            .where((a) => a.kind == AlarmKind.pause)
            .map((a) => a.shiftTypeId),
        ['day'],
      );
    });
  });

  group('split shifts', () {
    final tomorrow = _today.addDays(1);

    PlannedAlarm only(String id) {
      final pauses = _pauses(
        _plan(
          _schedule({
            tomorrow: [id],
          }),
          _settings({id: _pause()}),
        ),
      );
      expect(pauses, hasLength(1), reason: 'one notice per shift');
      return pauses.single;
    }

    test('goes in the long segment: the second one', () {
      final pause = only('second');
      // 15:00-20:00 -> halfway at 17:30.
      expect(_at(pause), '2026-10-20 17:30');
      expect(pause.segment, 1);
      expect(pause.body, 'Largo2: de 15:00 a 20:00');
    });

    test('goes in the long segment: the first one', () {
      final pause = only('first');
      // 08:00-13:00 -> halfway at 10:30.
      expect(_at(pause), '2026-10-20 10:30');
      expect(pause.segment, 0);
      expect(pause.body, 'Largo1: de 08:00 a 13:00');
    });

    test('with two segments of the same length the first one wins', () {
      final pause = only('equal');
      expect(_at(pause), '2026-10-20 11:00');
      expect(pause.segment, 0);
    });

    test('a long segment that starts after midnight', () {
      final pause = only('late');
      // 01:00-07:00 of the next day -> 04:00 of the next day.
      expect(_at(pause), '2026-10-21 04:00');
      expect(pause.shiftDate, tomorrow);
      expect(pause.segment, 1);
    });

    test('"after the start" counts from the start of that segment', () {
      final pauses = _pauses(
        _plan(
          _schedule({
            tomorrow: ['second'],
          }),
          _settings({
            'second': _pause(timing: PauseTiming.afterStart, after: 120),
          }),
        ),
      );
      expect(_at(pauses.single), '2026-10-20 17:00');
      // 5 h is the whole long segment: it does not fit.
      expect(
        _pauses(
          _plan(
            _schedule({
              tomorrow: ['second'],
            }),
            _settings({
              'second': _pause(timing: PauseTiming.afterStart, after: 300),
            }),
          ),
        ),
        isEmpty,
      );
    });

    test('the second-segment alarm switch does not touch the notice', () {
      final alarms = _plan(
        _schedule({
          tomorrow: ['second'],
        }),
        _settings({
          'second': const AlarmTypeSettings(
            enabled: true,
            secondSegment: false,
            pause: PauseAlertSettings(enabled: true),
          ),
        }),
      );
      expect(alarms.map((a) => a.kind), [AlarmKind.shift, AlarmKind.pause]);
    });
  });

  group('days without a notice', () {
    final tomorrow = _today.addDays(1);

    test('an absence on the day silences it', () {
      final settings = _settings({'day': _pause(), 'vac': _pause()});
      expect(
        _plan(
          _schedule({
            tomorrow: ['day', 'vac'],
          }),
          settings,
        ),
        isEmpty,
      );
      expect(
        _plan(
          _schedule({
            tomorrow: ['vac'],
          }),
          settings,
        ),
        isEmpty,
      );
      // The next day, without the absence, rings.
      final alarms = _plan(
        _schedule({
          tomorrow: ['day', 'vac'],
          tomorrow.addDays(1): ['day'],
        }),
        settings,
      );
      expect(alarms.map((a) => a.shiftDate), [tomorrow.addDays(1)]);
    });

    test('an absence silences only the pause notice, not the alarm before '
        'the shift', () {
      final alarms = _plan(
        _schedule({
          tomorrow: ['day', 'vac'],
        }),
        _settings({
          'day': _pause(alarm: true),
          'vac': const AlarmTypeSettings(enabled: true),
        }),
      );
      expect(alarms.map((a) => a.kind), [AlarmKind.shift]);
    });

    test('a shift taken off the day (override with nothing) has none', () {
      final schedule = Schedule(
        shiftTypes: _types,
        patterns: const [
          Pattern(
            id: 'p',
            name: 'Siempre mañana',
            steps: [
              ['day'],
            ],
          ),
        ],
        runs: [PatternRun(id: 'r', patternId: 'p', startDate: _today, seq: 1)],
        entries: {tomorrow: DayEntry(date: tomorrow, shiftTypeIds: const [])},
      );
      final alarms = _pauses(_plan(schedule, _settings({'day': _pause()})));
      expect(alarms.map((a) => a.shiftDate), isNot(contains(tomorrow)));
      expect(alarms.map((a) => a.shiftDate), contains(tomorrow.addDays(1)));
    });

    test('"Sin alarma este día" silences it', () {
      final schedule = _schedule({
        tomorrow: ['day'],
        tomorrow.addDays(1): ['day'],
      });
      final alarms = _plan(
        schedule,
        _settings({'day': _pause()}, skipped: {tomorrow}),
      );
      expect(alarms.map((a) => a.shiftDate), [tomorrow.addDays(1)]);
    });

    test('the global switch is needed', () {
      expect(
        _plan(
          _schedule({
            tomorrow: ['day'],
          }),
          _settings({'day': _pause()}, enabled: false),
        ),
        isEmpty,
      );
    });

    test('without the texts of the pause notice there is none', () {
      expect(
        _plan(
          _schedule({
            tomorrow: ['day'],
          }),
          _settings({'day': _pause()}),
          strings: _stringsWithoutPause,
        ),
        isEmpty,
      );
      expect(
        _plan(
          _schedule({
            tomorrow: ['day'],
          }),
          _settings({'day': _pause()}),
          strings: AlarmStrings.blank,
        ),
        isEmpty,
      );
    });

    test('a notice that already passed is not planned', () {
      final alarms = _pauses(
        _plan(
          _schedule({
            tomorrow: ['day'],
          }),
          _settings({'day': _pause()}),
          now: DateTime.utc(2026, 10, 20, 8), // 10:00 Madrid is now
        ),
      );
      expect(alarms, isEmpty);
    });

    test('beyond the horizon waits', () {
      final far = _today.addDays(40);
      expect(
        _pauses(
          _plan(
            _schedule({
              far: ['day'],
            }),
            _settings({'day': _pause()}),
          ),
        ),
        isEmpty,
      );
    });
  });

  group('"Próximo aviso" is about shifts', () {
    final schedule = _schedule({
      _today.addDays(1): ['day'],
    });

    test('a pause notice alone is not a next alarm', () {
      expect(
        nextAlarm(
          schedule: schedule,
          settings: _settings({'day': _pause()}),
          now: DateTime.utc(2026, 10, 19, 10),
          location: _madrid,
        ),
        isNull,
      );
    });

    test('with the alarm on, the alarm before the shift comes first', () {
      final next = nextAlarm(
        schedule: schedule,
        settings: _settings({'day': _pause(alarm: true)}),
        now: DateTime.utc(2026, 10, 19, 10),
        location: _madrid,
      );
      expect(next!.kind, AlarmKind.shift);
    });
  });

  group('daylight saving (Europe/Madrid)', () {
    // Wall-clock times, like every alarm: a moment that does not exist moves
    // forward, a repeated one is the first time.
    List<PlannedAlarm> pauses(
      String id,
      CivilDate date,
      AlarmTypeSettings settings,
      DateTime now,
    ) => _pauses(
      _plan(
        _schedule({
          date: [id],
        }),
        AlarmSettings(
          enabled: true,
          horizonDays: 30,
          byShiftType: {id: settings},
        ),
        now: now,
      ),
    );

    test('March: the night that loses an hour', () {
      final now = DateTime.utc(2026, 3, 20, 10);
      const date = CivilDate(2026, 3, 28); // 22:00-06:00, clocks go 02->03

      final mid = pauses('night', date, _pause(), now).single;
      expect(_at(mid), '2026-03-29 02:00');
      // 02:00 does not exist: it rings at 03:00 (01:00 UTC), never before.
      expect(_utc(mid), DateTime.utc(2026, 3, 29, 1));

      final before = pauses(
        'night',
        date,
        _pause(timing: PauseTiming.afterStart, after: 180),
        now,
      ).single;
      expect(_at(before), '2026-03-29 01:00');
      expect(_utc(before), DateTime.utc(2026, 3, 29));

      final after = pauses(
        'night',
        date,
        _pause(timing: PauseTiming.afterStart, after: 300),
        now,
      ).single;
      expect(_at(after), '2026-03-29 03:00');
      expect(_utc(after), DateTime.utc(2026, 3, 29, 1));
    });

    test('March: a day shift on the day the clocks change keeps its hour', () {
      final pause = pauses(
        'day',
        const CivilDate(2026, 3, 29),
        _pause(),
        DateTime.utc(2026, 3, 20, 10),
      ).single;
      expect(_at(pause), '2026-03-29 10:00');
      expect(_utc(pause), DateTime.utc(2026, 3, 29, 8));
    });

    test('October: the night that gains an hour', () {
      final now = DateTime.utc(2026, 10, 20, 10);
      // The 24th is in the future of a "now" in the 20th.
      const date = CivilDate(2026, 10, 24);

      final mid = pauses('night', date, _pause(), now).single;
      expect(_at(mid), '2026-10-25 02:00');
      // 02:00 happens twice: the first one (summer time, 00:00 UTC).
      expect(_utc(mid), DateTime.utc(2026, 10, 25));

      final half = pauses(
        'night',
        date,
        _pause(timing: PauseTiming.afterStart, after: 270),
        now,
      ).single;
      expect(_at(half), '2026-10-25 02:30');
      expect(_utc(half), DateTime.utc(2026, 10, 25, 0, 30));

      final late = pauses(
        'night',
        date,
        _pause(timing: PauseTiming.afterStart, after: 330),
        now,
      ).single;
      expect(_at(late), '2026-10-25 03:30');
      expect(_utc(late), DateTime.utc(2026, 10, 25, 2, 30));
    });

    test('a notice that the clock change pushes to the end of its shift is '
        'dropped', () {
      // 01:00-03:00 on 2026-03-29: halfway is 02:00, which rings at 03:00 =
      // the end of the shift.
      final gap = _work('gap', 'Hueco', 1, 3);
      final schedule = Schedule(
        shiftTypes: [gap],
        entries: {
          const CivilDate(2026, 3, 29): const DayEntry(
            date: CivilDate(2026, 3, 29),
            shiftTypeIds: ['gap'],
          ),
        },
      );
      expect(
        _pauses(
          _plan(
            schedule,
            _settings({'gap': _pause()}),
            now: DateTime.utc(2026, 3, 20, 10),
          ),
        ),
        isEmpty,
      );
    });
  });

  group('payload', () {
    test('the pause notice travels as a kind of its own', () {
      final alarm = _pauses(
        _plan(
          _schedule({
            _today.addDays(1): ['day'],
          }),
          _settings({'day': _pause()}),
        ),
      ).single;
      expect(alarm.payload, startsWith(alarmPayloadPrefix));
      final decoded = AlarmPayload.decode(alarm.payload)!;
      expect(decoded.kind, AlarmKind.pause);
      expect(decoded.title, 'Toca pausa');
      expect(decoded.snoozeLabel, isNull);
      expect(decoded.sound, isNull);
    });
  });

  group('AlarmSync keeps the notice in line with the settings', () {
    final schedule = _schedule({
      _today.addDays(1): ['day'],
      _today.addDays(2): ['day', 'vac'],
      _today.addDays(3): ['day'],
    });

    test('schedules it, skips the absence day and cancels it when turned '
        'off', () async {
      var settings = _settings({'day': _pause()});
      final scheduler = FakeAlarmScheduler();
      final sync = AlarmSync(
        scheduler: scheduler,
        loadSettings: () async => settings,
        readSchedule: () => schedule,
        now: () => DateTime.utc(2026, 10, 19, 10),
        strings: _strings,
      );
      addTearDown(sync.dispose);

      await sync.resync();
      expect(scheduler.scheduled.map((a) => a.kind).toSet(), {AlarmKind.pause});
      expect(scheduler.scheduled.map((a) => a.shiftDate), [
        _today.addDays(1),
        _today.addDays(3),
      ]);

      // Same input, same ids: no duplicates.
      final ids = scheduler.scheduled.map((a) => a.id).toList();
      await sync.resync();
      expect(scheduler.scheduled.map((a) => a.id), ids);

      // The user turns it off: the next pass leaves nothing to ring.
      settings = _settings({'day': const AlarmTypeSettings()});
      await sync.resync();
      expect(scheduler.scheduled, isEmpty);

      // Back on, then the whole alarm switch off: also gone.
      settings = _settings({'day': _pause()});
      await sync.resync();
      expect(scheduler.scheduled, hasLength(2));
      settings = _settings({'day': _pause()}, enabled: false);
      await sync.resync();
      expect(scheduler.scheduled, isEmpty);
    });

    test('a change of shifts moves it', () async {
      var current = schedule;
      final scheduler = FakeAlarmScheduler();
      final sync = AlarmSync(
        scheduler: scheduler,
        loadSettings: () async => _settings({'day': _pause()}),
        readSchedule: () => current,
        now: () => DateTime.utc(2026, 10, 19, 10),
        strings: _strings,
      );
      addTearDown(sync.dispose);
      await sync.resync();
      expect(scheduler.scheduled, hasLength(2));

      current = _schedule({
        _today.addDays(1): ['night'],
      });
      await sync.resync();
      expect(scheduler.scheduled, isEmpty, reason: 'night has no notice');

      current = _schedule({
        _today.addDays(1): ['day', 'vac'],
      });
      await sync.resync();
      expect(scheduler.scheduled, isEmpty, reason: 'an absence arrived');
    });

    test('without the permission nothing is scheduled', () async {
      final scheduler = FakeAlarmScheduler(permission: AlarmPermission.denied);
      final sync = AlarmSync(
        scheduler: scheduler,
        loadSettings: () async => _settings({'day': _pause()}),
        readSchedule: () => schedule,
        now: () => DateTime.utc(2026, 10, 19, 10),
        strings: _strings,
      );
      addTearDown(sync.dispose);
      await sync.resync();
      expect(scheduler.scheduled, isEmpty);
    });
  });

  group('LocalAlarmScheduler and the time zone', () {
    test('every pass reads the zone again: the same wall-clock notice rings '
        'at the new local time', () async {
      var zone = 'Europe/Madrid';
      final plugin = _Plugin();
      final scheduler = LocalAlarmScheduler(
        plugin: plugin,
        localZone: () async => zone,
      );
      final alarm = _pauses(
        _plan(
          _schedule({
            _today.addDays(1): ['day'],
          }),
          _settings({'day': _pause()}),
        ),
      ).single;

      await scheduler.replaceAll([alarm]);
      zone = 'Atlantic/Canary'; // the user travels, the process lives on
      await scheduler.replaceAll([alarm]);

      // 10:00 on 2026-10-20: CEST (UTC+2) in Madrid, WEST (UTC+1) in Canarias.
      expect(plugin.scheduled, hasLength(2));
      expect(plugin.scheduled[0].toUtc(), DateTime.utc(2026, 10, 20, 8));
      expect(plugin.scheduled[1].toUtc(), DateTime.utc(2026, 10, 20, 9));
    });
  });
}

class _Plugin implements FlutterLocalNotificationsPlugin {
  final scheduled = <tz.TZDateTime>[];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    switch (invocation.memberName) {
      case #initialize:
        return Future<bool?>.value(true);
      case #zonedSchedule:
        scheduled.add(
          invocation.namedArguments[#scheduledDate] as tz.TZDateTime,
        );
        return Future<void>.value();
      case #pendingNotificationRequests:
        return Future<List<PendingNotificationRequest>>.value(const []);
      case #resolvePlatformSpecificImplementation:
        return null;
    }
    return super.noSuchMethod(invocation);
  }
}
