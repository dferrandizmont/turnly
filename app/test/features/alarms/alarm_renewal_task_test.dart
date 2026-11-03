import 'dart:io';
import 'dart:isolate';
import 'dart:ui' show IsolateNameServer, Locale;

import 'package:cuadrante/core/database/app_database.dart';
import 'package:cuadrante/core/database/database_opener.dart';
import 'package:cuadrante/features/alarms/application/alarm_renewal.dart';
import 'package:cuadrante/features/alarms/data/alarm_foreground_relay.dart';
import 'package:cuadrante/features/alarms/data/alarm_renewal_task.dart';
import 'package:cuadrante/features/alarms/data/alarm_scheduler.dart';
import 'package:cuadrante/features/alarms/data/alarm_settings_repository.dart';
import 'package:cuadrante/features/alarms/domain/alarm_planner.dart';
import 'package:cuadrante/features/alarms/domain/alarm_settings.dart';
import 'package:cuadrante/features/alarms/domain/alarm_strings.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/features/settings/data/preferences_repository.dart';
import 'package:cuadrante/features/settings/domain/preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:workmanager/workmanager.dart';

// A1: the background renewal as a plain function, its database store, the
// hand-over to a running app and the WorkManager registration.

const _strings = AlarmStrings(
  title: _title,
  body: _body,
  channelName: 'Alarmas',
  channelDescription: 'Descripción',
  dayBeforeTitle: _title,
  snoozeAction: 'Posponer',
  awakeAction: 'Despierto',
  testTitle: 'Prueba',
  testBody: 'Prueba',
  reminderTitle: 'Recordatorio',
  reminderEmptyBody: 'Recordatorio',
  reminderChannelName: 'Recordatorios',
  reminderChannelDescription: 'Descripción',
  renewalTitle: 'Avisos de turno',
  renewalBody: _renewalBody,
);
String _title(String name, String start) => '$name $start';
String _body(String name, String start, String end) => '$name $start-$end';
String _renewalBody(CivilDate day) => 'Hasta ${day.toIso()}';

const _night = ShiftType(
  id: 'night',
  code: 'N',
  name: 'Noche',
  colorValue: 0xFF336699,
  category: ShiftCategory.work,
  startMinute: 22 * 60,
  endMinute: 6 * 60,
);

const _today = CivilDate(2026, 10, 19);
final _noon = DateTime(2026, 10, 19, 12);

final _schedule = Schedule(
  shiftTypes: const [_night],
  entries: {
    for (var i = 0; i <= 60; i++)
      _today.addDays(i): DayEntry(
        date: _today.addDays(i),
        shiftTypeIds: const ['night'],
      ),
  },
);

const _settings = AlarmSettings(
  enabled: true,
  horizonDays: 14,
  byShiftType: {'night': AlarmTypeSettings(enabled: true)},
);

class _FakeStore implements AlarmRenewalStore {
  _FakeStore({
    this.settings = _settings,
    this.locale = const Locale('es'),
    this.formatLocale,
    this.hour12 = false,
    this.failOnSettings = false,
    required this.log,
  });

  final AlarmSettings settings;
  final Locale locale;
  final String? formatLocale;
  final bool hour12;
  final bool failOnSettings;
  final List<String> log;
  bool closed = false;

  @override
  Future<AlarmSettings> loadSettings() async {
    log.add('settings');
    if (failOnSettings) throw StateError('database is locked');
    return settings;
  }

  @override
  Future<Schedule> loadPrimarySchedule() async {
    log.add('schedule');
    return _schedule;
  }

  @override
  Future<AlarmTextFormat> textFormat() async => AlarmTextFormat(
    locale: locale,
    formatLocale: formatLocale,
    hour12: hour12,
  );

  @override
  Future<void> close() async {
    log.add('close');
    closed = true;
  }
}

/// A [FakeAlarmScheduler] that logs when the plugin is first touched.
class _LoggingScheduler extends FakeAlarmScheduler {
  _LoggingScheduler(this.log, {super.permission});

  final List<String> log;

  @override
  Future<void> configure(AlarmStrings strings) {
    log.add('configure');
    return super.configure(strings);
  }
}

