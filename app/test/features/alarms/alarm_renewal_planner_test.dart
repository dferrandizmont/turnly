import 'package:cuadrante/features/alarms/domain/alarm_planner.dart';
import 'package:cuadrante/features/alarms/domain/alarm_settings.dart';
import 'package:cuadrante/features/alarms/domain/alarm_strings.dart';
import 'package:cuadrante/features/alarms/domain/wall_clock.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;

// A1: the plan says whether it was cut (horizon or cap), how far the shift
// alarms reach and, when cut, plans the renewal notice the evening before
// the last alarm.

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
  renewalTitle: 'Avisos de turno',
  renewalBody: _renewalBody,
);

/// The same texts without the renewal ones (as every older test fixture).
const _stringsWithoutRenewal = AlarmStrings(
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
String _renewalBody(CivilDate day) => 'Hasta el ${day.toIso()}';

ShiftType _type(String id, int startH, int endH) => ShiftType(
  id: id,
  code: id.substring(0, 1).toUpperCase(),
  name: id,
  colorValue: 0xFF336699,
  category: ShiftCategory.work,
  startMinute: startH * 60,
  endMinute: endH * 60,
);

final _night = _type('night', 22, 6);
final _morning = _type('morning', 6, 14);

const _today = CivilDate(2026, 10, 19);
final _noon = DateTime(2026, 10, 19, 12);

/// [ids] every day from [from] to [to] (days after [start], inclusive).
Schedule _daily(
  List<String> ids, {
  CivilDate start = _today,
  int from = 0,
  required int to,
  Map<CivilDate, DayEntry> extra = const {},
}) => Schedule(
  shiftTypes: [_night, _morning],
  entries: {
    for (var i = from; i <= to; i++)
      start.addDays(i): DayEntry(date: start.addDays(i), shiftTypeIds: ids),
    ...extra,
  },
);

AlarmSettings _on(
  List<String> ids, {
  int horizon = 14,
  bool dayBefore = false,
}) => AlarmSettings(
  enabled: true,
  horizonDays: horizon,
  byShiftType: {
    for (final id in ids)
      id: AlarmTypeSettings(enabled: true, dayBefore: dayBefore),
  },
);

AlarmPlan _plan(
  Schedule schedule,
  AlarmSettings settings, {
  DateTime? now,
  AlarmStrings strings = _strings,
}) => planAlarmSchedule(
  schedule: schedule,
  settings: settings,
  now: now ?? _noon,
  strings: strings,
);

tz.TZDateTime _instant(PlannedAlarm alarm) =>
    resolveAlarmInstant(alarm, defaultAlarmLocation());

void main() {
  group('cut by the horizon', () {
    test('a rotation past the horizon is cut and gets the notice at 20:00 '
        'the day before the last alarm', () {
      final plan = _plan(_daily(['night'], to: 60), _on(['night']));
      // Nights at 22:00 ring at 20:30; the window ends day 14 at 12:00, so
      // the last one is the night of day 13.
      expect(plan.truncated, isTrue);
      final last = plan.alarms.last;
      expect(last.shiftDate, _today.addDays(13));
      expect(plan.lastShiftAlarm, last);
      expect(plan.coveredUntil, _instant(last));

      final renewal = plan.renewal!;
      expect(renewal.kind, AlarmKind.renewal);
      expect(renewal.fireDate, _today.addDays(12));
      expect(renewal.fireMinute, 20 * 60);
      expect(renewal.shiftDate, _today.addDays(13));
      expect(renewal.shiftTypeId, '');
      expect(renewal.title, 'Avisos de turno');
      expect(renewal.body, 'Hasta el 2026-11-01');
      expect(renewal.snoozeLabel, isNull, reason: 'no buttons');
      expect(renewal.id, renewalNoticeId);
      expect(plan.toSchedule, [...plan.alarms, renewal]);
      expect(
        plan.alarms.map((a) => a.id),
        isNot(contains(renewal.id)),
        reason: 'it never replaces an alarm',
      );
    });

    test('the alarms are exactly those of planAlarms', () {
      final schedule = _daily(['night'], to: 60);
      final settings = _on(['night'], dayBefore: true);
      expect(
        _plan(schedule, settings).alarms,
        planAlarms(
          schedule: schedule,
          settings: settings,
          now: _noon,
          strings: _strings,
        ),
      );
    });

    test('no shift past the horizon: not cut, no notice', () {
      final plan = _plan(_daily(['night'], to: 5), _on(['night']));
      expect(plan.truncated, isFalse);
      expect(plan.renewal, isNull);
      expect(plan.alarms, hasLength(6));
      expect(plan.coveredUntil, _instant(plan.alarms.last));
      expect(plan.toSchedule, plan.alarms);
    });

    test('a shift more than the lookahead past the horizon does not count', () {
      final far = _today.addDays(14 + 1 + renewalLookaheadDays + 3);
      final plan = _plan(
        _daily(
          ['night'],
          to: 3,
          extra: {
            far: DayEntry(date: far, shiftTypeIds: const ['night']),
          },
        ),
        _on(['night']),
      );
      expect(plan.truncated, isFalse);
      expect(plan.renewal, isNull);
    });

    test('a long holiday: nothing in the window, shifts after it, the notice '
        'goes on the eve of the end of the horizon', () {
      final plan = _plan(_daily(['night'], from: 20, to: 40), _on(['night']));
      expect(plan.alarms, isEmpty);
      expect(plan.truncated, isTrue);
      expect(plan.coveredUntil, isNull);
      expect(plan.lastShiftAlarm, isNull);
      final renewal = plan.renewal!;
      expect(renewal.shiftDate, _today.addDays(14));
      expect(renewal.fireDate, _today.addDays(13));
      expect(renewal.fireMinute, 20 * 60);
    });
  });

  group('cut by the cap', () {
    test(
      'more than $maxPendingAlarms alarms in the window: cut, the notice '
      'before the last kept one, dodging the 20:00 evening-before notice',
      () {
        // Morning (04:30) and night (20:30) every day, both with the
        // evening-before notice at 20:00: four alarms a day, the 60 run out on
        // day 15 although the horizon (30) reaches past the last shift (25).
        final plan = _plan(
          _daily(['morning', 'night'], to: 25),
          _on(['morning', 'night'], horizon: 30, dayBefore: true),
        );
        expect(plan.alarms, hasLength(maxPendingAlarms));
        expect(plan.truncated, isTrue);
        final last = plan.lastShiftAlarm!;
        expect(last, plan.alarms.last);
        final renewal = plan.renewal!;
        expect(renewal.fireDate, last.fireDate.addDays(-1));
        // 20:00 is taken by the evening-before notices: 19:30 is the nearest
        // free half hour.
        expect(renewal.fireMinute, 19 * 60 + 30);
        expect(_instant(renewal).isBefore(_instant(last)), isTrue);
      },
    );
  });

  group('the renewal notice', () {
    test('never in the past: the nearest valid half hour after now', () {
      // Horizon of a day, mornings ring at 04:30: the last alarm is
      // tomorrow 04:30, and at 21:00 the evening slots up to 21:00 are gone.
      final plan = _plan(
        _daily(['morning'], to: 10),
        _on(['morning'], horizon: 1),
        now: DateTime(2026, 10, 19, 21),
      );
      expect(plan.alarms.single.fireDate, _today.addDays(1));
      final renewal = plan.renewal!;
      expect(renewal.fireDate, _today);
      expect(renewal.fireMinute, 21 * 60 + 30);
    });

    test('no notice when no evening slot is left', () {
      final plan = _plan(
        _daily(['morning'], to: 10),
        _on(['morning'], horizon: 1),
        now: DateTime(2026, 10, 19, 23, 10),
      );
      expect(plan.truncated, isTrue);
      expect(plan.alarms, isNotEmpty);
      expect(plan.renewal, isNull);
    });

    test('it keeps $renewalNoticeClearance away from a reminder', () {
      final eve = _today.addDays(12);
      final plan = _plan(
        _daily(
          ['night'],
          to: 60,
          extra: {
            eve: DayEntry(
              date: eve,
              shiftTypeIds: const ['night'],
              note: 'Llamar',
              noteReminderMinute: 20 * 60 + 5,
            ),
          },
        ),
        _on(['night']),
      );
      expect(plan.renewal!.fireDate, eve);
      expect(plan.renewal!.fireMinute, 19 * 60 + 30);
    });

    test('not when the shift alarms are off, even if reminders are cut', () {
      final far = _today.addDays(40);
      final plan = _plan(
        Schedule(
          shiftTypes: [_night],
          entries: {
            for (final d in [_today.addDays(2), far])
              d: DayEntry(date: d, noteReminderMinute: 9 * 60),
          },
        ),
        AlarmSettings.disabled,
      );
      expect(plan.alarms, hasLength(1));
      expect(plan.truncated, isFalse);
      expect(plan.renewal, isNull);
      expect(plan.coveredUntil, isNull, reason: 'reminders are not shifts');
    });

    test('not with texts that have no renewal strings', () {
      final plan = _plan(
        _daily(['night'], to: 60),
        _on(['night']),
        strings: _stringsWithoutRenewal,
      );
      expect(plan.truncated, isTrue);
      expect(plan.renewal, isNull);
    });

    test('a body that throws costs the notice, never the alarms', () {
      final plan = _plan(
        _daily(['night'], to: 60),
        _on(['night']),
        strings: const AlarmStrings(
          title: _title,
          body: _body,
          channelName: '',
          channelDescription: '',
          dayBeforeTitle: _dayBeforeTitle,
          snoozeAction: '',
          awakeAction: '',
          testTitle: '',
          testBody: '',
          reminderTitle: '',
          reminderEmptyBody: '',
          reminderChannelName: '',
          reminderChannelDescription: '',
          renewalTitle: 'Avisos',
          renewalBody: _throwingBody,
        ),
      );
      expect(plan.alarms, isNotEmpty);
      expect(plan.renewal, isNull);
    });

    test('the same input plans the same notice (no duplicates on resync)', () {
      final schedule = _daily(['night'], to: 60);
      final a = _plan(schedule, _on(['night']));
      final b = _plan(schedule, _on(['night']));
      expect(a.toSchedule, b.toSchedule);
    });
  });

  group('daylight saving (Europe/Madrid)', () {
    test('autumn: 20:00 local on 25 October is 19:00 UTC', () {
      // Mornings ring at 04:30; the window ends on 26 October at 12:00, so
      // the last alarm is 26 October 04:30 and the notice is the 25th.
      final plan = _plan(
        _daily(['morning'], start: const CivilDate(2026, 10, 12), to: 40),
        _on(['morning']),
        now: DateTime(2026, 10, 12, 12),
      );
      expect(plan.alarms.last.fireDate, const CivilDate(2026, 10, 26));
      final renewal = plan.renewal!;
      expect(renewal.fireDate, const CivilDate(2026, 10, 25));
      expect(renewal.fireMinute, 20 * 60);
      expect(_instant(renewal).toUtc(), DateTime.utc(2026, 10, 25, 19));
    });

    test('spring: 20:00 local on 29 March is 18:00 UTC', () {
      final plan = _plan(
        _daily(['morning'], start: const CivilDate(2026, 3, 16), to: 40),
        _on(['morning']),
        now: DateTime(2026, 3, 16, 12),
      );
      expect(plan.alarms.last.fireDate, const CivilDate(2026, 3, 30));
      final renewal = plan.renewal!;
      expect(renewal.fireDate, const CivilDate(2026, 3, 29));
      expect(_instant(renewal).toUtc(), DateTime.utc(2026, 3, 29, 18));
    });
  });

  group('horizon of 30 days by default (A1)', () {
    test('a typical rotation (one alarm a day) fits in the cap', () {
      final plan = _plan(
        _daily(['night'], to: 60),
        const AlarmSettings(
          enabled: true,
          byShiftType: {'night': AlarmTypeSettings(enabled: true)},
        ),
      );
      expect(AlarmSettings.defaultHorizonDays, 30);
      expect(plan.alarms, hasLength(30));
      expect(plan.alarms.last.shiftDate, _today.addDays(29));
      expect(plan.renewal!.fireDate, _today.addDays(28));
    });

    test('a stored version 1 horizon (always the old default) reads as 30', () {
      final settings = AlarmSettings.fromJson({
        'version': 1,
        'enabled': true,
        'horizonDays': 14,
      });
      expect(settings.horizonDays, 30);
    });

    test('a version 2 horizon is honoured (and clamped)', () {
      expect(
        AlarmSettings.fromJson({'version': 2, 'horizonDays': 10}).horizonDays,
        10,
      );
      expect(
        AlarmSettings.fromJson({'version': 2, 'horizonDays': 90}).horizonDays,
        30,
      );
      expect(
        AlarmSettings.fromJson({'horizonDays': 10}).horizonDays,
        30,
        reason: 'no version = version 1',
      );
    });

    test('settings round-trip through version 2', () {
      const settings = AlarmSettings(enabled: true, horizonDays: 21);
      final json = settings.toJson();
      expect(json['version'], 2);
      expect(AlarmSettings.fromJson(json), settings);
    });
  });
}

String _throwingBody(CivilDate day) => throw StateError('no texts');
