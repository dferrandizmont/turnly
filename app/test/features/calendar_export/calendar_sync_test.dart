import 'package:cuadrante/features/alarms/data/alarm_scheduler.dart'
    show AsyncMutex;
import 'package:cuadrante/features/calendar_export/application/calendar_sync.dart';
import 'package:cuadrante/features/calendar_export/domain/calendar_sync_settings.dart';
import 'package:cuadrante/features/calendar_export/domain/device_calendar_api.dart';
import 'package:cuadrante/features/calendar_export/domain/export_events.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_device_calendar.dart';
import '../import/import_support.dart';

/// «Today» of these tests: Monday 19 Oct 2026, 09:00.
final _now = DateTime(2026, 10, 19, 9);
const _today = CivilDate(2026, 10, 19);

const _sick = ShiftType(
  id: 'sick',
  code: 'B',
  name: 'Baja médica',
  colorValue: 0xFF8E8E93,
  category: ShiftCategory.absence,
);

Schedule scheduleOf(
  Map<CivilDate, List<String>> days, {
  List<ShiftType> extra = const [],
}) => Schedule(
  shiftTypes: [...baseTypes, ...extra],
  entries: {
    for (final e in days.entries)
      e.key: DayEntry(date: e.key, shiftTypeIds: e.value),
  },
);

/// The service wired to a fake phone and an in-memory settings row.
class Rig {
  Rig({
    required this.phone,
    Schedule? schedule,
    CalendarSyncSettings? settings,
    Duration debounce = const Duration(seconds: 3),
  }) : schedule = schedule ?? scheduleOf({}),
       stored = settings ?? CalendarSyncSettings.off {
    sync = CalendarSync(
      api: phone,
      load: () async => stored,
      save: (s) async {
        saves++;
        stored = s;
      },
      readSchedule: (id) async => id == missingCalendar ? null : this.schedule,
      now: () => _now,
      lock: AsyncMutex(),
      debounce: debounce,
      onError: (e, s) => errors.add(e),
      onChanged: () => changes++,
    );
    sync.notices.listen(notices.add);
  }

  final FakeDeviceCalendar phone;
  Schedule schedule;
  CalendarSyncSettings stored;
  late final CalendarSync sync;
  String? missingCalendar;
  int saves = 0;
  int changes = 0;
  final List<Object> errors = [];
  final List<CalendarSyncNotice> notices = [];
}

CalendarSyncSettings onFor(
  String deviceCalendarId, {
  String name = 'Turnly',
  String appCalendarId = 'main',
  bool includeRest = false,
  bool includeAbsences = false,
}) => CalendarSyncSettings(
  enabled: true,
  deviceCalendarId: deviceCalendarId,
  deviceCalendarName: name,
  appCalendarId: appCalendarId,
  includeRest: includeRest,
  includeAbsences: includeAbsences,
);

/// Tags of the events in [calendarId], sorted.
List<String> tagsIn(FakeDeviceCalendar phone, String calendarId) => [
  for (final e in phone.eventsOf(calendarId))
    ExportTag.parse(e.description)?.key ?? 'foreign:${e.title}',
]..sort();

