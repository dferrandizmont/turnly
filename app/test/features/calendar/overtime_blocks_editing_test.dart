import 'package:cuadrante/core/providers.dart';
import 'package:cuadrante/features/calendar/application/schedule_controller.dart';
import 'package:cuadrante/features/calendar/application/selection_controller.dart';
import 'package:cuadrante/features/calendar/domain/range_editing.dart';
import 'package:cuadrante/features/calendars/domain/calendar.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_storage.dart';

final _now = DateTime(2026, 10, 19, 12);

// Demo data around Monday 19 Oct 2026: 19-23 Oct Noche, 24-25 Libre, 26-30
// Mañana by the rotation.
const _oct19 = CivilDate(2026, 10, 19);
const _oct24 = CivilDate(2026, 10, 24);
const _oct30 = CivilDate(2026, 10, 30);
const _nov9 = CivilDate(2026, 11, 9);

/// The blocks of extra hours (schema v7) travel with the day like its note:
/// copy, paste, duplicate, repeat, cut and «Borrar el día por completo»,
/// through the real controller and the real database.
void main() {
  late TestStorage storage;
  late ProviderContainer container;

  ScheduleController controller() =>
      container.read(scheduleControllerProvider.notifier);
  Schedule schedule() => container.read(scheduleControllerProvider).schedule;
  DayEntry? entry(CivilDate d) => schedule().entries[d];
  List<OvertimeBlock> blocks(CivilDate d) => entry(d)?.overtimeBlocks ?? [];

  OvertimeBlock block(CivilDate date, {String id = 'a', int start = 360}) =>
      OvertimeBlock(
        id: id,
        date: date,
        typeId: overtimeTypeId,
        startMinute: start,
        endMinute: start + 90,
        breakMinutes: 15,
        note: 'Relevo',
      );

  Future<void> expectStoredEqualsMemory() async {
    await controller().pendingWrites;
    final stored = (await storage.repository.load(mainCalendarId)).schedule;
    expectSameSchedule(stored, schedule());
    for (final date in [_oct19, _oct24, _oct30, _nov9]) {
      expect(stored.entries[date]?.overtimeBlocks ?? [], blocks(date));
    }
  }

  setUp(() async {
    final base = await TestStorage.open(now: _now);
    addTearDown(base.close);
    storage = base;
    container = ProviderContainer(
      overrides: [
        ...storage.overrides,
        clockProvider.overrideWithValue(() => _now),
      ],
    );
    addTearDown(() async {
      await controller().pendingWrites;
      container.dispose();
    });
    controller().setOvertimeBlocks(_oct19, [
      block(_oct19),
      block(_oct19, id: 'b', start: 1200),
    ]);
    await controller().pendingWrites;
  });

  test('«Duplicar en otro día» takes the blocks to that day', () async {
    controller().copyDay(_oct19, _oct30);
    expect(blocks(_oct30), [
      block(_oct30),
      block(_oct30, id: 'b', start: 1200),
    ]);
    expect(blocks(_oct19), hasLength(2));
    await expectStoredEqualsMemory();
  });

  test('pasting with the notes brings them; without, leaves the day as it '
      'was', () async {
    final clip = DayClipboard.capture(schedule(), [_oct19]);
    controller().pasteDays(clip, _oct30);
    expect(blocks(_oct30), isEmpty);
    controller().pasteDays(clip, _oct30, includeNotes: true);
    expect(blocks(_oct30), hasLength(2));
    expect(blocks(_oct30).first.date, _oct30);
    await expectStoredEqualsMemory();
  });

  test('repeating with the notes copies them to every repetition', () async {
    controller().repeatDays([_oct19], 1, includeNotes: true);
    expect(blocks(_oct19.addDays(1)), hasLength(2));
    await expectStoredEqualsMemory();
  });

  test('cut + paste with the notes moves them', () async {
    final selection = container.read(selectionControllerProvider.notifier);
    selection.select([_oct19]);
    final result = selection.cut()!;
    expect(blocks(_oct19), isEmpty);
    await expectStoredEqualsMemory();
    controller().pasteDays(result.clip, _nov9, includeNotes: true);
    expect(blocks(_nov9), [block(_nov9), block(_nov9, id: 'b', start: 1200)]);
    await expectStoredEqualsMemory();
  });

  test('«Borrar día» (shifts only) keeps them; «Borrar el día por completo» '
      'takes them away; undo brings them back', () async {
    controller().clearDays([_oct19]);
    expect(blocks(_oct19), hasLength(2));
    controller().clearDayCompletely(_oct19);
    expect(blocks(_oct19), isEmpty);
    await expectStoredEqualsMemory();
    controller().undo();
    expect(blocks(_oct19), hasLength(2));
    await expectStoredEqualsMemory();
  });

  test(
    'a day with only blocks is kept, and gone with its last block',
    () async {
      controller().setOvertimeBlocks(_oct24, [block(_oct24)]);
      await expectStoredEqualsMemory();
      expect(entry(_oct24)!.isEmpty, isFalse);
      controller().setOvertimeBlocks(_oct24, const []);
      expect(entry(_oct24), isNull);
      await expectStoredEqualsMemory();
    },
  );
}
