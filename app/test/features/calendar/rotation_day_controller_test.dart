import 'package:cuadrante/core/providers.dart';
import 'package:cuadrante/features/calendar/application/schedule_controller.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_storage.dart';

final _now = DateTime(2026, 10, 19, 12);
const _today = CivilDate(2026, 10, 19);

/// The rotation actions of the day detail against a real database: each one
/// is ONE undo step, undo leaves the tables exactly as they were and what is
/// stored always matches what is shown.
///
/// Demo data: an open-ended correturnos (`run-1`, seq 1) since Monday 13 July;
/// 19-23 Oct are nights (days 15-19 of the cycle), 24-25 libre and Monday 26
/// is the first day of the cycle again. 21 Oct is Mañana + Tarde by hand.
void main() {
  late TestStorage storage;
  late ProviderContainer container;

  ScheduleController controller() =>
      container.read(scheduleControllerProvider.notifier);
  ScheduleState state() => container.read(scheduleControllerProvider);
  Schedule schedule() => state().schedule;
  String ids(CivilDate d) => schedule().resolve(d).shiftIds.join('+');
  Future<void> flush() => controller().pendingWrites;

  setUp(() async {
    storage = await TestStorage.open(now: _now);
    addTearDown(storage.close);
    container = ProviderContainer(
      overrides: [
        ...storage.overrides,
        clockProvider.overrideWithValue(() => _now),
      ],
    );
    addTearDown(() async {
      await container.read(scheduleControllerProvider.notifier).pendingWrites;
      container.dispose();
    });
  });

  List<PatternRun> byId(List<PatternRun> runs) =>
      [...runs]..sort((a, b) => a.id.compareTo(b.id));

  /// The schedule the database holds now, as a fresh start would load it.
  Future<Schedule> stored() async {
    await flush();
    return (await storage.withReloadedSnapshot()).snapshot.schedule;
  }

  test('restartRunAt: one step, the cycle starts over, hand-made days stay, '
      'undo restores the tables', () async {
    final before = await dumpTables(storage.database);
    final runsBefore = schedule().runs;
    final date = _today.addDays(1); // Tue 20 Oct, a night
    final handMade = _today.addDays(2);
    expect(ids(handMade), 'morning+afternoon');

    final step = await controller().restartRunAt(date);
    expect(step, isNotNull);

    expect(schedule().runs, hasLength(2));
    final old = schedule().runs.firstWhere((r) => r.id == 'run-1');
    expect(old.endDate, _today);
    final fresh = schedule().runs.firstWhere((r) => r.id != 'run-1');
    expect(fresh.patternId, 'correturnos');
    expect(fresh.startDate, date);
    expect(fresh.endDate, isNull);
    expect(fresh.stepOffset, 0);
    expect(fresh.seq, 2);

    expect(ids(_today), 'night', reason: 'the days before do not change');
    expect(ids(date), 'morning', reason: 'the first day of the cycle');
    expect(ids(handMade), 'morning+afternoon', reason: 'changed by hand');
    expect(ids(date.addDays(5)), 'rest');
    expect(state().canUndo, isTrue);

    final saved = await stored();
    expect(byId(saved.runs), byId(schedule().runs));
    expect(saved.entries, schedule().entries);
    expect(state().saveErrors, 0);

    expect(controller().undoIfLast(step!), isTrue);
    expect(schedule().runs, runsBefore);
    expect(state().canUndo, isFalse, reason: 'a single step');
    expect(ids(date), 'night');
    await flush();
    expect(await dumpTables(storage.database), before);
  });

  test('restartRunAt does nothing on the first day of the cycle or '
      'without a rotation', () async {
    final runsBefore = schedule().runs;
    expect(await controller().restartRunAt(_today.addDays(7)), isNull);
    expect(
      await controller().restartRunAt(const CivilDate(2026, 6, 1)),
      isNull,
    );
    expect(schedule().runs, runsBefore);
    expect(state().canUndo, isFalse);
  });

  test('endRunOn: one step, the rotation ends that day, hand-made days '
      'stay, undo restores the tables', () async {
    final before = await dumpTables(storage.database);
    final runsBefore = schedule().runs;
    final date = _today.addDays(1);
    final handMade = _today.addDays(2);

    final step = controller().endRunOn(date);
    expect(step, isNotNull);
    expect(schedule().runs.single.endDate, date);
    expect(schedule().runs.single.seq, 1);
    expect(ids(date), 'night');
    expect(ids(handMade), 'morning+afternoon', reason: 'changed by hand');
    expect(ids(date.addDays(3)), '', reason: 'no rotation after the end');
    expect(schedule().resolve(date.addDays(3)).source, DaySource.none);

    final saved = await stored();
    expect(saved.runs, schedule().runs);
    expect(saved.entries, schedule().entries);

    // Already its last day: nothing more to end.
    expect(controller().endRunOn(date), isNull);

    expect(controller().undoIfLast(step!), isTrue);
    expect(schedule().runs, runsBefore);
    expect(state().canUndo, isFalse, reason: 'a single step');
    await flush();
    expect(await dumpTables(storage.database), before);
  });

  test('resumeRunAt: after the rotation ended it applies again from that '
      'day, on the chosen day of the cycle, as one step', () async {
    final end = _today.addDays(1);
    controller().endRunOn(end);
    await flush();
    final before = await dumpTables(storage.database);
    final runsBefore = schedule().runs;
    final date = _today.addDays(12); // Sat 31 Oct, no rotation now
    final vacation = _today.addDays(8);
    expect(ids(date), '');
    expect(ids(vacation), 'vacation');

    // Day 8 of the correturnos cycle (index 7) is the first Tarde.
    final step = await controller().resumeRunAt(date, stepOffset: 7);
    expect(step, isNotNull);
    expect(schedule().runs, hasLength(2));
    final fresh = schedule().runs.firstWhere((r) => r.id != 'run-1');
    expect(fresh.patternId, 'correturnos');
    expect(fresh.startDate, date);
    expect(fresh.endDate, isNull);
    expect(fresh.stepOffset, 7);
    expect(fresh.seq, 2);
    expect(ids(date), 'afternoon');
    expect(ids(date.addDays(5)), 'rest');
    expect(ids(date.addDays(-1)), '', reason: 'the gap stays empty');
    expect(ids(vacation), 'vacation', reason: 'changed by hand');
    expect(ids(_today), 'night', reason: 'the days before do not change');

    final saved = await stored();
    expect(byId(saved.runs), byId(schedule().runs));
    expect(saved.entries, schedule().entries);
    expect(state().saveErrors, 0);

    expect(controller().undoIfLast(step!), isTrue);
    expect(schedule().runs, runsBefore);
    expect(ids(date), '');
    await flush();
    expect(await dumpTables(storage.database), before);
  });

  test('resumeRunAt does nothing on a day that has a rotation', () async {
    expect(await controller().resumeRunAt(_today), isNull);
    expect(schedule().runs, hasLength(1));
    expect(state().canUndo, isFalse);
  });
}
