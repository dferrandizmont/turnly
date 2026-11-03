import 'package:cuadrante/features/alarms/application/alarm_providers.dart';
import 'package:cuadrante/features/alarms/application/alarm_renewal.dart';
import 'package:cuadrante/features/alarms/application/alarm_sync.dart';
import 'package:cuadrante/features/alarms/data/alarm_scheduler.dart';
import 'package:cuadrante/features/alarms/domain/alarm_planner.dart';
import 'package:cuadrante/features/alarms/domain/alarm_settings.dart';
import 'package:cuadrante/features/alarms/domain/alarm_strings.dart';
import 'package:cuadrante/features/alarms/domain/wall_clock.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// A1: AlarmSync hands the renewal notice to the scheduler, publishes what it
// scheduled (the «hasta el…» line) and keeps the background task in step.

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

Schedule _nights(int days) => Schedule(
  shiftTypes: const [_night],
  entries: {
    for (var i = 0; i <= days; i++)
      _today.addDays(i): DayEntry(
        date: _today.addDays(i),
        shiftTypeIds: const ['night'],
      ),
  },
);

const _on = AlarmSettings(
  enabled: true,
  horizonDays: 14,
  byShiftType: {'night': AlarmTypeSettings(enabled: true)},
);

class _ThrowingRenewal implements AlarmRenewalRegistrar {
  @override
  Future<void> setEnabled(bool enabled) async =>
      throw StateError('WorkManager');
}

void main() {
  late FakeAlarmScheduler scheduler;
  late AlarmSettings settings;
  late FakeAlarmRenewal renewal;
  late List<Object> errors;

  AlarmSync makeSync({AlarmRenewalRegistrar? registrar}) => AlarmSync(
    scheduler: scheduler,
    loadSettings: () async => settings,
    readSchedule: () => _nights(60),
    now: () => DateTime(2026, 10, 19, 12),
    strings: _strings,
    onError: (e, _) => errors.add(e),
    renewal: registrar ?? renewal,
  );

  setUp(() {
    scheduler = FakeAlarmScheduler();
    settings = _on;
    renewal = FakeAlarmRenewal();
    errors = [];
  });

  test('a cut plan schedules the renewal notice with the alarms', () async {
    final sync = makeSync();
    addTearDown(sync.dispose);
    await sync.resync();
    final notices = scheduler.scheduled.where(
      (a) => a.kind == AlarmKind.renewal,
    );
    expect(notices, hasLength(1));
    expect(sync.lastPlan!.toSchedule, scheduler.scheduled);
    expect(notices.single.fireDate, _today.addDays(12));
  });

  test('lastPlan and plans tell how far the scheduled alarms reach', () async {
    final sync = makeSync();
    addTearDown(sync.dispose);
    expect(sync.lastPlan, isNull, reason: 'before the first run');
    final emitted = <AlarmPlan>[];
    final sub = sync.plans.listen(emitted.add);
    addTearDown(sub.cancel);

    await sync.resync();
    await Future<void>.delayed(Duration.zero);
    final last = scheduler.scheduled.lastWhere(
      (a) => a.kind != AlarmKind.renewal,
    );
    expect(
      sync.lastPlan!.coveredUntil,
      resolveAlarmInstant(last, defaultAlarmLocation()),
    );
    expect(emitted, hasLength(1));

    // Without the permission nothing is scheduled, and the plan says so.
    scheduler.permission = AlarmPermission.denied;
    await sync.resync();
    await Future<void>.delayed(Duration.zero);
    expect(scheduler.scheduled, isEmpty);
    expect(sync.lastPlan!.coveredUntil, isNull);
    expect(emitted, hasLength(2));
  });

  test('the background renewal follows the switches', () async {
    final sync = makeSync();
    addTearDown(sync.dispose);
    await sync.resync();
    expect(renewal.calls, [true]);

    settings = AlarmSettings.disabled;
    await sync.resync();
    expect(renewal.calls, [true, false]);
    expect(
      scheduler.scheduled.where((a) => a.kind == AlarmKind.renewal),
      isEmpty,
      reason: 'alarms off: no notice either',
    );

    // Not the permission: a background run without it touches nothing.
    settings = _on;
    scheduler.permission = AlarmPermission.denied;
    await sync.resync();
    expect(renewal.calls, [true, false, true]);
  });

  test('a registration error is reported and the alarms stay', () async {
    final sync = makeSync(registrar: _ThrowingRenewal());
    addTearDown(sync.dispose);
    await sync.resync();
    expect(errors.single, isA<StateError>());
    expect(scheduler.scheduled, isNotEmpty);
    expect(sync.lastPlan, isNotNull);
  });

  test('alarmsScheduledUntilProvider follows the runs', () async {
    final sync = makeSync();
    final container = ProviderContainer(
      overrides: [alarmSyncProvider.overrideWithValue(sync)],
    );
    addTearDown(() {
      container.dispose();
      sync.dispose();
    });
    final values = <DateTime?>[];
    container.listen(
      alarmsScheduledUntilProvider,
      (_, next) => values.add(next),
      fireImmediately: true,
    );
    expect(values, [null]);

    await sync.resync();
    await Future<void>.delayed(Duration.zero);
    expect(container.read(alarmsScheduledUntilProvider), isNotNull);
    expect(
      container.read(alarmsScheduledUntilProvider),
      sync.lastPlan!.coveredUntil,
    );

    settings = AlarmSettings.disabled;
    await sync.resync();
    await Future<void>.delayed(Duration.zero);
    expect(container.read(alarmsScheduledUntilProvider), isNull);
  });
}
