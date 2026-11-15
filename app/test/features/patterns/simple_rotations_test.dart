import 'package:cuadrante/app.dart';
import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/features/calendar/application/schedule_controller.dart';
import 'package:cuadrante/features/patterns/application/pattern_wizard.dart';
import 'package:cuadrante/features/patterns/domain/pattern_application.dart';
import 'package:cuadrante/features/patterns/domain/pattern_catalog.dart';
import 'package:cuadrante/features/patterns/presentation/pattern_wizard_screen.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/real_font.dart';
import '../calendar/harness.dart';

Finder key(String value) => find.byKey(ValueKey(value));

Future<void> tap(WidgetTester tester, String value) async {
  await tester.ensureVisible(key(value));
  await tester.pumpAndSettle();
  await tester.tap(key(value));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await initializeLocale();
    expect(await loadRoboto(), isTrue);
  });

  test('choosing a work shift preserves stored rotations', () {
    final preset = patternPresetById('2x2');
    final original = preset.materialize({'morning': 'morning', 'rest': 'rest'});
    const start = CivilDate(2026, 10, 1);
    final schedule = Schedule(
      shiftTypes: [for (final t in shiftTemplates) t.toShiftType(t.key)],
      patterns: [original],
      runs: [
        PatternRun(
          id: 'old-run',
          patternId: original.id,
          startDate: start,
          seq: 1,
        ),
      ],
    );
    final chosen = presetPattern(schedule, preset, workShiftId: 'night');
    expect(chosen.id, isNot(original.id));
    expect(chosen.steps, [
      ['night'],
      ['night'],
      ['rest'],
      ['rest'],
    ]);
    expect(schedule.patternById('2x2'), original);
    final applied = planPatternApplication(
      schedule,
      PatternRequest(pattern: chosen, from: start.addDays(8)),
      seq: 2,
    ).schedule;
    expect(applied.resolve(start).shifts.single.id, 'morning');
    expect(applied.resolve(start.addDays(8)).shifts.single.id, 'night');
    expect(applied.resolve(start.addDays(10)).shifts.single.id, 'rest');
  });

  test('applying the same rotation and shift twice stores one pattern', () {
    final preset = patternPresetById('2x2');
    final base = Schedule(
      shiftTypes: [for (final t in shiftTemplates) t.toShiftType(t.key)],
    );
    var schedule = base;
    for (var i = 0; i < 2; i++) {
      final chosen = presetPattern(schedule, preset, workShiftId: 'night');
      expect(chosen.id, '2x2-night');
      schedule = planPatternApplication(
        schedule,
        PatternRequest(
          pattern: chosen,
          from: const CivilDate(2026, 10, 1).addDays(i * 8),
        ),
        seq: i + 1,
      ).schedule;
    }
    expect(schedule.patterns.where((p) => p.id == '2x2-night'), hasLength(1));
    expect(schedule.runs, hasLength(2));
    expect(isCatalogPatternId('2x2-night'), isTrue);
    expect(isCatalogPatternId('custom-x'), isFalse);
    expect(
      patternDisplayName(schedule, schedule.patternById('2x2-night')!),
      '${preset.name} · ${schedule.shiftTypeById('night')!.name}',
    );
  });

  for (final (id, workDays) in [('2x2', 2), ('3x1', 3)]) {
    testWidgets('$id: wizard date and work shift, 360 dp at x2', (
      tester,
    ) async {
      await pumpCalendar(tester, size: const Size(360, 800), textScale: 2);
      await enterPaintMode(tester);
      await tester.tap(key('paint-pattern'));
      await tester.pumpAndSettle();
      await tap(tester, 'pattern-card-$id');
      await tap(tester, 'pattern-next');
      expect(
        find.text(
          'Tu rotación empieza el lunes 19 de octubre y se repite desde ese día.',
        ),
        findsOneWidget,
      );
      await tap(tester, 'pattern-start-date');
      await tester.tap(
        find.descendant(
          of: find.byType(DatePickerDialog),
          matching: find.text('20'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .descendant(
              of: find.byType(DatePickerDialog),
              matching: find.byType(TextButton),
            )
            .last,
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Tu rotación empieza el martes 20 de octubre y se repite desde ese día.',
        ),
        findsOneWidget,
      );
      await tap(tester, 'rotation-work-afternoon');
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CuadranteApp)),
      );
      final screen = tester.widget<PatternWizardScreen>(
        find.byType(PatternWizardScreen),
      );
      final args = (start: screen.start, shiftId: screen.shiftId);
      // The demo data has manual days in this week; replace them so only the
      // rotation is left to check.
      container
          .read(patternWizardProvider(args).notifier)
          .setClearOverrides(true);
      final preview = container.read(patternPreviewProvider(args))!;
      const start = CivilDate(2026, 10, 20);
      for (var i = 0; i < 8; i++) {
        expect(
          preview.schedule.resolve(start.addDays(i)).shifts.single.id,
          i % 4 < workDays ? 'afternoon' : 'rest',
        );
      }
      expect(tester.takeException(), isNull);
      await tap(tester, 'pattern-next');
      await tap(tester, 'pattern-apply');
      final controller = container.read(scheduleControllerProvider.notifier);
      await tester.runAsync(() => controller.pendingWrites);
      final saved = container.read(scheduleControllerProvider).schedule;
      expect(saved.resolve(start).shifts.single.id, 'afternoon');
      expect(saved.resolve(start.addDays(workDays)).shifts.single.id, 'rest');
      expect(tester.takeException(), isNull);
    });
  }
}
