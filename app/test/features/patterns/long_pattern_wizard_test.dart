import 'package:cuadrante/app.dart';
import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/core/theme/spacing.dart';
import 'package:cuadrante/core/widgets/buttons.dart';
import 'package:cuadrante/features/calendar/application/schedule_controller.dart';
import 'package:cuadrante/features/calendar/presentation/day_cell.dart';
import 'package:cuadrante/features/calendars/domain/calendar.dart';
import 'package:cuadrante/features/schedule/data/schedule_repository.dart';
import 'package:cuadrante/features/patterns/application/pattern_wizard.dart';
import 'package:cuadrante/features/patterns/domain/pattern_blocks.dart';
import 'package:cuadrante/features/patterns/domain/weeks_per_shift.dart';
import 'package:cuadrante/features/patterns/presentation/mini_month.dart';
import 'package:cuadrante/features/patterns/presentation/pattern_wizard_screen.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'dart:ui' show Tristate;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/real_font.dart';
import '../../support/text_lines.dart';
import '../calendar/harness.dart';

Finder _key(String value) => find.byKey(ValueKey(value));
ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(CuadranteApp)));
PatternWizardArgs _args(WidgetTester tester) {
  final screen = tester.widget<PatternWizardScreen>(
    find.byType(PatternWizardScreen),
  );
  return PatternWizardArgs(start: screen.start, shiftId: screen.shiftId);
}

PatternWizardController _wizard(WidgetTester tester) =>
    _container(tester).read(patternWizardProvider(_args(tester)).notifier);
PatternWizardState _state(WidgetTester tester) =>
    _container(tester).read(patternWizardProvider(_args(tester)));
Schedule _schedule(WidgetTester tester) =>
    _container(tester).read(scheduleControllerProvider).schedule;

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _open(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double scale = 1,
  Brightness brightness = Brightness.light,
  Future<void> Function(ScheduleRepository repository)? prepare,
}) async {
  await pumpCalendar(
    tester,
    size: size,
    textScale: scale,
    brightness: brightness,
    prepare: prepare,
  );
  await enterPaintMode(tester);
  await _tap(tester, _key('paint-pattern'));
}

Future<void> _template63(WidgetTester tester) async {
  await _tap(tester, _key('pattern-card-weeks-per-shift'));
  for (final id in ['morning', 'night', 'afternoon']) {
    await _tap(tester, _key('weeks-shift-$id'));
  }
  for (final id in ['morning', 'night', 'afternoon']) {
    await _tap(tester, _key('weeks-plus-$id'));
    await _tap(tester, _key('weeks-plus-$id'));
  }
}

