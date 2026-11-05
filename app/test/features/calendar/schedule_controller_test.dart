import 'package:cuadrante/core/providers.dart';
import 'package:cuadrante/features/calendar/application/paint_controller.dart';
import 'package:cuadrante/features/calendar/application/schedule_controller.dart';
import 'package:cuadrante/features/schedule/data/demo_schedule.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/features/shift_types/domain/shift_color_presets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_storage.dart';

const today = CivilDate(2026, 10, 19);

String ids(Schedule s, CivilDate d) => s.resolve(d).shiftIds.join('+');

void main() {
  late ProviderContainer container;

  setUp(() async {
    final storage = await TestStorage.open(now: DateTime(2026, 10, 19));
    container = ProviderContainer(
      overrides: [
        ...storage.overrides,
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 19)),
      ],
    );
    addTearDown(() async {
      // Let queued writes finish before the database goes away.
      await container.read(scheduleControllerProvider.notifier).pendingWrites;
      container.dispose();
      await storage.close();
    });
  });

  ScheduleController controller() =>
      container.read(scheduleControllerProvider.notifier);
  ScheduleState state() => container.read(scheduleControllerProvider);
  Schedule schedule() => state().schedule;

  group('demo schedule', () {
    test('correturnos from the Monday three months back, open ended', () {
      final s = buildDemoSchedule(today);
      final run = s.runs.single;
      expect(run.patternId, 'correturnos');
      expect(run.startDate, const CivilDate(2026, 7, 13));
      expect(run.startDate.weekday, DateTime.monday);
      expect(run.endDate, isNull);
      expect(s.patterns.map((p) => p.id), contains('24x72'));
      expect(s.shiftTypes, hasLength(shiftTemplates.length));
    });

    test('rotation and overrides around today', () {
      final s = buildDemoSchedule(today);
      expect(ids(s, today), 'night');
      expect(ids(s, today.addDays(5)), 'rest');
      expect(ids(s, today.addDays(2)), 'morning+afternoon');
      expect(s.resolve(today.addDays(3)).isEmpty, isTrue);
      expect(ids(s, today.addDays(8)), 'vacation');
      expect(ids(s, today.addDays(9)), 'vacation');
      final noted = s.resolve(today.addDays(1));
      expect(noted.note, isNotNull);
      expect(noted.source, DaySource.pattern);
    });

    test('is a function of today', () {
      final a = buildDemoSchedule(const CivilDate(2027, 1, 31));
      // 31 Jan - 3 months = Sat 31 Oct, so the Monday before is 26 Oct.
      expect(a.runs.single.startDate, const CivilDate(2026, 10, 26));
    });
  });

  group('strokes', () {
    final d1 = today.addDays(5); // Saturday, rest
    final d2 = today.addDays(6); // Sunday, rest
    final d3 = today.addDays(7); // Monday, morning

    test('starts without history', () {
      expect(state().canUndo, isFalse);
      expect(state().canRedo, isFalse);
    });

    test('a stroke paints several days live, then one step', () {
      final c = controller();
      c.beginStroke(const PaintTool.replace('afternoon'));
      expect(c.paintDay(d1), isTrue);
      expect(c.paintDay(d2), isTrue);
      expect(c.paintDay(d3), isTrue);
      // Live: painted but not yet in the history.
      expect(
        [d1, d2, d3].map((d) => ids(schedule(), d)),
        everyElement('afternoon'),
      );
      expect(state().canUndo, isFalse);

      c.endStroke();
      expect(state().canUndo, isTrue);
      expect(
        [d1, d2, d3].map((d) => ids(schedule(), d)),
        everyElement('afternoon'),
      );
    });

    test('one undo reverts the whole stroke, redo reapplies it', () {
      final before = [d1, d2, d3].map((d) => ids(schedule(), d)).toList();
      final c = controller();
      c.beginStroke(const PaintTool.replace('night'));
      c.paintDay(d1);
      c.paintDay(d2);
      c.paintDay(d3);
      c.endStroke();

      c.undo();
      expect([d1, d2, d3].map((d) => ids(schedule(), d)), before);
      expect(state().canUndo, isFalse);
      expect(state().canRedo, isTrue);

      c.redo();
      expect(
        [d1, d2, d3].map((d) => ids(schedule(), d)),
        everyElement('night'),
      );
      expect(state().canUndo, isTrue);
      expect(state().canRedo, isFalse);
    });

    test('painting the same day twice in a stroke counts once', () {
      final c = controller();
      c.beginStroke(const PaintTool.replace('night'));
      expect(c.paintDay(d1), isTrue);
      expect(c.paintDay(d1), isFalse);
      c.endStroke();
      c.undo();
      expect(state().canUndo, isFalse);
    });

    test('a tap is a stroke of one day', () {
      final c = controller();
      c.beginStroke(const PaintTool.replace('guard24'));
      c.paintDay(d1);
      c.endStroke();
      expect(ids(schedule(), d1), 'guard24');
      c.undo();
      expect(ids(schedule(), d1), 'rest');
    });

    test('a new stroke after undo drops the redo history', () {
      final c = controller();
      c.beginStroke(const PaintTool.replace('night'));
      c.paintDay(d1);
      c.endStroke();
      c.undo();
      expect(state().canRedo, isTrue);

      c.beginStroke(const PaintTool.replace('morning'));
      c.paintDay(d2);
      c.endStroke();
      expect(state().canRedo, isFalse);
    });

    test('add ("Doblar") keeps the existing shifts', () {
      final c = controller();
      c.beginStroke(const PaintTool.add('morning'));
      c.paintDay(today); // night by rotation
      c.paintDay(today.addDays(2)); // already morning+afternoon
      c.endStroke();
      expect(ids(schedule(), today), 'night+morning');
      expect(ids(schedule(), today.addDays(2)), 'morning+afternoon');
      c.undo();
      expect(ids(schedule(), today), 'night');
    });

    test('add over a lone «Libre» replaces it; over several it does not', () {
      final c = controller();
      expect(ids(schedule(), d1), 'rest');
      c.beginStroke(const PaintTool.add('morning', replaceRest: true));
      c.paintDay(d1); // «Libre» by rotation
      c.endStroke();
      expect(ids(schedule(), d1), 'morning');
      c.undo();
      expect(ids(schedule(), d1), 'rest');

      c.setDayShifts(d1, ['rest', 'night']);
      c.beginStroke(const PaintTool.add('morning', replaceRest: true));
      c.paintDay(d1);
      c.endStroke();
      expect(ids(schedule(), d1), 'rest+night+morning');
    });

    test('replace overwrites the shifts of the day', () {
      final c = controller();
      c.beginStroke(const PaintTool.replace('vacation'));
      c.paintDay(today.addDays(2));
      c.endStroke();
      expect(ids(schedule(), today.addDays(2)), 'vacation');
    });

    test('eraser empties days, undo brings them back', () {
      final c = controller();
      c.beginStroke(const PaintTool.erase());
      c.paintDay(today);
      c.paintDay(d3);
      c.endStroke();
      expect(schedule().resolve(today).isEmpty, isTrue);
      expect(schedule().resolve(d3).isEmpty, isTrue);
      c.undo();
      expect(ids(schedule(), today), 'night');
      expect(ids(schedule(), d3), 'morning');
    });

    test('painting what the rotation already gives leaves no step', () {
      final c = controller();
      c.beginStroke(const PaintTool.replace('night'));
      c.paintDay(today);
      c.endStroke();
      expect(state().canUndo, isFalse);
    });

    test('paintDay without a stroke does nothing', () {
      expect(controller().paintDay(d1), isFalse);
      expect(ids(schedule(), d1), 'rest');
    });

    test('beginStroke closes an unfinished stroke', () {
      final c = controller();
      c.beginStroke(const PaintTool.replace('night'));
      c.paintDay(d1);
      c.beginStroke(const PaintTool.replace('morning'));
      c.paintDay(d2);
      c.endStroke();
      c.undo();
      expect(ids(schedule(), d2), 'rest');
      expect(ids(schedule(), d1), 'night');
      c.undo();
      expect(ids(schedule(), d1), 'rest');
    });
  });

  group('paint mode', () {
    PaintState paint() => container.read(paintControllerProvider);
    PaintController p() => container.read(paintControllerProvider.notifier);

    test('defaults to the first work shift, replace, off', () {
      expect(paint().active, isFalse);
      expect(paint().shiftTypeId, 'morning');
      expect(paint().doubling, isFalse);
      expect(p().tool, const PaintTool.replace('morning'));
    });

    test('"Doblar" switches replace and add', () {
      p().selectShift('night');
      expect(p().tool, const PaintTool.replace('night'));
      p().toggleDoubling();
      expect(p().tool, const PaintTool.add('night', replaceRest: true));
      p().toggleDoubling();
      expect(p().tool, const PaintTool.replace('night'));
    });

    test(
      'doubling with an absence keeps «Libre»; with work it replaces it',
      () {
        p().toggleDoubling();
        p().selectShift('vacation');
        expect(p().tool, const PaintTool.add('vacation'));
        p().selectShift('guard24');
        expect(p().tool, const PaintTool.add('guard24', replaceRest: true));
      },
    );

    test('the eraser overrides doubling', () {
      p().toggleDoubling();
      p().selectEraser();
      expect(paint().erasing, isTrue);
      expect(p().tool, const PaintTool.erase());
      p().selectShift('morning');
      expect(p().tool, const PaintTool.add('morning', replaceRest: true));
    });

    test('toggle enters and leaves; leaving closes the open stroke', () {
      p().toggle();
      expect(paint().active, isTrue);
      final c = controller();
      c.beginStroke(p().tool);
      c.paintDay(today.addDays(5));
      p().toggle();
      expect(paint().active, isFalse);
      expect(c.strokeActive, isFalse);
      expect(state().canUndo, isTrue);
    });
  });

  group('the undo of a colour preset', () {
    test('puts only the colour back, not a later edit (L2)', () async {
      final c = controller();
      // A whole set of colours is applied: it hands back the types as they
      // were for the «Deshacer» of the snack bar.
      final previous = c.applyColorPreset(shiftColorPresets.first);
      expect(previous, isNotNull);
      expect(previous, isNotEmpty);
      await c.pendingWrites;

      // The person then edits one of those types: a name (and hours).
      final edited = previous!.first;
      final afterPreset = c.state.schedule.shiftTypeById(edited.id)!;
      c.saveShiftType(
        afterPreset.copyWith(name: 'Mi turno', startMinute: 1, endMinute: 2),
      );
      await c.pendingWrites;

      // «Deshacer»: the colour goes back, the name and the hours stay.
      c.restoreShiftTypes(previous);
      await c.pendingWrites;

      final restored = c.state.schedule.shiftTypeById(edited.id)!;
      expect(restored.name, 'Mi turno', reason: 'the later edit is kept');
      expect(restored.startMinute, 1);
      expect(restored.endMinute, 2);
      expect(
        restored.colorValue,
        edited.colorValue,
        reason: 'the colour is back',
      );
    });
  });
}
