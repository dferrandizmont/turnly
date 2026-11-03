import 'package:cuadrante/features/dnd/application/dnd_sync.dart';
import 'package:cuadrante/features/dnd/data/dnd_channel.dart';
import 'package:cuadrante/features/dnd/domain/dnd_settings.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

final _morning = ShiftType(
  id: 'morning',
  code: 'M',
  name: 'Mañana',
  colorValue: 0xFF336699,
  category: ShiftCategory.work,
  startMinute: 6 * 60,
  endMinute: 14 * 60,
);

const _today = CivilDate(2026, 10, 19);

Schedule _schedule({bool withTomorrow = false}) => Schedule(
  shiftTypes: [_morning],
  entries: {
    _today: DayEntry(date: _today, shiftTypeIds: ['morning']),
    if (withTomorrow)
      _today.addDays(1): DayEntry(
        date: _today.addDays(1),
        shiftTypeIds: ['morning'],
      ),
  },
);

DndSettings _on() => const DndSettings(
  enabled: true,
  byShiftType: {'morning': DndTypeSettings(enabled: true)},
);

void main() {
  late tz.Location madrid;

  setUpAll(() {
    tzdata.initializeTimeZones();
    madrid = tz.getLocation('Europe/Madrid');
  });

  DndSync buildSync(
    FakeDndChannel channel, {
    DndSettings? settings,
    Future<int> Function()? horizonDays,
    bool withTomorrow = false,
    void Function(Object error, StackTrace stack)? onError,
  }) => DndSync(
    channel: channel,
    loadSettings: () async => settings ?? _on(),
    readSchedule: () => _schedule(withTomorrow: withTomorrow),
    now: () => tz.TZDateTime(madrid, 2026, 10, 19, 5),
    horizonDays: horizonDays,
    debounce: const Duration(milliseconds: 10),
    onError: onError,
  );

  test('the silence off: the windows are cancelled and nothing is armed', () async {
    final channel = FakeDndChannel();
    final sync = buildSync(channel, settings: DndSettings.disabled);
    await sync.resync();
    expect(channel.cancelCalls, 1);
    expect(channel.replaceCalls, 0);
    expect(sync.lastWindows, isEmpty);
  });

  test('without the permission: the windows are cancelled', () async {
    final channel = FakeDndChannel()..permission = DndPermission.denied;
    final sync = buildSync(channel);
    await sync.resync();
    expect(channel.cancelCalls, 1);
    expect(channel.replaceCalls, 0);
  });

  test('on a platform without the silence: the windows are cancelled', () async {
    final channel = FakeDndChannel()..permission = DndPermission.unsupported;
    final sync = buildSync(channel);
    await sync.resync();
    expect(channel.cancelCalls, 1);
    expect(channel.replaceCalls, 0);
  });

  test('with the permission: the plan reaches the channel', () async {
    final channel = FakeDndChannel();
    final sync = buildSync(channel);
    await sync.resync();
    expect(channel.replaceCalls, 1);
    expect(channel.windows, hasLength(1));
    expect(channel.windows.single.start, tz.TZDateTime(madrid, 2026, 10, 19, 6));
    expect(channel.windows.single.end, tz.TZDateTime(madrid, 2026, 10, 19, 14));
    expect(sync.lastWindows, channel.windows);
    expect(sync.runs, 1);
  });

  test('the horizon of the shift alarms is the one used', () async {
    // With a horizon of one day the shift of tomorrow is inside the window.
    final wide = FakeDndChannel();
    await buildSync(
      wide,
      horizonDays: () async => 1,
      withTomorrow: true,
    ).resync();
    expect(wide.windows, hasLength(2));

    // With a horizon of zero days it is not: only today's shift is.
    final narrow = FakeDndChannel();
    await buildSync(
      narrow,
      horizonDays: () async => 0,
      withTomorrow: true,
    ).resync();
    expect(narrow.windows, hasLength(1));
  });

  test('a run that fails is told about it and the next one works', () async {
    final channel = FakeDndChannel();
    final errors = <Object>[];
    var fail = true;
    final sync = DndSync(
      channel: channel,
      loadSettings: () async {
        if (fail) throw StateError('boom');
        return _on();
      },
      readSchedule: () => _schedule(),
      now: () => tz.TZDateTime(madrid, 2026, 10, 19, 5),
      onError: (error, stack) => errors.add(error),
    );
    await sync.resync();
    expect(errors, hasLength(1));
    expect(channel.replaceCalls, 0);

    fail = false;
    await sync.resync();
    expect(channel.replaceCalls, 1);
  });

  test('the requests are debounced and coalesced', () async {
    final channel = FakeDndChannel();
    final sync = buildSync(channel);
    sync.requestResync();
    sync.requestResync();
    sync.requestResync();
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(channel.replaceCalls, 1);
  });

  test('a disposed sync does nothing', () async {
    final channel = FakeDndChannel();
    final sync = buildSync(channel);
    sync.dispose();
    await sync.resync();
    expect(channel.replaceCalls, 0);
  });
}