List<CivilDate> _months(WidgetTester tester) => [
  for (final month in tester.widgetList<MiniMonth>(find.byType(MiniMonth)))
    month.month,
];
ResolvedDay _previewDay(WidgetTester tester, CivilDate date) =>
    tester.widget<DayCell>(_key('preview-${date.toIso()}')).day;

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeLocale();
    expect(await loadRoboto(), isTrue);
  });

  for (final (size, scale) in [
    (const Size(915, 412), 1.0),
    (const Size(412, 915), 1.5),
    (const Size(412, 915), 2.0),
    (const Size(360, 640), 2.0),
    (const Size(640, 360), 1.5),
    (const Size(1280, 800), 1.0),
    (const Size(800, 1280), 1.0),
  ]) {
    testWidgets('63-day open block stays reachable at $size x$scale', (
      tester,
    ) async {
      await _open(tester, size: size, scale: scale);
      await _tap(tester, _key('pattern-create-own'));
      _wizard(tester).replaceBlocks([
        for (final id in ['morning', 'night', 'afternoon'])
          PatternBlock(shiftIds: [id], days: 21),
      ]);
      _wizard(tester).showBlock(1);
      await tester.pumpAndSettle();
      final viewport = tester.getRect(_key('pattern-step-choose'));
      final fixed = find
          .descendant(
            of: _key('pattern-step-choose'),
            matching: _key('builder-palette'),
          )
          .evaluate()
          .isEmpty;
      if (fixed) {
        expect(
          viewport.height,
          greaterThanOrEqualTo(Sp.touch * 4),
          reason: 'a fixed palette must leave room to edit the sequence',
        );
      } else {
        expect(
          find.descendant(
            of: _key('builder-palette'),
            matching: find.byType(Scrollable),
          ),
          findsNothing,
          reason: 'the palette joins the page scroll',
        );
      }
      final scrollable = find
          .descendant(
            of: _key('pattern-step-choose'),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.dragFrom(
        Offset(viewport.left + Sp.xs, viewport.center.dy),
        const Offset(0, -Sp.touch),
      );
      await tester.pumpAndSettle();
      expect(
        tester.state<ScrollableState>(scrollable).position.pixels,
        greaterThan(0),
        reason: 'a swipe must scroll the sequence',
      );
      final lastShift = _container(tester)
          .read(scheduleControllerProvider)
          .palette
          .last
          .id;
      final lastPuck = _key('builder-add-$lastShift');
      for (final target in [
        _key('builder-length'),
        _key('builder-block-1'),
        _key('block-days-21'),
        _key('block-options'),
        _key('builder-cycle-offset-62'),
        lastPuck,
      ]) {
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        expect(target.hitTestable(), findsOneWidget);
        final rect = tester.getRect(target);
        expect(rect.top, greaterThanOrEqualTo(viewport.top));
        expect(
          rect.bottom,
          lessThanOrEqualTo(
            fixed && target == lastPuck
                ? tester.getTopLeft(_key('pattern-next')).dy
                : viewport.bottom,
          ),
        );
        expect(tester.takeException(), isNull);
      }
      expect(find.text('3 semanas'), findsOneWidget);
      expect(_state(tester).draft, hasLength(63));
    });
  }

  for (final exit in ['system', 'app-bar', 'builder']) {
    testWidgets('$exit back asks before discarding an edited sequence', (
      tester,
    ) async {
      await _open(tester);
      await _tap(tester, _key('pattern-create-own'));
      await _tap(tester, _key('builder-add-morning'));
      Future<void> back() async {
        if (exit == 'system') {
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
        } else {
          await _tap(
            tester,
            exit == 'builder' ? _key('builder-back') : find.byType(BackButton),
          );
        }
      }

      await back();
      expect(find.text('¿Descartar la secuencia?'), findsOneWidget);
      await _tap(tester, find.text('Seguir editando'));
      expect(_state(tester).draft, [
        ['morning'],
      ]);
      await back();
      await _tap(tester, find.text('Descartar'));
      expect(find.byType(AlertDialog), findsNothing);
      expect(_key('builder-name'), findsNothing);
      if (exit == 'builder') {
        expect(find.byType(PatternWizardScreen), findsOneWidget);
        await _tap(tester, _key('pattern-create-own'));
        expect(_state(tester).draft, isEmpty);
      } else {
        expect(find.byType(PatternWizardScreen), findsNothing);
      }
    });
  }

  for (final exit in ['system', 'app-bar']) {
    Future<void> back(WidgetTester tester) async {
      if (exit == 'system') {
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
      } else {
        await _tap(tester, find.byType(BackButton));
      }
    }

    for (final edit in ['sequence', 'adjust-by-hand', 'mode-only']) {
      testWidgets('$exit back asks before discarding weeks template $edit', (
        tester,
      ) async {
        await _open(tester);
        final before = _schedule(tester);
        await _tap(tester, _key('pattern-card-weeks-per-shift'));
        if (edit == 'mode-only') {
          await _tap(tester, _key('weeks-mode-weekdays'));
        } else {
          await _tap(tester, _key('weeks-shift-morning'));
          await _tap(tester, _key('weeks-plus-morning'));
          if (edit == 'adjust-by-hand') {
            await _tap(tester, _key('weeks-adjust'));
            expect(_state(tester).building, isTrue);
          }
        }
        final draft = _state(tester).draft;
        final mode = _state(tester).weekMode;

        await back(tester);
        expect(find.text('¿Descartar la secuencia?'), findsOneWidget);
        await _tap(tester, find.text('Seguir editando'));
        expect(_state(tester).draft, draft);
        expect(_state(tester).weekMode, mode);
        await back(tester);
        await _tap(tester, find.text('Descartar'));
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(PatternWizardScreen), findsNothing);
        expect(_schedule(tester), before);
      });
    }

    for (final reverted in [false, true]) {
      testWidgets(
        '$exit back leaves weeks template without changes (reverted: $reverted)',
        (tester) async {
          await _open(tester);
          await _tap(tester, _key('pattern-card-weeks-per-shift'));
          if (reverted) {
            await _tap(tester, _key('weeks-shift-morning'));
            await _tap(tester, _key('weeks-mode-weekdays'));
            await _tap(tester, _key('weeks-shift-morning'));
            await _tap(tester, _key('weeks-mode-allDays'));
          }
          await back(tester);
          expect(find.byType(AlertDialog), findsNothing);
          expect(find.byType(PatternWizardScreen), findsNothing);
        },
      );
    }
  }

  testWidgets('unchanged sequence and undone edits leave without a dialog', (
    tester,
  ) async {
    await _open(tester);
    await _tap(tester, _key('pattern-create-own'));
    await _tap(tester, _key('builder-add-morning'));
    _wizard(tester).undoDraft();
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(PatternWizardScreen), findsNothing);
  });

  testWidgets('an unchanged copy exits cleanly; changing only its name asks', (
    tester,
  ) async {
    await _open(tester);
    final original = _schedule(tester).patternById('correturnos')!;
    _wizard(tester).editAsCopy(original);
    await tester.pumpAndSettle();
    // Expanding a block is not an edit to the sequence.
    _wizard(tester).showBlock(0);
    await tester.pumpAndSettle();
    await _tap(tester, _key('builder-back'));
    expect(find.byType(AlertDialog), findsNothing);
    _wizard(tester).editAsCopy(original);
    await tester.pumpAndSettle();
    await tester.ensureVisible(_key('builder-name'));
    await tester.enterText(_key('builder-name'), 'Mi secuencia');
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('¿Descartar la secuencia?'), findsOneWidget);
    await _tap(tester, find.text('Seguir editando'));
    expect(_state(tester).draft, original.steps);
    expect(_state(tester).draftName, 'Mi secuencia');
    _wizard(tester).setName(original.name);
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(PatternWizardScreen), findsNothing);
  });

  testWidgets('rapid triple Apply cannot undo or apply a rotation twice', (
    tester,
  ) async {
    await _open(tester);
    await _tap(tester, _key('pattern-create-own'));
    await _tap(tester, _key('builder-add-morning'));
    await _tap(tester, _key('pattern-next'));
    await _tap(tester, _key('pattern-next'));
    final before = _schedule(tester).runs.length;
    final apply = tester.getRect(_key('pattern-apply'));
    // The right end of Apply overlaps the next screen's snackbar action.
    final point = Offset(apply.right - 24, apply.center.dy);
    final provider = patternWizardProvider(_args(tester));
    final container = _container(tester);
    for (var i = 0; i < 3; i++) {
      await tester.tapAt(point);
      await tester.runAsync(
        () => container.read(scheduleControllerProvider.notifier).pendingWrites,
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        container.read(provider).applying,
        isTrue,
        reason: 'keep Apply disabled until the burst of taps has ended',
      );
      expect(
        tester.widget<PrimaryButton>(_key('pattern-apply')).onPressed,
        isNull,
      );
    }
    await tester.pumpAndSettle();
    expect(_schedule(tester).runs, hasLength(before + 1));
    expect(find.byType(PatternWizardScreen), findsNothing);
    // Undo remains usable once the burst has ended.
    await _tap(tester, find.widgetWithText(SnackBarAction, 'Deshacer'));
    expect(_schedule(tester).runs, hasLength(before));
  });

  testWidgets(
    'palette semantics tap adds a block and respects the cycle limit',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await _open(tester);
      await _tap(tester, _key('pattern-create-own'));
      final puck = _key('builder-add-morning');
      await tester.ensureVisible(puck);
      await tester.pumpAndSettle();
      final label = tester.getSemantics(puck).label;
      tester.semantics.performAction(
        find.semantics.byLabel(label),
        SemanticsAction.tap,
      );
      await tester.pumpAndSettle();
      expect(_state(tester).draft, [
        ['morning'],
      ]);
      await tester.ensureVisible(_key('builder-block-0'));
      await tester.pumpAndSettle();
      final block = tester
          .getSemantics(_key('builder-block-0'))
          .getSemanticsData();
      expect(block.flagsCollection.isButton, isTrue);
      expect(block.flagsCollection.isExpanded, Tristate.isTrue);
      expect(block.hasAction(SemanticsAction.tap), isTrue);
      _wizard(tester).replaceBlocks([
        PatternBlock(shiftIds: ['morning'], days: 371),
      ]);
      await tester.pumpAndSettle();
      await tester.ensureVisible(puck);
      await tester.pumpAndSettle();
      final full = tester.getSemantics(puck).getSemanticsData();
      expect(full.hasAction(SemanticsAction.tap), isFalse);
      expect(_state(tester).draft, hasLength(371));
      semantics.dispose();
    },
  );

  testWidgets(
    'tap order, renumbering, per-shift counts and live 63-day cycle',
    (tester) async {
      await _open(tester);
      expect(
        tester.getTopLeft(_key('pattern-card-weeks-per-shift')).dy,
        lessThan(tester.getTopLeft(_key('pattern-card-correturnos')).dy),
      );
      await _template63(tester);
      expect(_state(tester).weekShiftIds, ['morning', 'night', 'afternoon']);
      expect(_state(tester).draft, hasLength(63));
      expect(_key('weeks-cycle-offset-62'), findsOneWidget);
      for (final mode in WeeksPerShiftMode.values) {
        await _tap(tester, _key('weeks-mode-${mode.name}'));
        expect(
          _state(tester).draft,
          weeksPerShift(
            shiftIds: ['morning', 'night', 'afternoon'],
            weeks: [3, 3, 3],
            mode: mode,
            restShiftId: 'rest',
          ),
        );
      }
      await _tap(tester, _key('weeks-shift-night'));
      expect(_state(tester).weekShiftIds, ['morning', 'afternoon']);
      expect(
        tester.widget<Text>(_key('weeks-order-afternoon')).data,
        'Orden: 2',
      );
      await _tap(tester, _key('weeks-shift-night'));
      expect(_state(tester).weekShiftIds, ['morning', 'afternoon', 'night']);
      expect(_state(tester).weekCounts, [3, 3, 1]);
      expect(
        tester.widget<IconButton>(_key('weeks-minus-night')).onPressed,
        isNull,
      );
      final wizard = _wizard(tester);
      expect(wizard.setWeekCount(2, 8), isTrue);
      await tester.pumpAndSettle();
      expect(
        tester.widget<IconButton>(_key('weeks-plus-night')).onPressed,
        isNull,
      );
      expect(wizard.setWeekCount(2, 9), isFalse);
      // Many work types can never expand past the builder's 371-day limit.
      for (var i = 0; i < 5; i++) {
        wizard.toggleWeekShift('work-$i');
      }
      for (var i = 0; i < _state(tester).weekCounts.length; i++) {
        wizard.setWeekCount(i, 8);
      }
      expect(_state(tester).draft.length, lessThanOrEqualTo(371));
    },
  );

  testWidgets(
    'weekday start on Wednesday stays aligned and Adjust opens the same blocks',
    (tester) async {
      await _open(tester);
      await _template63(tester);
      await _tap(tester, _key('weeks-mode-weekdays'));
      _wizard(tester).setStart(const CivilDate(2027, 1, 6));
      await _tap(tester, _key('pattern-next'));
      expect(_state(tester).stepOffset, 2);
      expect(_previewDay(tester, const CivilDate(2027, 1, 9)).shiftIds, [
        'rest',
      ]);
      expect(_previewDay(tester, const CivilDate(2027, 1, 11)).shiftIds, [
        'morning',
      ]);
      final request = _wizard(tester).request(_schedule(tester))!;
      expect(request.stepOffset, 2);
      await _tap(tester, _key('pattern-back'));
      List<(CivilDate, String)> effectiveDays() {
        final preview = _container(tester)
            .read(patternPreviewProvider(_args(tester)))!;
        final start = _state(tester).start;
        return [
          for (final day in preview.schedule.resolveRange(
            start,
            start.addDays(80),
          ))
            (day.date, day.shiftIds.join('+')),
        ];
      }

      final originalDays = effectiveDays();
      _wizard(tester).setStart(const CivilDate(2027, 1, 7));
      final movedDays = effectiveDays();
      _wizard(tester).setStart(const CivilDate(2027, 1, 6));
      final steps = _state(tester).draft;
      await _tap(tester, _key('weeks-adjust'));
      expect(_state(tester).building, isTrue);
      expect(_state(tester).blocks, compressSteps(steps));
      expect(_state(tester).blocks, hasLength(18));
      expect(_key('builder-block-0'), findsOneWidget);
      expect(_state(tester).draft, steps);
      final blocks = _state(tester).blocks;
      expect(
        _wizard(tester)
            .editBlocks(setBlockDays(blocks, 0, blocks.first.days + 1)),
        isTrue,
      );
      expect(_state(tester).alignWeekdays, isFalse);
      expect(effectiveDays(), isNot(originalDays));
      _wizard(tester).undoDraft();
      expect(_state(tester).alignWeekdays, isTrue);
      expect(_state(tester).stepOffset, 2);
      expect(effectiveDays(), originalDays);
      _wizard(tester).setStart(const CivilDate(2027, 1, 7));
      expect(_state(tester).stepOffset, 3);
      expect(effectiveDays(), movedDays);

      // Change the start while the manual edit has disabled alignment, then
      // return to the builder and undo: the restored offset belongs to Thursday.
      _wizard(tester).setStart(const CivilDate(2027, 1, 6));
      expect(
        _wizard(tester)
            .editBlocks(setBlockDays(blocks, 0, blocks.first.days + 1)),
        isTrue,
      );
      await _tap(tester, _key('pattern-next'));
      _wizard(tester).setStart(const CivilDate(2027, 1, 7));
      expect(_state(tester).alignWeekdays, isFalse);
      await _tap(tester, _key('pattern-back'));
      await _tap(tester, _key('builder-undo'));
      expect(_state(tester).alignWeekdays, isTrue);
      expect(_state(tester).stepOffset, 3);
      expect(effectiveDays(), movedDays);
      final restored = _container(tester)
          .read(patternPreviewProvider(_args(tester)))!
          .schedule;
      for (final (date, shifts) in [
        (const CivilDate(2027, 1, 7), ['morning']),
        (const CivilDate(2027, 1, 8), ['morning']),
        (const CivilDate(2027, 1, 9), ['rest']),
        (const CivilDate(2027, 1, 10), ['rest']),
        (const CivilDate(2027, 1, 11), ['morning']),
      ]) {
        expect(restored.resolve(date).shiftIds, shifts, reason: '$date');
      }
    },
  );

  testWidgets(
    'step 2 covers the whole cycle; step 3 updates the end and manual changes',
    (tester) async {
      await _open(tester);
      await _template63(tester);
      final calendar = _container(tester)
          .read(scheduleControllerProvider.notifier);
      calendar.setDayShifts(const CivilDate(2027, 1, 5), ['guard24']);
      _wizard(tester).setStart(const CivilDate(2027, 1, 4));
      await _tap(tester, _key('pattern-next'));
      const months = [
        CivilDate(2027, 1, 1),
        CivilDate(2027, 2, 1),
        CivilDate(2027, 3, 1),
      ];
      expect(_months(tester), months);
      expect(_previewDay(tester, const CivilDate(2027, 3, 7)).shiftIds, [
        'afternoon',
      ]);
      expect(_key('preview-override-2027-01-05'), findsOneWidget);
      await _tap(tester, _key('pattern-next'));
      expect(_months(tester), months);
      await _tap(tester, _key('pattern-replace-overrides'));
      expect(_key('preview-override-2027-01-05'), findsNothing);
      expect(_previewDay(tester, const CivilDate(2027, 1, 5)).shiftIds, [
        'morning',
      ]);
      _wizard(tester).setUntil(const CivilDate(2027, 1, 8));
      await tester.pumpAndSettle();
      expect(
        _previewDay(tester, const CivilDate(2027, 1, 9)).shiftIds,
        _schedule(tester).resolve(const CivilDate(2027, 1, 9)).shiftIds,
      );
      expect(_months(tester), months);
      // The live preview does not change the stored day.
      expect(_schedule(tester).resolve(const CivilDate(2027, 1, 5)).shiftIds, [
        'guard24',
      ]);
    },
  );

  testWidgets('a short cycle still displays at least one whole month', (
    tester,
  ) async {
    await _open(tester);
    await _tap(tester, _key('pattern-card-24x72'));
    _wizard(tester).setStart(const CivilDate(2027, 1, 4));
    await _tap(tester, _key('pattern-next'));
    expect(_months(tester), [const CivilDate(2027, 1, 1)]);
    expect(_key('preview-2027-01-31'), findsOneWidget);
  });

  for (final source in ['correturnos', 'own']) {
    testWidgets(
      'Edit $source saves a separate pattern before applying a new rotation',
      (tester) async {
        await _open(
          tester,
          prepare: (repository) async {
            if (source == 'own') {
              await repository.savePattern(
                const Pattern(
                  id: 'own',
                  name: 'Propio',
                  steps: [
                    ['morning'],
                    [],
                  ],
                ),
              );
            }
            await repository.apply(
              mainCalendarId,
              ScheduleChange(
                runsAfter: [
                  PatternRun(
                    id: 'source-run',
                    patternId: source,
                    startDate: fixedToday.addDays(-7),
                    seq: 99,
                  ),
                ],
              ),
            );
          },
        );
        final original = _schedule(tester).patternById(source)!;
        final beforeRuns = _schedule(tester).runs;
        final beforePatternCount = _schedule(tester).patterns.length;
        final card = _key('pattern-card-${original.id}');
        await _tap(
          tester,
          find.descendant(of: card, matching: find.text('Editar')),
        );
        expect(_state(tester).draft, original.steps);
        expect(find.text('Guardar como patrón nuevo'), findsOneWidget);
        await _tap(tester, _key('builder-add-night'));
        await _tap(tester, _key('pattern-next'));
        expect(_state(tester).step, WizardStep.start);
        expect(_schedule(tester).patterns, hasLength(beforePatternCount + 1));
        expect(_schedule(tester).patternById(original.id), original);
        expect(_schedule(tester).runs, beforeRuns);
        final copy = _schedule(tester).patternById(_state(tester).customId!)!;
        expect(copy.id, isNot(original.id));
        expect(copy.name, '${original.name} (2)');
        expect(copy.steps.last, ['night']);
        await _tap(tester, _key('pattern-next'));
        await _tap(tester, _key('pattern-apply'));
        expect(
          _schedule(tester).runs.any((r) => r.patternId == copy.id),
          isTrue,
        );
        expect(_schedule(tester).patternById(original.id), original);
      },
    );
  }

  testWidgets(
    'Remove names unused patterns and hides the action for used ones',
    (tester) async {
      await _open(
        tester,
        prepare: (repository) async {
          for (final (id, name) in [
            ('unused', 'Sin uso'),
            ('used', 'Con uso'),
          ]) {
            await repository.savePattern(
              Pattern(
                id: id,
                name: name,
                steps: const [
                  ['night'],
                ],
              ),
            );
          }
          await repository.apply(
            mainCalendarId,
            ScheduleChange(
              runsAfter: [
                PatternRun(
                  id: 'used-run',
                  patternId: 'used',
                  startDate: fixedToday,
                  seq: 99,
                ),
              ],
            ),
          );
        },
      );
      final own = _schedule(tester).patternById('unused')!;
      _wizard(tester).selectCustom(own.id);
      final card = _key('pattern-card-${own.id}');
      await _tap(
        tester,
        find.descendant(of: card, matching: find.text('Quitar')),
      );
      expect(find.text('¿Quitar «Sin uso»?'), findsOneWidget);
      await _tap(tester, find.text('Cancelar'));
      expect(_schedule(tester).patternById(own.id), isNotNull);
      await _tap(
        tester,
        find.descendant(of: card, matching: find.text('Quitar')),
      );
      await _tap(tester, _key('pattern-remove-confirm'));
      expect(_schedule(tester).patternById(own.id), isNull);
      expect(_state(tester).hasChoice, isFalse);
      final usedCard = _key('pattern-card-used');
      expect(
        find.descendant(of: usedCard, matching: find.text('Quitar')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: usedCard,
          matching: find.textContaining('lo usa una rotación'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: usedCard, matching: find.text('Editar')),
        findsOneWidget,
      );
    },
  );

  for (final (size, scale) in [
    (const Size(320, 568), 2.0),
    (const Size(390, 844), 1.0),
  ]) {
    for (final brightness in Brightness.values) {
      testWidgets('template and both previews fit $size x$scale $brightness', (
        tester,
      ) async {
        await _open(tester, size: size, scale: scale, brightness: brightness);
        await _template63(tester);
        await _tap(tester, _key('weeks-mode-weekdays'));
        _container(tester)
            .read(scheduleControllerProvider.notifier)
            .setDayShifts(_state(tester).start, ['guard24']);
        await tester.pumpAndSettle();
        expect(brokenParagraphs(tester), isEmpty);
        await _tap(tester, _key('pattern-next'));
        for (final step in ['start', 'end']) {
          expect(_months(tester).length, greaterThanOrEqualTo(3));
          expect(
            _key('preview-override-${_state(tester).start.toIso()}'),
            findsOneWidget,
          );
          final scroll = find
              .descendant(
                of: _key('pattern-step-$step'),
                matching: find.byType(Scrollable),
              )
              .first;
          final position = tester.state<ScrollableState>(scroll).position;
          position.jumpTo(position.maxScrollExtent);
          await tester.pumpAndSettle();
          final lastMonth = _months(tester).last;
          final last = lastMonth.addDays(lastMonth.daysInMonth - 1);
          final cell = tester.getRect(_key('preview-${last.toIso()}'));
          expect(
            cell.bottom,
            lessThanOrEqualTo(
              tester.getRect(_key('pattern-step-$step')).bottom,
            ),
          );
          expect(
            cell.bottom,
            lessThan(
              tester
                  .getTopLeft(
                    _key(step == 'start' ? 'pattern-next' : 'pattern-apply'),
                  )
                  .dy,
            ),
          );
          expect(tester.takeException(), isNull);
          if (step == 'start') await _tap(tester, _key('pattern-next'));
        }
      });
    }
  }
}