void main() {
  group('runAlarmRenewal', () {
    late List<String> log;
    late _LoggingScheduler scheduler;
    late int schedulersMade;
    late int askAppCalls;
    late List<AlarmTextFormat> formatsAsked;
    late List<Object> errors;

    setUp(() {
      log = [];
      scheduler = _LoggingScheduler(log);
      schedulersMade = 0;
      askAppCalls = 0;
      formatsAsked = [];
      errors = [];
    });

    Future<AlarmRenewalOutcome> run({
      bool appAlive = false,
      Future<AlarmRenewalStore?> Function()? openStore,
      _FakeStore? store,
    }) => runAlarmRenewal(
      askApp: () async {
        askAppCalls++;
        return appAlive;
      },
      openStore: openStore ?? () async => store ?? _FakeStore(log: log),
      scheduler: () {
        schedulersMade++;
        return scheduler;
      },
      strings: (format) async {
        formatsAsked.add(format);
        return _strings;
      },
      now: () => _noon,
      onError: (error, _) => errors.add(error),
    );

    test('with the app alive in the process, the app replans: nothing is '
        'opened or scheduled here', () async {
      var opened = false;
      final outcome = await run(
        appAlive: true,
        openStore: () async {
          opened = true;
          return _FakeStore(log: log);
        },
      );
      expect(outcome, AlarmRenewalOutcome.handledByApp);
      expect(alarmRenewalSucceeded(outcome), isTrue);
      expect(opened, isFalse);
      expect(schedulersMade, 0);
    });

    test('renews with the same planner as the app, database closed before '
        'touching the notifications', () async {
      final outcome = await run();
      expect(outcome, AlarmRenewalOutcome.renewed);
      final expected = planAlarmSchedule(
        schedule: _schedule,
        settings: _settings,
        now: _noon,
        strings: _strings,
        location: await scheduler.planningZone(),
      );
      expect(scheduler.scheduled, expected.toSchedule);
      expect(
        scheduler.scheduled.where((a) => a.kind == AlarmKind.renewal),
        hasLength(1),
        reason: 'cut by the horizon: the renewal notice goes along',
      );
      expect(log, ['settings', 'schedule', 'close', 'configure']);
      expect(askAppCalls, 2, reason: 'asks again after writing');
      expect(formatsAsked, [const AlarmTextFormat(locale: Locale('es'))]);
    });

    test('running twice gives the same alarms: no duplicates', () async {
      await run();
      final first = scheduler.scheduled;
      await run();
      expect(scheduler.scheduled, first);
      expect(
        scheduler.scheduled.map((a) => a.id).toSet(),
        hasLength(first.length),
      );
    });

    test('a skipped day stays silent and a snooze is never touched', () async {
      final skipped = _today.addDays(3);
      scheduler.oneOffs.add(
        OneOffAlarm(
          id: 7,
          fireAt: _noon.add(const Duration(minutes: 5)),
          kind: OneOffKind.snooze,
          title: 'Noche',
          body: 'Noche',
          payload: '${alarmSnoozePayloadPrefix}x',
        ),
      );
      final outcome = await run(
        store: _FakeStore(
          log: log,
          settings: _settings.withSkipped(skipped, skipped: true),
        ),
      );
      expect(outcome, AlarmRenewalOutcome.renewed);
      expect(
        scheduler.scheduled.where(
          (a) => a.shiftDate == skipped && a.kind != AlarmKind.renewal,
        ),
        isEmpty,
      );
      expect(scheduler.oneOffs.single.id, 7);
      expect(scheduler.cancelSnoozeCalls, 0);
    });

    test('the texts follow the language and the clock of the app', () async {
      await run(
        store: _FakeStore(
          log: log,
          locale: const Locale('en'),
          formatLocale: 'en_US',
          hour12: true,
        ),
      );
      expect(formatsAsked, [
        const AlarmTextFormat(
          locale: Locale('en'),
          formatLocale: 'en_US',
          hour12: true,
        ),
      ]);
    });

    test('alarmStringsFor writes the hours with the chosen clock', () async {
      final h12 = await alarmStringsFor(
        const AlarmTextFormat(
          locale: Locale('en'),
          formatLocale: 'en_US',
          hour12: true,
        ),
      );
      expect(h12.time(22 * 60), '10:00 PM');
      expect(h12.title('Night', h12.time(22 * 60)), contains('10:00 PM'));
      final h24 = await alarmStringsFor(
        const AlarmTextFormat(locale: Locale('es'), formatLocale: 'es_ES'),
      );
      expect(h24.time(22 * 60), '22:00');
      expect(h24.renewalBody, isNotNull);
    });

    test('no database: nothing is touched', () async {
      final outcome = await run(openStore: () async => null);
      expect(outcome, AlarmRenewalOutcome.noDatabase);
      expect(alarmRenewalSucceeded(outcome), isTrue);
      expect(schedulersMade, 0);
    });

    test('alarms off: the store is closed and nothing is touched', () async {
      final store = _FakeStore(log: log, settings: AlarmSettings.disabled);
      final outcome = await run(store: store);
      expect(outcome, AlarmRenewalOutcome.alarmsOff);
      expect(store.closed, isTrue);
      expect(schedulersMade, 0);
      expect(log, isNot(contains('schedule')));
    });

    test('no permission: nothing is scheduled nor cancelled', () async {
      scheduler = _LoggingScheduler(log, permission: AlarmPermission.denied);
      final outcome = await run();
      expect(outcome, AlarmRenewalOutcome.noPermission);
      expect(scheduler.replaceCalls, 0);
      expect(scheduler.cancelSnoozeCalls, 0);
    });

    test('a busy database fails (to be retried) and is still closed', () async {
      final store = _FakeStore(log: log, failOnSettings: true);
      final outcome = await run(store: store);
      expect(outcome, AlarmRenewalOutcome.failed);
      expect(alarmRenewalSucceeded(outcome), isFalse);
      expect(store.closed, isTrue);
      expect(schedulersMade, 0);
      expect(errors.single, isA<StateError>());
    });

    test('a store that cannot be opened fails without throwing', () async {
      final outcome = await run(
        openStore: () async => throw const FileSystemException('locked'),
      );
      expect(outcome, AlarmRenewalOutcome.failed);
      expect(errors.single, isA<FileSystemException>());
    });
  });

  group('openAlarmRenewalStore', () {
    late Directory dir;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('alarm_renewal_');
      addTearDown(() => dir.deleteSync(recursive: true));
    });

    Future<void> createDatabase({
      Future<void> Function(AppDatabase db)? prepare,
    }) async {
      final db = await openAppDatabase(directory: dir);
      await db.customSelect('SELECT 1').get();
      await prepare?.call(db);
      await db.close();
    }

    test('no file yet: null, and no file is created', () async {
      expect(await openAlarmRenewalStore(directory: dir), isNull);
      expect(File(p.join(dir.path, databaseFileName)).existsSync(), isFalse);
    });

    test('reads the settings, the primary schedule and the language', () async {
      await createDatabase(
        prepare: (db) async {
          await AlarmSettingsRepository(db).save(_settings);
          await PreferencesRepository(db).setLanguage(AppLanguage.gl);
        },
      );
      final store = await openAlarmRenewalStore(directory: dir);
      expect(store, isNotNull);
      try {
        expect(await store!.loadSettings(), _settings);
        final schedule = await store.loadPrimarySchedule();
        expect(schedule.shiftTypes, isA<List<ShiftType>>());
        expect((await store.textFormat()).locale, const Locale('gl'));
      } finally {
        await store?.close();
      }
    });

    test('a database on another schema version is left alone', () async {
      await createDatabase();
      final file = File(p.join(dir.path, databaseFileName));
      final raw = sqlite3.open(file.path);
      raw.execute(
        'PRAGMA user_version = ${AppDatabase.latestSchemaVersion - 1}',
      );
      raw.close();
      final before = file.readAsBytesSync();
      expect(await openAlarmRenewalStore(directory: dir), isNull);
      expect(file.readAsBytesSync(), before, reason: 'never migrated');
    });

    test('the store cannot write to the database', () async {
      await createDatabase();
      final store = await openAlarmRenewalStore(
        directory: dir,
      ) as DatabaseAlarmRenewalStore;
      try {
        // Reads work...
        expect(await store.loadSettings(), AlarmSettings.disabled);
      } finally {
        await store.close();
      }
      // ...and the file opened the same way refuses a write.
      final raw = sqlite3.open(
        p.join(dir.path, databaseFileName),
        mode: OpenMode.readOnly,
      );
      addTearDown(raw.close);
      expect(
        () => raw.execute("INSERT INTO settings VALUES ('x', '1')"),
        throwsA(isA<SqliteException>()),
      );
    });

    test('«Sistema» follows the phone languages like the app', () async {
      final db = await openAppDatabase(directory: dir);
      final store = DatabaseAlarmRenewalStore(
        db,
        phoneLocales: const [Locale('fr'), Locale('ca', 'ES')],
      );
      try {
        final format = await store.textFormat();
        expect(format.locale, const Locale('ca'));
        expect(format.formatLocale, 'ca_ES');
      } finally {
        await store.close();
      }
    });

    Future<AlarmTextFormat> clockFor(
      TimeFormatPreference? preference, {
      List<Locale> phone = const [Locale('en', 'US')],
      bool phone24 = false,
    }) async {
      final db = await openAppDatabase(directory: dir);
      if (preference != null) {
        await PreferencesRepository(db).setTimeFormat(preference);
      }
      final store = DatabaseAlarmRenewalStore(
        db,
        phoneLocales: phone,
        phoneUses24Hour: phone24,
      );
      try {
        return await store.textFormat();
      } finally {
        await store.close();
      }
    }

    test('Formato de hora: 12 h and 24 h are what they say', () async {
      expect((await clockFor(TimeFormatPreference.h12)).hour12, isTrue);
      expect((await clockFor(TimeFormatPreference.h24)).hour12, isFalse);
    });

    test(
      'no stored format (an existing install) is 24 h, as in the app',
      () async {
        expect((await clockFor(null)).hour12, isFalse);
      },
    );

    test('Automático follows the region like FormatsHost', () async {
      final us = await clockFor(TimeFormatPreference.auto);
      expect(us.formatLocale, 'en_US');
      expect(us.hour12, isTrue);
      expect(
        (await clockFor(
          TimeFormatPreference.auto,
          phone: const [Locale('en', 'GB')],
        )).hour12,
        isFalse,
      );
      expect(
        (await clockFor(
          TimeFormatPreference.auto,
          phone: const [Locale('es', 'ES')],
        )).hour12,
        isFalse,
      );
      // The phone's 24-hour switch wins, when the engine reports it.
      expect(
        (await clockFor(TimeFormatPreference.auto, phone24: true)).hour12,
        isFalse,
      );
    });
  });

  group('AlarmForegroundRelay', () {
    const name = 'test.alarms.resync';

    tearDown(() => IsolateNameServer.removePortNameMapping(name));

    test('a running app replans when asked; closed, nobody answers', () async {
      var resyncs = 0;
      final relay = AlarmForegroundRelay(portName: name)
        ..open(() async => resyncs++);
      expect(await askForegroundToResync(portName: name), isTrue);
      expect(resyncs, 1);

      relay.close();
      expect(await askForegroundToResync(portName: name), isFalse);
      expect(resyncs, 1);
    });

    test('listening from main: a request that comes while the app starts is '
        'held until AlarmsHost attaches, then answered', () async {
      var resyncs = 0;
      final relay = AlarmForegroundRelay(portName: name)..listen();
      addTearDown(relay.close);
      expect(relay.isListening, isTrue);
      var answered = false;
      final asked = askForegroundToResync(portName: name)
          .then((v) => answered = v);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(answered, isFalse, reason: 'held, not dropped');
      expect(resyncs, 0);

      relay.attach(() async => resyncs++);
      await asked;
      expect(answered, isTrue);
      expect(resyncs, 1);
    });

    test('a detached relay (AlarmsHost gone) holds requests and keeps the '
        'mapping; attaching again answers them', () async {
      var resyncs = 0;
      final relay = AlarmForegroundRelay(portName: name)
        ..open(() async => resyncs++);
      addTearDown(relay.close);
      relay.detach();
      final asked = askForegroundToResync(portName: name);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(IsolateNameServer.lookupPortByName(name), isNotNull);
      expect(resyncs, 0);
      relay.attach(() async => resyncs++);
      expect(await asked, isTrue);
      expect(resyncs, 1);
    });

    test('listening twice keeps one registration', () async {
      final relay = AlarmForegroundRelay(portName: name)..listen();
      addTearDown(relay.close);
      final first = IsolateNameServer.lookupPortByName(name);
      relay.listen();
      expect(IsolateNameServer.lookupPortByName(name), first);
    });

    test('an app whose resync fails still counts as handled', () async {
      final relay = AlarmForegroundRelay(portName: name)
        ..open(() async => throw StateError('plugin'));
      addTearDown(relay.close);
      expect(await askForegroundToResync(portName: name), isTrue);
    });

    test('a port left by a dead isolate times out and is forgotten', () async {
      final orphan = ReceivePort();
      addTearDown(orphan.close);
      IsolateNameServer.registerPortWithName(orphan.sendPort, name);
      expect(
        await askForegroundToResync(
          portName: name,
          timeout: const Duration(milliseconds: 50),
        ),
        isFalse,
      );
      expect(IsolateNameServer.lookupPortByName(name), isNull);
    });

    test('opening replaces a stale mapping; closing an old relay leaves the '
        'new one alone', () async {
      var first = 0;
      var second = 0;
      final old = AlarmForegroundRelay(portName: name)
        ..open(() async => first++);
      final current = AlarmForegroundRelay(portName: name)
        ..open(() async => second++);
      addTearDown(current.close);
      old.close();
      expect(await askForegroundToResync(portName: name), isTrue);
      expect((first, second), (0, 1));
    });
  });

  group('WorkmanagerAlarmRenewal', () {
    test('registers the periodic task once and cancels it when off', () async {
      final fake = _FakeWorkmanager();
      final renewal = WorkmanagerAlarmRenewal(workmanager: fake);
      await renewal.setEnabled(true);
      await renewal.setEnabled(true);
      expect(fake.initializeCalls, 1);
      expect(fake.registered, hasLength(1));
      final call = fake.registered.single;
      expect(call.name, alarmRenewalTaskName);
      expect(call.frequency, alarmRenewalFrequency);
      expect(call.frequency, const Duration(hours: 12));
      expect(call.constraints?.networkType, NetworkType.notRequired);
      expect(call.policy, ExistingPeriodicWorkPolicy.update);

      await renewal.setEnabled(false);
      await renewal.setEnabled(false);
      expect(fake.cancelled, [alarmRenewalTaskName]);
      expect(fake.initializeCalls, 1);

      await renewal.setEnabled(true);
      expect(fake.registered, hasLength(2));
    });

    test('cancelling does not initialize the plugin', () async {
      final fake = _FakeWorkmanager();
      await WorkmanagerAlarmRenewal(workmanager: fake).setEnabled(false);
      expect(fake.cancelled, [alarmRenewalTaskName]);
      expect(fake.initializeCalls, 0);
    });

    test('a failed registration is tried again on the next call', () async {
      final fake = _FakeWorkmanager()..failRegister = true;
      final renewal = WorkmanagerAlarmRenewal(workmanager: fake);
      await expectLater(renewal.setEnabled(true), throwsStateError);
      fake.failRegister = false;
      await renewal.setEnabled(true);
      expect(fake.registered, hasLength(1));
    });
  });
}

