import 'dart:async';

import 'package:cuadrante/core/database/app_database.dart';
import 'package:cuadrante/core/database/database_provider.dart';
import 'package:cuadrante/features/backup/data/backup_repository.dart'
    show isDeviceSetting;
import 'package:cuadrante/features/calendar_export/application/device_calendar_providers.dart';
import 'package:cuadrante/features/calendar_export/domain/device_calendar_api.dart';
import 'package:cuadrante/features/calendar_export/domain/export_events.dart';
import 'package:cuadrante/features/device_events/application/device_events.dart';
import 'package:cuadrante/features/device_events/application/device_events_providers.dart';
import 'package:cuadrante/features/device_events/data/device_events_repository.dart';
import 'package:cuadrante/features/device_events/domain/device_events_permission.dart';
import 'package:cuadrante/features/device_events/domain/device_events_settings.dart';
import 'package:cuadrante/features/schedule/domain/civil_date.dart';
import 'package:flutter/widgets.dart' show SizedBox;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_device_calendar.dart';
import '../../support/test_storage.dart';

const _day = CivilDate(2026, 10, 20);

/// A phone whose **first** `events` call snapshots what it had, tells the test
/// it got there and then waits for [gate] before answering: it holds a read in
/// flight while the app "comes back to the front".
class _GatedPhone extends FakeDeviceCalendar {
  _GatedPhone({required this._gate, required this._reached});

  final Future<void> _gate;
  final Completer<void> _reached;
  bool _held = false;

  @override
  Future<List<DeviceEvent>> events(
    DateTime start,
    DateTime end, {
    List<String>? calendarIds,
  }) async {
    if (_held) return super.events(start, end, calendarIds: calendarIds);
    _held = true;
    final snapshot = await super.events(start, end, calendarIds: calendarIds);
    _reached.complete();
    await _gate;
    return snapshot;
  }
}