void main() {
  group('a pass', () {
    test('is a no-op while «Mantener al día» is off', () async {
      final phone = FakeDeviceCalendar();
      final id = phone.addCalendar('Turnly');
      final rig = Rig(
        phone: phone,
        schedule: scheduleOf({
          _today: ['morning'],
        }),
      );
      expect(await rig.sync.sync(), CalendarSyncOutcome.off);
      expect(phone.eventListings, 0);
      expect(phone.calendarListings, 0);
      expect(phone.createdEvents, 0);
      expect(phone.eventsOf(id), isEmpty);
      expect(rig.saves, 0);
    });

    test('creates the shifts of the window', () async {
      final phone = FakeDeviceCalendar();
      final id = phone.addCalendar('Turnly');
      final rig = Rig(
        phone: phone,
        settings: onFor(id),
        schedule: scheduleOf({
          _today: ['morning'],
          _today.addDays(1): ['night'],
        }),
      );
      expect(await rig.sync.sync(), CalendarSyncOutcome.synced);
      expect(phone.eventsOf(id), hasLength(2));
      expect(
        phone.eventsOf(id).map((e) => e.title),
        containsAll(['Mañana · M', 'Noche · N']),
      );
      expect(rig.stored.lastSyncAt, _now);
      expect(rig.stored.lastFailed, 0);
      expect(rig.stored.enabled, isTrue);
      expect(rig.changes, 1);
    });

    test('creates, updates and deletes by difference', () async {
      final phone = FakeDeviceCalendar();
      final id = phone.addCalendar('Turnly');
      final rig = Rig(
        phone: phone,
        settings: onFor(id),
        schedule: scheduleOf({
          _today: ['morning'],
          _today.addDays(1): ['afternoon'],
          _today.addDays(2): ['night'],
        }),
      );
      await rig.sync.sync();
      expect(phone.eventsOf(id), hasLength(3));

      // Day 0 stays, day 1 changes shift, day 2 is cleared, day 3 is new.
      rig.schedule = scheduleOf({
        _today: ['morning'],
        _today.addDays(1): ['night'],
        _today.addDays(3): ['afternoon'],
      });
      final created = phone.createdEvents;
      final deleted = phone.deletedEvents;
      await rig.sync.sync();

      final byDay = {
        for (final e in phone.eventsOf(id))
          ExportTag.parse(e.description)!.date: e.title,
      };
      expect(byDay, {
        _today: 'Mañana · M',
        _today.addDays(1): 'Noche · N',
        _today.addDays(3): 'Tarde · T',
      });
      // Day 1 is replaced (one delete, one create), day 2 deleted, day 3
      // created; day 0 is not touched.
      expect(phone.createdEvents - created, 2);
      expect(phone.deletedEvents - deleted, 2);
    });

    test('a second pass changes nothing: no duplicates, no churn', () async {
      final phone = FakeDeviceCalendar();
      final id = phone.addCalendar('Turnly');
      final rig = Rig(
        phone: phone,
        settings: onFor(id, includeRest: true),
        schedule: scheduleOf({
          for (var i = 0; i < 20; i++)
            _today.addDays(i): [i.isEven ? 'morning' : 'rest'],
        }),
      );
      await rig.sync.sync();
      final first = tagsIn(phone, id);
      expect(first, hasLength(20));
      final created = phone.createdEvents;
      final deleted = phone.deletedEvents;

      await rig.sync.sync();
      await rig.sync.sync();
      expect(tagsIn(phone, id), first);
      expect(phone.createdEvents, created);
      expect(phone.deletedEvents, deleted);
      expect(first.toSet(), hasLength(first.length), reason: 'unique tags');
    });

    test(
      'repairs a copy the user deleted and a duplicate that appeared',
      () async {
        final phone = FakeDeviceCalendar();
        final id = phone.addCalendar('Turnly');
        final rig = Rig(
          phone: phone,
          settings: onFor(id),
          schedule: scheduleOf({
            _today: ['morning'],
            _today.addDays(1): ['afternoon'],
          }),
        );
        await rig.sync.sync();
        final events = phone.eventsOf(id);
        // The user deletes one by hand, and a copy of the other shows up.
        await phone.deleteEvent(events.first.instanceId);
        final other = events.last;
        phone.addSimpleEvent(
          id,
          other.title,
          other.start,
          other.end,
          description: other.description,
        );
        await rig.sync.sync();
        expect(phone.eventsOf(id), hasLength(2));
        expect(tagsIn(phone, id).toSet(), hasLength(2));
      },
    );

    test('only touches its own events', () async {
      final phone = FakeDeviceCalendar();
      final id = phone.addCalendar('Turnly');
      final other = phone.addCalendar('Personal');
      DateTime at(int day, int hour) => DateTime(2026, 10, day, hour);
      // The user's own event in the same calendar.
      phone.addSimpleEvent(id, 'Dentista', at(20, 9), at(20, 10));
      // Text that merely quotes a tag is not ours.
      phone.addSimpleEvent(
        id,
        'Nota',
        at(20, 11),
        at(20, 12),
        description:
            'mira esto\n${exportTag('main', _today.addDays(1), 'morning', 0)}',
      );
      // Our tag but for another Turnly calendar.
      phone.addSimpleEvent(
        id,
        'Mañana · M',
        at(21, 6),
        at(21, 14),
        description:
            '$exportMarkerLine\n'
            '${exportTag('otro', _today.addDays(2), 'morning', 0)}',
      );
      // Our tag, but in another phone calendar.
      phone.addSimpleEvent(
        other,
        'Mañana · M',
        at(21, 6),
        at(21, 14),
        description:
            '$exportMarkerLine\n'
            '${exportTag('main', _today.addDays(2), 'morning', 0)}',
      );
      // Our tag, outside the window (a month ago): kept as history.
      final old = phone.addSimpleEvent(
        id,
        'Mañana · M',
        DateTime(2026, 9, 10, 6),
        DateTime(2026, 9, 10, 14),
        description:
            '$exportMarkerLine\n'
            '${exportTag('main', const CivilDate(2026, 9, 10), 'morning', 0)}',
      );
      final rig = Rig(
        phone: phone,
        settings: onFor(id),
        schedule: scheduleOf({
          _today: ['morning'],
        }),
      );
      await rig.sync.sync();

      final titles = phone.eventsOf(id).map((e) => e.title).toList();
      expect(titles, contains('Dentista'));
      expect(titles, contains('Nota'));
      expect(phone.eventsOf(id).map((e) => e.instanceId), contains(old));
      expect(phone.eventsOf(other), hasLength(1));
      expect(
        phone
            .eventsOf(id)
            .where((e) => ExportTag.parse(e.description)?.calendarId == 'otro'),
        hasLength(1),
      );
      // The four above plus the one shift written now.
      expect(phone.eventsOf(id), hasLength(5));
      await rig.sync.sync();
      expect(phone.eventsOf(id), hasLength(5));
      expect(phone.deletedEvents, 0);
    });

    test('keeps to the window: a week back, three months ahead', () async {
      final phone = FakeDeviceCalendar();
      final id = phone.addCalendar('Turnly');
      final rig = Rig(
        phone: phone,
        settings: onFor(id),
        schedule: scheduleOf({
          _today.addDays(-8): ['morning'],
          _today.addDays(-7): ['morning'],
          _today.addDays(90): ['morning'],
          _today.addDays(91): ['morning'],
        }),
      );
      await rig.sync.sync();
      final days = phone
          .eventsOf(id)
          .map((e) => ExportTag.parse(e.description)!.date)
          .toSet();
      expect(days, {_today.addDays(-7), _today.addDays(90)});
    });

    test('absences stay out unless asked; when asked they follow', () async {
      final phone = FakeDeviceCalendar();
      final id = phone.addCalendar('Turnly');
      final rig = Rig(
        phone: phone,
        settings: onFor(id),
        schedule: scheduleOf(
          {
            _today: ['morning'],
            _today.addDays(1): ['sick'],
          },
          extra: [_sick],
        ),
      );
      await rig.sync.sync();
      expect(phone.eventsOf(id).map((e) => e.title), ['Mañana · M']);
      expect(
        phone.eventsOf(id).map((e) => e.description).join(),
        isNot(contains('sick')),
      );

      rig.stored = rig.stored.copyWith(includeAbsences: true);
      await rig.sync.sync();
      expect(phone.eventsOf(id), hasLength(2));

      // Switched off again: the sick leave is taken out of the calendar.
      rig.stored = rig.stored.copyWith(includeAbsences: false);
      await rig.sync.sync();
      expect(phone.eventsOf(id).map((e) => e.title), ['Mañana · M']);
    });

    test('counts events that could not be written and retries them', () async {
      final phone = FakeDeviceCalendar();
      final id = phone.addCalendar('Turnly');
      phone.failCreatingTitles.add('Tarde · T');
      final rig = Rig(
        phone: phone,
        settings: onFor(id),
        schedule: scheduleOf({
          _today: ['morning'],
          _today.addDays(1): ['afternoon'],
        }),
      );
      expect(await rig.sync.sync(), CalendarSyncOutcome.synced);
      expect(rig.stored.lastFailed, 1);
      expect(rig.stored.enabled, isTrue);
      phone.failCreatingTitles.clear();
      await rig.sync.sync();
      expect(rig.stored.lastFailed, 0);
      expect(phone.eventsOf(id), hasLength(2));
    });

    test(
      'a calendar that does not answer fails the pass and keeps it on',
      () async {
        final phone = FakeDeviceCalendar();
        final id = phone.addCalendar('Turnly');
        final rig = Rig(
          phone: phone,
          settings: onFor(id),
          schedule: scheduleOf({
            _today: ['morning'],
          }),
        );
        phone.failNext = CalendarApiError.unavailable;
        expect(await rig.sync.sync(), CalendarSyncOutcome.failed);
        expect(rig.errors, hasLength(1));
        expect(rig.stored.enabled, isTrue);
        expect(rig.stored.notice, isNull);
        // The next change tries again.
        expect(await rig.sync.sync(), CalendarSyncOutcome.synced);
        expect(phone.eventsOf(id), hasLength(1));
      },
    );
  });

  group('it turns itself off, with a notice', () {
    test('when the permission was taken away', () async {
      final phone = FakeDeviceCalendar();
      final id = phone.addCalendar('Turnly');
      final rig = Rig(
        phone: phone,
        settings: onFor(id),
        schedule: scheduleOf({
          _today: ['morning'],
        }),
      );
      phone.setAccess(CalendarAccess.denied);
      expect(await rig.sync.sync(), CalendarSyncOutcome.stopped);
      expect(rig.stored.enabled, isFalse);
      expect(rig.stored.notice, CalendarSyncNotice.permission);
      await Future<void>.delayed(Duration.zero);
      expect(rig.notices, [CalendarSyncNotice.permission]);
      expect(phone.createdEvents, 0);
      expect(phone.deletedEvents, 0);
      // And it stays quiet afterwards.
      expect(await rig.sync.sync(), CalendarSyncOutcome.off);
      expect(rig.notices, hasLength(1));
    });

    test('when the permission is only «add events» (iOS 17)', () async {
      final phone = FakeDeviceCalendar(access: CalendarAccess.writeOnly);
      final id = phone.addCalendar('Turnly');
      final rig = Rig(phone: phone, settings: onFor(id));
      expect(await rig.sync.sync(), CalendarSyncOutcome.stopped);
      expect(rig.stored.notice, CalendarSyncNotice.permission);
    });

    test('when the permission goes away in the middle of the pass', () async {
      final phone = FakeDeviceCalendar();
      final id = phone.addCalendar('Turnly');
      final rig = Rig(
        phone: phone,
        settings: onFor(id),
        schedule: scheduleOf({
          _today: ['morning'],
        }),
      );
      phone.failNext = CalendarApiError.permissionDenied;
      expect(await rig.sync.sync(), CalendarSyncOutcome.stopped);
      expect(rig.stored.notice, CalendarSyncNotice.permission);
    });

    test('when the phone calendar was deleted', () async {
      final phone = FakeDeviceCalendar();
      final rig = Rig(
        phone: phone,
        settings: onFor('cal-gone'),
        schedule: scheduleOf({
          _today: ['morning'],
        }),
      );
      expect(await rig.sync.sync(), CalendarSyncOutcome.stopped);
      expect(rig.stored.enabled, isFalse);
      expect(rig.stored.notice, CalendarSyncNotice.calendarGone);
      expect(phone.createdEvents, 0);
      expect(phone.createdCalendars, 0, reason: 'never makes a new one');
    });

    test('when the calendar id now belongs to another calendar', () async {
      // The id came from another phone (a restored settings row): it must not
      // write into whichever calendar has that number here.
      final phone = FakeDeviceCalendar();
      final id = phone.addCalendar('Trabajo');
      final rig = Rig(
        phone: phone,
        settings: onFor(id, name: 'Turnly'),
        schedule: scheduleOf({
          _today: ['morning'],
        }),
      );
      expect(await rig.sync.sync(), CalendarSyncOutcome.stopped);
      expect(rig.stored.notice, CalendarSyncNotice.calendarGone);
      expect(phone.eventsOf(id), isEmpty);
    });

    test('when the calendar became read-only or hidden', () async {
      final phone = FakeDeviceCalendar();
      final id = phone.addCalendar('Turnly', readOnly: true);
      final rig = Rig(phone: phone, settings: onFor(id));
      expect(await rig.sync.sync(), CalendarSyncOutcome.stopped);
      expect(rig.stored.notice, CalendarSyncNotice.calendarGone);
    });

    test('when the Turnly calendar it exported was deleted', () async {
      final phone = FakeDeviceCalendar();
      final id = phone.addCalendar('Turnly');
      final rig = Rig(
        phone: phone,
        settings: onFor(id, appCalendarId: 'x'),
      );
      rig.missingCalendar = 'x';
      expect(await rig.sync.sync(), CalendarSyncOutcome.stopped);
      expect(rig.stored.notice, CalendarSyncNotice.sourceGone);
      expect(phone.deletedEvents, 0, reason: 'nothing is wiped');
    });

    test('and turning it on again clears the notice', () {
      const s = CalendarSyncSettings(notice: CalendarSyncNotice.permission);
      expect(s.copyWith(enabled: true, clearNotice: true).notice, isNull);
    });
  });

  group('changes are grouped', () {
    testWidgets('a burst of requests makes one pass after the quiet', (
      tester,
    ) async {
      final phone = FakeDeviceCalendar();
      final id = phone.addCalendar('Turnly');
      final rig = Rig(
        phone: phone,
        settings: onFor(id),
        schedule: scheduleOf({
          _today: ['morning'],
        }),
      );
      for (var i = 0; i < 10; i++) {
        rig.sync.requestSync();
        await tester.pump(const Duration(seconds: 1));
      }
      // Each call restarted the wait: nothing ran yet.
      expect(rig.sync.runs, 0);
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(rig.sync.runs, 1);
      expect(phone.eventsOf(id), hasLength(1));
      await tester.pump(const Duration(minutes: 1));
      expect(rig.sync.runs, 1);
    });

    test('a request during a pass makes at most one more, not many', () async {
      final phone = FakeDeviceCalendar();
      final id = phone.addCalendar('Turnly');
      final rig = Rig(
        phone: phone,
        settings: onFor(id),
        schedule: scheduleOf({
          _today: ['morning'],
        }),
      );
      final first = rig.sync.sync();
      final second = rig.sync.sync();
      final third = rig.sync.sync();
      await Future.wait([first, second, third]);
      expect(rig.sync.runs, lessThanOrEqualTo(2));
      expect(phone.eventsOf(id), hasLength(1));
    });

    test('the latest schedule wins, whenever the pass reads it', () async {
      final phone = FakeDeviceCalendar();
      final id = phone.addCalendar('Turnly');
      final rig = Rig(
        phone: phone,
        settings: onFor(id),
        schedule: scheduleOf({
          _today: ['morning'],
        }),
      );
      final running = rig.sync.sync();
      rig.schedule = scheduleOf({
        _today: ['night'],
      });
      await rig.sync.sync();
      await running;
      expect(phone.eventsOf(id).map((e) => e.title), ['Noche · N']);
    });

    test('two passes at once never duplicate (they share the lock)', () async {
      final phone = FakeDeviceCalendar();
      final id = phone.addCalendar('Turnly');
      final lock = AsyncMutex();
      Rig make() {
        final rig = Rig(
          phone: phone,
          settings: onFor(id),
          schedule: scheduleOf({
            for (var i = 0; i < 5; i++) _today.addDays(i): ['morning'],
          }),
        );
        return rig;
      }

      final a = make();
      final b = make();
      // Both write the same calendar; the lock is what keeps them in turn.
      final syncA = CalendarSync(
        api: phone,
        load: () async => a.stored,
        save: (s) async => a.stored = s,
        readSchedule: (_) async => a.schedule,
        now: () => _now,
        lock: lock,
      );
      final syncB = CalendarSync(
        api: phone,
        load: () async => b.stored,
        save: (s) async => b.stored = s,
        readSchedule: (_) async => b.schedule,
        now: () => _now,
        lock: lock,
      );
      await Future.wait([syncA.sync(), syncB.sync()]);
      expect(phone.eventsOf(id), hasLength(5));
      expect(tagsIn(phone, id).toSet(), hasLength(5));
    });
  });

  group('settings', () {
    test('survive a round trip through JSON', () {
      final s = CalendarSyncSettings(
        enabled: true,
        deviceCalendarId: '7',
        deviceCalendarName: 'Turnly',
        appCalendarId: 'main',
        includeRest: true,
        includeAbsences: true,
        notice: CalendarSyncNotice.sourceGone,
        lastSyncAt: DateTime(2026, 10, 19, 9, 30),
        lastFailed: 2,
      );
      expect(CalendarSyncSettings.fromJson(s.toJson()), s);
    });

    test('anything unreadable reads as off', () {
      final s = CalendarSyncSettings.fromJson({
        'enabled': 'yes',
        'deviceCalendarId': 5,
        'notice': 'dragons',
        'lastSyncAt': 'yesterday',
        'lastFailed': 'many',
      });
      expect(s.enabled, isFalse);
      expect(s.active, isFalse);
      expect(s.notice, isNull);
      expect(s.lastSyncAt, isNull);
      expect(s.lastFailed, 0);
    });

    test('are only active with everything they need', () {
      expect(
        const CalendarSyncSettings(enabled: true, deviceCalendarId: '1').active,
        isFalse,
      );
      expect(onFor('1').active, isTrue);
      expect(onFor('1').copyWith(enabled: false).active, isFalse);
    });
  });
}