class _Registration {
  _Registration(this.name, this.frequency, this.constraints, this.policy);
  final String name;
  final Duration? frequency;
  final Constraints? constraints;
  final ExistingPeriodicWorkPolicy? policy;
}

class _FakeWorkmanager implements Workmanager {
  int initializeCalls = 0;
  bool failRegister = false;
  final List<_Registration> registered = [];
  final List<String> cancelled = [];

  @override
  Future<void> initialize(
    Function callbackDispatcher, {
    bool isInDebugMode = false,
  }) async => initializeCalls++;

  @override
  Future<void> registerPeriodicTask(
    String uniqueName,
    String taskName, {
    Duration? frequency,
    Duration? flexInterval,
    Map<String, dynamic>? inputData,
    Duration? initialDelay,
    Constraints? constraints,
    ExistingPeriodicWorkPolicy? existingWorkPolicy,
    BackoffPolicy? backoffPolicy,
    Duration? backoffPolicyDelay,
    String? tag,
    ForegroundServiceConfig? foregroundServiceConfig,
  }) async {
    if (failRegister) throw StateError('WorkManager');
    registered.add(
      _Registration(uniqueName, frequency, constraints, existingWorkPolicy),
    );
  }

  @override
  Future<void> cancelByUniqueName(String uniqueName) async =>
      cancelled.add(uniqueName);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