void main() {
  group('DeviceEvents cache', () {
    late FakeDeviceCalendar phone;
    late String work;
    late DeviceEvents cache;

    setUp(() {
      phone = FakeDeviceCalendar();
      work = phone.addCalendar('Trabajo');
      cache = DeviceEvents(
        api: phone,
        loadSettings: () async => DeviceEventsSettings(calendarIds: [work]),
      );
    });

    test('reads a month once and keeps it', () async {
      phone.addSimpleEvent(
        work,
        'Dentista',
        DateTime(2026, 10, 20, 9),
        DateTime(2026, 10, 20, 10),
      );
      final first = await cache.month(_day);
      expect(first.day(_day).timed.single.title, 'Dentista');
      // The same month (another day of it too) does not read again.
      await cache.month(const CivilDate(2026, 10, 1));
      await cache.day(_day);
      expect(phone.eventListings, 1);
    });

    test('two asks at the same time share one read', () async {
      phone.addSimpleEvent(
        work,
        'Dentista',
        DateTime(2026, 10, 20, 9),
        DateTime(2026, 10, 20, 10),
      );
      await Future.wait([cache.month(_day), cache.month(_day)]);
      expect(phone.eventListings, 1);
    });

    test('refresh lets the next read see the changes', () async {
      phone.addSimpleEvent(
        work,
        'Dentista',
        DateTime(2026, 10, 20, 9),
        DateTime(2026, 10, 20, 10),
      );
      await cache.month(_day);
      phone.addSimpleEvent(
        work,
        'Cena',
        DateTime(2026, 10, 20, 21),
        DateTime(2026, 10, 20, 22),
      );
      // Still the old month.
      expect((await cache.month(_day)).day(_day).count, 1);
      cache.refresh();
      expect((await cache.month(_day)).day(_day).count, 2);
      expect(phone.eventListings, 2);
    });

    test(
      'a read under way when the app comes back does not refill the cache',
      () async {
        final gate = Completer<void>();
        final reached = Completer<void>();
        final held = _GatedPhone(gate: gate.future, reached: reached);
        final workId = held.addCalendar('Trabajo');
        held.addSimpleEvent(
          workId,
          'Viejo',
          DateTime(2026, 10, 20, 9),
          DateTime(2026, 10, 20, 10),
        );
        final cache = DeviceEvents(
          api: held,
          loadSettings: () async => DeviceEventsSettings(calendarIds: [workId]),
        );
        final stale = cache.month(_day);
        await reached.future; // it already has the old month in hand
        cache.refresh(); // the app came back to the front
        held.addSimpleEvent(
          workId,
          'Nuevo',
          DateTime(2026, 10, 20, 21),
          DateTime(2026, 10, 20, 22),
        );
        gate.complete(); // the stale read finishes
        // It still answers what it read, but that month is not kept.
        expect((await stale).day(_day).count, 1);
        // The next ask reads again and sees the change.
        expect((await cache.month(_day)).day(_day).count, 2);
        expect(held.eventListings, 2);
      },
    );

    test('a range reads the months it spans and reuses them', () async {
      phone.addSimpleEvent(
        work,
        'Octubre',
        DateTime(2026, 10, 31, 9),
        DateTime(2026, 10, 31, 10),
      );
      phone.addSimpleEvent(
        work,
        'Noviembre',
        DateTime(2026, 11, 1, 9),
        DateTime(2026, 11, 1, 10),
      );
      final days = await cache.range(
        const CivilDate(2026, 10, 31),
        const CivilDate(2026, 11, 1),
      );
      expect(days.map((d) => d.date.toIso()), ['2026-10-31', '2026-11-01']);
      expect(phone.eventListings, 2);
      // Days with nothing are left out, and nothing is read again.
      final wider = await cache.range(
        const CivilDate(2026, 10, 1),
        const CivilDate(2026, 11, 30),
      );
      expect(wider, hasLength(2));
      expect(phone.eventListings, 2);
    });

    test('nothing chosen: nothing is read', () async {
      final none = DeviceEvents(
        api: phone,
        loadSettings: () async => DeviceEventsSettings.none,
      );
      final month = await none.month(_day);
      expect(month.isEmpty, isTrue);
      expect(phone.eventListings, 0);
    });

    test(
      'with the permission denied the month is empty, not an error',
      () async {
        phone.setAccess(CalendarAccess.denied);
        final month = await cache.month(_day);
        expect(month.isEmpty, isTrue);
        expect(month.year, 2026);
        expect(month.month, 10);
        // It never even reached the calendar list (`calendars()` throws without
        // the permission).
        expect(phone.calendarListings, 0);
        expect(phone.eventListings, 0);
        expect((await cache.day(_day)).isEmpty, isTrue);
      },
    );

    test('a revoked permission empties the months already read', () async {
      phone.addSimpleEvent(
        work,
        'Dentista',
        DateTime(2026, 10, 20, 9),
        DateTime(2026, 10, 20, 10),
      );
      expect((await cache.month(_day)).day(_day).count, 1);
      phone.setAccess(CalendarAccess.denied);
      cache.refresh();
      expect((await cache.month(_day)).isEmpty, isTrue);
    });

    test(
      'a phone that does not answer gives an empty month, not an error',
      () async {
        phone.failNext = CalendarApiError.unavailable;
        final month = await cache.month(_day);
        expect(month.isEmpty, isTrue);
      },
    );

    test('a calendar that is not offered is ignored', () async {
      final turnly = phone.addCalendar('Turnly');
      final withTurnly = DeviceEvents(
        api: phone,
        loadSettings: () async =>
            DeviceEventsSettings(calendarIds: ['cal-nope', turnly]),
      );
      final month = await withTurnly.month(_day);
      expect(month.isEmpty, isTrue);
      expect(phone.eventListings, 0);
    });

    test('leaves out the events Turnly wrote in a chosen calendar', () async {
      phone.addSimpleEvent(
        work,
        'Mañana · M',
        DateTime(2026, 10, 20, 6),
        DateTime(2026, 10, 20, 14),
        description:
            '$exportMarkerLine\n'
            '${exportTag('main', _day, 'm', 0)}',
      );
      final month = await cache.month(_day);
      expect(month.day(_day).isEmpty, isTrue);
    });
  });

  group('providers', () {
    late AppDatabase database;
    late FakeDeviceCalendar phone;
    late ProviderContainer container;
    late String work;

    setUp(() {
      database = openMemoryDatabase();
      phone = FakeDeviceCalendar();
      work = phone.addCalendar('Trabajo');
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          deviceCalendarApiProvider.overrideWithValue(phone),
        ],
      );
      addTearDown(database.close);
      addTearDown(container.dispose);
    });

    Future<void> choose(List<String> ids) =>
        DeviceEventsRepository(database)
            .save(DeviceEventsSettings(calendarIds: ids));

    test('the permission state follows the phone', () async {
      expect(
        await container.read(deviceEventsPermissionProvider.future),
        DeviceEventsPermission.granted,
      );
      phone.setAccess(CalendarAccess.denied);
      container.invalidate(deviceEventsPermissionProvider);
      expect(
        await container.read(deviceEventsPermissionProvider.future),
        DeviceEventsPermission.denied,
      );
    });

    test('granted but with no calendar of its own', () async {
      final empty = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          deviceCalendarApiProvider.overrideWithValue(FakeDeviceCalendar()),
        ],
      );
      addTearDown(empty.dispose);
      expect(
        await empty.read(deviceEventsPermissionProvider.future),
        DeviceEventsPermission.noCalendars,
      );
    });

    test('the available calendars leave Turnly out', () async {
      phone.addCalendar('Turnly');
      final calendars = await container.read(
        deviceEventsCalendarsProvider.future,
      );
      expect(calendars.map((c) => c.id), [work]);
    });

    test('the settings controller saves the chosen calendars once', () async {
      await container.read(deviceEventsSettingsProvider.notifier).setCalendars([
        work,
        work,
        '',
      ]);
      final stored = await DeviceEventsRepository(database).load();
      expect(stored.calendarIds, [work]);
      expect(
        (await container.read(deviceEventsSettingsProvider.future)).calendarIds,
        [work],
      );
    });

    test('the month is read from the chosen calendars', () async {
      await choose([work]);
      phone.addSimpleEvent(
        work,
        'Dentista',
        DateTime(2026, 10, 20, 9),
        DateTime(2026, 10, 20, 10),
      );
      final month = await container.read(deviceEventMonthProvider(_day).future);
      expect(month.day(_day).timed.single.title, 'Dentista');
      expect(
        (await container.read(deviceEventDayProvider(_day).future)).count,
        1,
      );
    });

    test('a range gives the days with events', () async {
      await choose([work]);
      phone.addSimpleEvent(
        work,
        'Dentista',
        DateTime(2026, 10, 20, 9),
        DateTime(2026, 10, 20, 10),
      );
      final days = await container.read(
        deviceEventRangeProvider((
          const CivilDate(2026, 10, 19),
          const CivilDate(2026, 10, 21),
        )).future,
      );
      expect(days.map((d) => d.date.toIso()), ['2026-10-20']);
    });
  });

  group('the screen hooks', () {
    late FakeDeviceCalendar phone;
    late String work;

    setUp(() {
      phone = FakeDeviceCalendar();
      work = phone.addCalendar('Trabajo');
    });

    /// Pumps a bare Consumer just to hold a live [WidgetRef].
    Future<WidgetRef> mount(
      WidgetTester tester,
      List<Override> overrides,
    ) async {
      late WidgetRef ref;
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: Consumer(
            builder: (context, r, _) {
              ref = r;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return ref;
    }

    testWidgets('refreshDeviceEvents forgets the cache and reads again', (
      tester,
    ) async {
      phone.addSimpleEvent(
        work,
        'Dentista',
        DateTime(2026, 10, 20, 9),
        DateTime(2026, 10, 20, 10),
      );
      final cache = DeviceEvents(
        api: phone,
        loadSettings: () async => DeviceEventsSettings(calendarIds: [work]),
      );
      final ref = await mount(tester, [
        deviceCalendarApiProvider.overrideWithValue(phone),
        deviceEventsProvider.overrideWithValue(cache),
      ]);
      final first = await ref.read(deviceEventMonthProvider(_day).future);
      expect(first.day(_day).count, 1);

      phone.addSimpleEvent(
        work,
        'Cena',
        DateTime(2026, 10, 20, 21),
        DateTime(2026, 10, 20, 22),
      );
      refreshDeviceEvents(ref);
      final second = await ref.read(deviceEventMonthProvider(_day).future);
      expect(second.day(_day).count, 2);
      expect(phone.eventListings, 2);
    });

    testWidgets('the request uses the Android-aware answer', (tester) async {
      // The first «no» of Android: the question can be asked again, so the
      // permission read afterwards says "never asked" and `declined` is true.
      final android = FakeDeviceCalendar(
        access: CalendarAccess.denied,
        onRequest: CalendarAccess.denied,
        retryableDenials: 1,
      );
      final ref = await mount(tester, [
        deviceCalendarApiProvider.overrideWithValue(android),
      ]);
      final outcome = await requestDeviceEventsPermission(ref);
      expect(outcome.declined, isTrue);
      expect(outcome.access, CalendarAccess.notDetermined);
      expect(android.requests, 1);
    });

    testWidgets('a refusal the system will not repeat comes back as denied', (
      tester,
    ) async {
      final ios = FakeDeviceCalendar(
        access: CalendarAccess.denied,
        onRequest: CalendarAccess.denied,
      );
      final ref = await mount(tester, [
        deviceCalendarApiProvider.overrideWithValue(ios),
      ]);
      final outcome = await requestDeviceEventsPermission(ref);
      expect(outcome.declined, isTrue);
      expect(outcome.access, CalendarAccess.denied);
    });

    testWidgets('granting the permission comes back as granted', (
      tester,
    ) async {
      final ref = await mount(tester, [
        deviceCalendarApiProvider.overrideWithValue(phone),
      ]);
      final outcome = await requestDeviceEventsPermission(ref);
      expect(outcome.access, CalendarAccess.granted);
      expect(outcome.declined, isFalse);
    });
  });

  group('the settings row', () {
    test('belongs to the device, never to the backup', () {
      expect(deviceEventsKey, 'deviceEvents');
      expect(isDeviceSetting(deviceEventsKey), isTrue);
    });

    test('makes the round trip through the database', () async {
      final database = openMemoryDatabase();
      addTearDown(database.close);
      final repository = DeviceEventsRepository(database);
      expect(await repository.load(), DeviceEventsSettings.none);
      await repository.save(
        const DeviceEventsSettings(calendarIds: ['3', 'home']),
      );
      expect(
        await repository.load(),
        const DeviceEventsSettings(calendarIds: ['3', 'home']),
      );
      await repository.save(DeviceEventsSettings.none);
      expect(await repository.load(), DeviceEventsSettings.none);
    });

    test('an unreadable row reads as nothing chosen', () async {
      final database = openMemoryDatabase();
      addTearDown(database.close);
      await database
          .into(database.settings)
          .insertOnConflictUpdate(
            SettingsCompanion.insert(key: deviceEventsKey, value: 'not json {'),
          );
      expect(
        await DeviceEventsRepository(database).load(),
        DeviceEventsSettings.none,
      );
    });
  });
}
