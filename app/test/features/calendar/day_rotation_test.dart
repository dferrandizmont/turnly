import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/core/widgets/app_snack_bar.dart';
import 'package:cuadrante/features/calendar/application/schedule_controller.dart';
import 'package:cuadrante/features/calendar/application/visible_month.dart';
import 'package:cuadrante/features/patterns/presentation/cycle_start_picker.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/real_font.dart';
import '../../support/text_lines.dart';
import 'day_detail_test.dart' show closeDay, openDay;
import 'harness.dart';

// The rotation of a day in its detail (`day_rotation_section.dart`): where
// the day comes from and the «Rotación» menu with the actions that make sense
// on it. Demo data around Monday 19 Oct 2026: an open-ended «Correturnos»
// since 13 July; 19-23 Oct are nights, 24-25 libre and Monday 26 is the first
// day of the cycle again; 21 Oct is Mañana + Tarde by hand and 22 Oct is
// emptied by hand.
const _oct20 = CivilDate(2026, 10, 20);
const _oct21 = CivilDate(2026, 10, 21);
const _oct22 = CivilDate(2026, 10, 22);
const _oct23 = CivilDate(2026, 10, 23);
const _oct26 = CivilDate(2026, 10, 26);
const _oct28 = CivilDate(2026, 10, 28);
const _oct30 = CivilDate(2026, 10, 30);

Finder _key(String key) => find.byKey(ValueKey(key));

String _source(WidgetTester tester) =>
    tester.widget<Text>(_key('day-source')).data!;

Schedule _schedule(WidgetTester tester) => scheduleOf(tester);

ScheduleController _controller(WidgetTester tester) =>
    containerOf(tester).read(scheduleControllerProvider.notifier);

Future<void> _openMenu(WidgetTester tester) async {
  await tester.ensureVisible(_key('day-rotation-menu'));
  await tester.pumpAndSettle();
  await tester.tap(_key('day-rotation-menu'));
  await tester.pumpAndSettle();
}

Future<void> _closeMenu(WidgetTester tester) async {
  Navigator.of(
    tester.element(find.byWidgetPredicate((w) => w is PopupMenuItem).first),
  ).pop();
  await tester.pumpAndSettle();
}

Future<void> _choose(WidgetTester tester, String key) async {
  await _openMenu(tester);
  await tester.tap(_key(key));
  await tester.pumpAndSettle();
}

Future<void> _confirm(WidgetTester tester) async {
  await tester.ensureVisible(_key('confirm-ok'));
  await tester.pumpAndSettle();
  await tester.tap(_key('confirm-ok'));
  await tester.pumpAndSettle();
}

String _dialogBody(WidgetTester tester) => tester
    .widget<Text>(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.byWidgetPredicate(
          (w) => w is Text && (w.data ?? '').startsWith('Tu rotación'),
        ),
      ),
    )
    .data!;

/// The texts under [root] that break inside a word.
List<String> _brokenIn(WidgetTester tester, Finder root) => [
  for (final element
      in find.descendant(of: root, matching: find.byType(RichText)).evaluate())
    if (!wrapsOnlyBetweenWords(element.renderObject! as RenderParagraph))
      paragraphLines(element.renderObject! as RenderParagraph).join(' | '),
];

void main() {
  // The real font, so the layout tests say something about a phone.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeLocale();
    expect(await loadRoboto(), isTrue, reason: 'Roboto from the Flutter SDK');
  });

  group('what each day offers', () {
    testWidgets('a day of the rotation says which one and offers to start '
        'it over or to end it there', (tester) async {
      await pumpCalendar(tester);
      await openDay(tester, _oct20);
      expect(_source(tester), 'De tu rotación «Correturnos»');
      await _openMenu(tester);
      expect(find.text('Empezar la rotación aquí'), findsOneWidget);
      expect(find.text('Último día de esta rotación'), findsOneWidget);
      expect(_key('day-rotation-resume'), findsNothing);
    });

    testWidgets('the first day of the cycle can start over on another day of '
        'the cycle, not on the same one', (tester) async {
      await pumpCalendar(tester);
      await openDay(tester, _oct26);
      expect(_source(tester), 'De tu rotación «Correturnos»');
      await _openMenu(tester);
      expect(_key('day-rotation-restart'), findsOneWidget);
      expect(_key('day-rotation-end'), findsOneWidget);
      expect(_key('day-rotation-resume'), findsNothing);

      await tester.tap(_key('day-rotation-restart'));
      await tester.pumpAndSettle();
      FilledButton ok() => tester.widget<FilledButton>(_key('confirm-ok'));
      // Day 1 of the cycle already falls on 26 Oct: nothing would change.
      expect(ok().onPressed, isNull);
      await tester.ensureVisible(_key('restart-offset-2'));
      await tester.pumpAndSettle();
      await tester.tap(_key('restart-offset-2'));
      await tester.pumpAndSettle();
      expect(ok().onPressed, isNotNull);
      await _confirm(tester);
      expect(_schedule(tester).resolvePattern(_oct26).stepIndex, 2);
    });

    testWidgets(
      'a day changed by hand says so, keeps «Volver a la rotación» and '
      'still offers the actions of its rotation',
      (tester) async {
        await pumpCalendar(tester);
        await openDay(tester, _oct21);
        expect(_source(tester), 'Cambiado a mano');
        expect(_key('day-reset'), findsOneWidget);
        await _openMenu(tester);
        expect(_key('day-rotation-restart'), findsOneWidget);
        expect(_key('day-rotation-end'), findsOneWidget);
        await _closeMenu(tester);
        await closeDay(tester);

        // Emptied by hand: «Este día no tiene turno» says it already.
        await openDay(tester, _oct22);
        expect(_key('day-source'), findsNothing);
        expect(_key('day-rotation-menu'), findsOneWidget);
      },
    );

    testWidgets('a day before the rotation started has no rotation menu', (
      tester,
    ) async {
      await pumpCalendar(tester);
      containerOf(tester)
          .read(visibleMonthProvider.notifier)
          .goTo(const CivilDate(2026, 6, 1));
      await tester.pumpAndSettle();
      await openDay(tester, const CivilDate(2026, 6, 10));
      expect(_key('day-rotation-menu'), findsNothing);
      expect(_key('day-source'), findsNothing);
    });

    testWidgets('after the rotation ended, an empty day says when it ended '
        'and offers to start it again', (tester) async {
      await pumpCalendar(tester);
      _controller(tester).endRunOn(_oct23);
      await tester.pumpAndSettle();
      await openDay(tester, _oct30);
      expect(find.text('Este día no tiene turno.'), findsOneWidget);
      expect(
        _source(tester),
        'Tu rotación «Correturnos» terminó el viernes 23 de octubre',
      );
      await _openMenu(tester);
      expect(find.text('Empezar tu rotación aquí'), findsOneWidget);
      expect(_key('day-rotation-restart'), findsNothing);
      expect(_key('day-rotation-end'), findsNothing);
      await _closeMenu(tester);
      await closeDay(tester);

      // The last day of the rotation: nothing left to end.
      await openDay(tester, _oct23);
      await _openMenu(tester);
      expect(_key('day-rotation-end'), findsNothing);
      expect(_key('day-rotation-restart'), findsOneWidget);
    });
  });

  group('Empezar la rotación aquí', () {
    testWidgets('a bounded restart explains temporary priority and preserves '
        'the later rotation outside its interval', (tester) async {
      await pumpCalendar(tester);
      final future = PatternRun(
        id: 'future',
        patternId: '6x4',
        startDate: _oct23,
        seq: 2,
      );
      _controller(tester).applyPlanned(
        (current) => (
          change: ScheduleChange(
            runsBefore: current.runs,
            runsAfter: [
              current.runs.single.copyWith(endDate: _oct28),
              future,
            ],
          ),
          newTypes: const <ShiftType>[],
        ),
      );
      await tester.pumpAndSettle();
      await openDay(tester, _oct20);
      await _choose(tester, 'day-rotation-restart');
      expect(
        _dialogBody(tester),
        contains(
          'Esta rotación tendrá prioridad hasta el miércoles 28 de octubre. '
          'Las demás seguirán aplicándose en las fechas que queden fuera de ese intervalo.',
        ),
      );
      await _confirm(tester);
      expect(_schedule(tester).resolve(_oct23).runId, isNot('future'));
      expect(_schedule(tester).resolve(_oct28.addDays(1)).runId, 'future');
      expect(
        _schedule(tester).runs.firstWhere((r) => r.id == 'future'),
        future,
      );
    });

    testWidgets('asks first, saying what changes, and is one step that the '
        'notice undoes', (tester) async {
      await pumpCalendar(tester);
      final runsBefore = _schedule(tester).runs;
      await openDay(tester, _oct20);
      await _choose(tester, 'day-rotation-restart');

      expect(find.text('¿Empezar la rotación aquí?'), findsOneWidget);
      expect(
        _dialogBody(tester),
        'Tu rotación «Correturnos» volverá a empezar el martes 20 de octubre: '
        'ese día será el primero del ciclo (Mañana 06:00–14:00). '
        'Los días anteriores y tus cambios a mano no se tocan.',
      );
      // Nothing changes until it is confirmed.
      expect(_schedule(tester).runs, runsBefore);
      await _confirm(tester);

      expect(find.byType(BottomSheet), findsNothing);
      expect(idsOn(_schedule(tester), fixedToday), 'night');
      expect(idsOn(_schedule(tester), _oct20), 'morning');
      expect(idsOn(_schedule(tester), _oct21), 'morning+afternoon');
      expect(_schedule(tester).resolve(_oct20).stepIndex, 0);
      expect(
        find.text('La rotación empieza el martes 20 de octubre'),
        findsOneWidget,
      );

      await tester.tap(find.text('Deshacer'));
      await tester.pumpAndSettle();
      expect(_schedule(tester).runs, runsBefore);
      expect(idsOn(_schedule(tester), _oct20), 'night');
    });

    testWidgets('asks which day of the cycle falls on that day, says it live '
        'and applies it', (tester) async {
      await pumpCalendar(tester);
      final runsBefore = _schedule(tester).runs;
      await openDay(tester, _oct20);
      await _choose(tester, 'day-rotation-restart');

      expect(find.byType(CycleStartPicker), findsOneWidget);
      expect(find.text('¿En qué día del ciclo estás ese día?'), findsOneWidget);
      expect(
        _dialogBody(tester),
        contains('ese día será el primero del ciclo'),
      );
      await tester.ensureVisible(_key('restart-offset-2'));
      await tester.pumpAndSettle();
      await tester.tap(_key('restart-offset-2'));
      await tester.pumpAndSettle();
      expect(
        _dialogBody(tester),
        startsWith(
          'Tu rotación «Correturnos» volverá a empezar el martes 20 de '
          'octubre: ese día será el día 3 del ciclo (',
        ),
      );
      expect(_dialogBody(tester), endsWith('no se tocan.'));
      expect(_schedule(tester).runs, runsBefore);
      await _confirm(tester);

      final schedule = _schedule(tester);
      expect(schedule.resolve(_oct20).stepIndex, 2);
      expect(schedule.resolvePattern(_oct21).stepIndex, 3);
      expect(schedule.resolve(_oct20).runId, isNot('run-1'));
      expect(
        find.text('La rotación empieza el martes 20 de octubre'),
        findsOneWidget,
      );
      await tester.tap(find.text('Deshacer'));
      await tester.pumpAndSettle();
      expect(_schedule(tester).runs, runsBefore);
    });

    testWidgets('the day that already falls on that date cannot be confirmed', (
      tester,
    ) async {
      await pumpCalendar(tester);
      final current = _schedule(tester).resolve(_oct20).stepIndex!;
      expect(current, isNot(0));
      await openDay(tester, _oct20);
      await _choose(tester, 'day-rotation-restart');
      FilledButton ok() => tester.widget<FilledButton>(_key('confirm-ok'));
      expect(ok().onPressed, isNotNull);

      await tester.ensureVisible(_key('restart-offset-$current'));
      await tester.pumpAndSettle();
      await tester.tap(_key('restart-offset-$current'));
      await tester.pumpAndSettle();
      expect(ok().onPressed, isNull);

      await tester.ensureVisible(_key('restart-offset-0'));
      await tester.pumpAndSettle();
      await tester.tap(_key('restart-offset-0'));
      await tester.pumpAndSettle();
      expect(ok().onPressed, isNotNull);
    });

    testWidgets('the text and the strip show the hours the shift had on that '
        'day', (tester) async {
      final old = shiftTemplates
          .firstWhere((t) => t.key == 'night')
          .toShiftType('night');
      await pumpCalendar(
        tester,
        // Noche now ends at 07:00, but until 25 Oct it ended at 06:00.
        prepare: (repository) => repository.saveShiftTypeWithHistory(
          old.copyWith(endMinute: 7 * 60),
          [
            ShiftTypeVersion(
              until: _oct23.addDays(2),
              terms: ShiftTerms.of(old),
            ),
          ],
        ),
      );
      await openDay(tester, _oct20);
      await _choose(tester, 'day-rotation-restart');
      await tester.ensureVisible(_key('restart-offset-14'));
      await tester.pumpAndSettle();
      await tester.tap(_key('restart-offset-14'));
      await tester.pumpAndSettle();

      // The line keeps the time range together with a word joiner.
      final result = tester
          .widget<Text>(_key('restart-offset-result'))
          .data!
          .replaceAll('\u2060', '');
      expect(result, contains('Noche 22:00–06:00'));
      expect(_dialogBody(tester), contains('Noche 22:00–06:00'));
      expect(result, isNot(contains('07:00')));
      expect(_dialogBody(tester), isNot(contains('07:00')));
    });

    testWidgets('on a day changed by hand the line says what the rotation '
        'would give and the day keeps what is there', (tester) async {
      await pumpCalendar(tester);
      expect(idsOn(_schedule(tester), _oct28), 'vacation');
      final current = _schedule(tester).resolvePattern(_oct28).stepIndex!;
      final pick = (current + 1) % 20;
      await openDay(tester, _oct28);
      await _choose(tester, 'day-rotation-restart');
      await tester.ensureVisible(_key('restart-offset-$pick'));
      await tester.pumpAndSettle();
      await tester.tap(_key('restart-offset-$pick'));
      await tester.pumpAndSettle();
      final result = tester.widget<Text>(_key('restart-offset-result')).data!;
      expect(result, startsWith('Según tu rotación: '));
      expect(result, isNot(contains('Ese día te toca')));
      await _confirm(tester);
      expect(idsOn(_schedule(tester), _oct28), 'vacation');
      expect(_schedule(tester).resolvePattern(_oct28).stepIndex, pick);
    });

    testWidgets('cancelling changes nothing', (tester) async {
      await pumpCalendar(tester);
      final runsBefore = _schedule(tester).runs;
      await openDay(tester, _oct20);
      await _choose(tester, 'day-rotation-restart');
      await tester.tap(_key('confirm-cancel'));
      await tester.pumpAndSettle();
      expect(_schedule(tester).runs, runsBefore);
      expect(find.byType(BottomSheet), findsOneWidget);
    });
  });

  group('Último día de esta rotación', () {
    testWidgets('a gap tomorrow does not imply that future rotations end', (
      tester,
    ) async {
      await pumpCalendar(tester);
      final future = PatternRun(
        id: 'future',
        patternId: '6x4',
        startDate: _oct30,
        seq: 2,
      );
      _controller(tester).applyPlanned(
        (current) => (
          change: ScheduleChange(
            runsBefore: current.runs,
            runsAfter: [...current.runs, future],
          ),
          newTypes: const <ShiftType>[],
        ),
      );
      await tester.pumpAndSettle();
      await openDay(tester, _oct20);
      await _choose(tester, 'day-rotation-end');
      expect(
        _dialogBody(tester),
        contains(
          'El miércoles 21 de octubre no tendrá ninguna rotación asignada. '
          'Las demás rotaciones mantienen sus fechas.',
        ),
      );
      await _confirm(tester);
      expect(_schedule(tester).resolvePattern(_oct23).runId, isNull);
      expect(_schedule(tester).resolvePattern(_oct30).runId, 'future');
      expect(
        _schedule(tester).runs.firstWhere((r) => r.id == 'future'),
        future,
      );
    });

    testWidgets('says that the next day is left without rotation, ends '
        'it there and the notice undoes it', (tester) async {
      await pumpCalendar(tester);
      final runsBefore = _schedule(tester).runs;
      await openDay(tester, _oct20);
      await _choose(tester, 'day-rotation-end');

      expect(find.text('¿Terminar la rotación este día?'), findsOneWidget);
      expect(
        _dialogBody(tester),
        'Tu rotación «Correturnos» terminará el martes 20 de octubre. '
        'El miércoles 21 de octubre no tendrá ninguna rotación asignada. Las demás rotaciones mantienen sus fechas. '
        'Los días anteriores y tus cambios a mano no se tocan.',
      );
      await _confirm(tester);

      expect(find.byType(BottomSheet), findsNothing);
      expect(_schedule(tester).runs.single.endDate, _oct20);
      expect(idsOn(_schedule(tester), _oct20), 'night');
      expect(idsOn(_schedule(tester), _oct21), 'morning+afternoon');
      expect(idsOn(_schedule(tester), _oct23), '');
      expect(
        find.text('La rotación acaba el martes 20 de octubre'),
        findsOneWidget,
      );

      await tester.tap(find.text('Deshacer'));
      await tester.pumpAndSettle();
      expect(_schedule(tester).runs, runsBefore);
      expect(idsOn(_schedule(tester), _oct23), 'night');
    });

    testWidgets('says which rotation takes over when an earlier one was '
        'still running underneath', (tester) async {
      await pumpCalendar(tester);
      // A 6x4 with an end on top of the correturnos from the 20th: a run
      // with an end does not cut the earlier one, which goes on underneath.
      _controller(tester).applyPlanned(
        (current) => (
          change: current.applyPattern(
            '6x4',
            _oct20,
            until: const CivilDate(2026, 12, 31),
            seq: 2,
          ),
          newTypes: const <ShiftType>[],
        ),
      );
      await tester.pumpAndSettle();
      final name = _schedule(tester).patternById('6x4')!.name;
      await openDay(tester, _oct21);
      // 21 Oct is changed by hand; the rotation underneath is the 6x4.
      await _choose(tester, 'day-rotation-end');
      expect(
        _dialogBody(tester),
        'Tu rotación «$name» terminará el miércoles 21 de octubre. '
        'El jueves 22 de octubre se aplicará tu rotación «Correturnos». Las demás rotaciones mantienen sus fechas. '
        'Los días anteriores y tus cambios a mano no se tocan.',
      );
      await _confirm(tester);
      expect(_schedule(tester).resolve(_oct23).runId, 'run-1');
      expect(idsOn(_schedule(tester), _oct23), 'night');
    });
  });

  group('Empezar tu rotación aquí', () {
    testWidgets('asks which day of the cycle falls on that day and applies '
        'the rotation from it, as one step', (tester) async {
      await pumpCalendar(tester);
      _controller(tester).endRunOn(_oct23);
      await tester.pumpAndSettle();
      final runsBefore = _schedule(tester).runs;
      await openDay(tester, _oct30);
      await _choose(tester, 'day-rotation-resume');

      expect(find.text('¿Empezar tu rotación aquí?'), findsOneWidget);
      expect(
        _dialogBody(tester),
        'Tu rotación «Correturnos» se aplicará otra vez desde el viernes 30 '
        'de octubre, sin fecha de fin. '
        'Los días anteriores y tus cambios a mano no se tocan.',
      );
      // The same question as the rotation wizard.
      expect(find.byType(CycleStartPicker), findsOneWidget);
      expect(find.text('¿En qué día del ciclo estás ese día?'), findsOneWidget);
      await tester.ensureVisible(_key('resume-offset-14'));
      await tester.pumpAndSettle();
      await tester.tap(_key('resume-offset-14'));
      await tester.pumpAndSettle();
      expect(_schedule(tester).runs, runsBefore);
      await _confirm(tester);

      expect(find.byType(BottomSheet), findsNothing);
      final fresh = _schedule(tester).runs.firstWhere((r) => r.id != 'run-1');
      expect(fresh.patternId, 'correturnos');
      expect(fresh.startDate, _oct30);
      expect(fresh.endDate, isNull);
      // The first Noche of the correturnos is its 15th day.
      expect(fresh.stepOffset, 14);
      expect(idsOn(_schedule(tester), _oct30), 'night');
      expect(idsOn(_schedule(tester), _oct28), 'vacation');
      expect(idsOn(_schedule(tester), const CivilDate(2026, 10, 29)), '');
      expect(
        find.text('La rotación empieza el viernes 30 de octubre'),
        findsOneWidget,
      );

      await tester.tap(find.text('Deshacer'));
      await tester.pumpAndSettle();
      expect(_schedule(tester).runs, runsBefore);
      expect(idsOn(_schedule(tester), _oct30), '');
    });

    testWidgets('without choosing, the rotation starts on the first day of '
        'its cycle', (tester) async {
      await pumpCalendar(tester);
      _controller(tester).endRunOn(_oct23);
      await tester.pumpAndSettle();
      await openDay(tester, _oct30);
      await _choose(tester, 'day-rotation-resume');
      await _confirm(tester);
      expect(_schedule(tester).resolve(_oct30).stepIndex, 0);
      expect(idsOn(_schedule(tester), _oct30), 'morning');
    });
  });

  group('tracked rotation notices', () {
    for (final action in ['restart', 'end', 'resume']) {
      for (final accessible in [false, true]) {
        testWidgets('$action reserves space, keeps its undo and releases '
            'space (accessible navigation: $accessible)', (tester) async {
          tester.platformDispatcher.accessibilityFeaturesTestValue =
              FakeAccessibilityFeatures(accessibleNavigation: accessible);
          await pumpCalendar(tester, textScale: 2);
          if (action == 'resume') {
            _controller(tester).endRunOn(_oct23);
            await tester.pumpAndSettle();
          }
          final before = _schedule(tester);
          await openDay(tester, action == 'resume' ? _oct30 : _oct20);
          await _choose(tester, 'day-rotation-$action');
          await _confirm(tester);
          final container = containerOf(tester);
          final bar = tester.widget<SnackBar>(find.byType(SnackBar));
          expect(bar.persist, accessible);
          expect(container.read(snackBarCoverProvider), greaterThan(0));
          if (accessible) {
            await tester.pump(const Duration(seconds: 8));
            await tester.pumpAndSettle();
            expect(find.byType(SnackBar), findsOneWidget);
            expect(container.read(snackBarCoverProvider), greaterThan(0));
          }
          await tester.tap(find.text('Deshacer'));
          await tester.pumpAndSettle();
          expect(_schedule(tester).runs, before.runs);
          expect(_schedule(tester).entries, before.entries);
          expect(container.read(snackBarCoverProvider), isNull);
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('undo from a notice cannot undo a subsequent edit', (
      tester,
    ) async {
      await pumpCalendar(tester);
      await openDay(tester, _oct20);
      await _choose(tester, 'day-rotation-restart');
      await _confirm(tester);
      _controller(tester).setNote(_oct23, 'Later edit');
      await tester.pumpAndSettle();
      final after = _schedule(tester);
      await tester.tap(find.text('Deshacer'));
      await tester.pumpAndSettle();
      expect(_schedule(tester).runs, after.runs);
      expect(_schedule(tester).entries, after.entries);
    });
  });

  group('layout', () {
    for (final size in const [Size(360, 740), Size(412, 915)]) {
      for (final scale in const [1.0, 1.3, 2.0]) {
        for (final brightness in Brightness.values) {
          testWidgets('the rotation row and its dialogs fit at '
              '${size.width.toInt()} dp, text x$scale, ${brightness.name}', (
            tester,
          ) async {
            await pumpCalendar(
              tester,
              size: size,
              textScale: scale,
              brightness: brightness,
            );
            _controller(tester).endRunOn(_oct23);
            await tester.pumpAndSettle();
            await openDay(tester, _oct20);
            expect(_key('day-rotation-menu'), findsOneWidget);
            expect(tester.takeException(), isNull);
            expect(_brokenIn(tester, _key('day-rotation')), isEmpty);
            // The row stays inside the sheet.
            final row = tester.getRect(_key('day-rotation'));
            expect(row.left, greaterThanOrEqualTo(0));
            expect(row.right, lessThanOrEqualTo(size.width));

            await _choose(tester, 'day-rotation-end');
            expect(find.byType(AlertDialog), findsOneWidget);
            expect(tester.takeException(), isNull);
            expect(_brokenIn(tester, find.byType(AlertDialog)), isEmpty);
            await tester.tap(_key('confirm-cancel'));
            await tester.pumpAndSettle();
            await closeDay(tester);

            // The dialog with the picker of the day of the cycle.
            await openDay(tester, _oct30);
            await _choose(tester, 'day-rotation-resume');
            expect(find.byType(CycleStartPicker), findsOneWidget);
            for (final i in [0, 7]) {
              final cell = _key('resume-offset-$i');
              await tester.ensureVisible(cell);
              await tester.pumpAndSettle();
              await tester.tap(cell);
              await tester.pumpAndSettle();
              expect(tester.getSize(cell).width, greaterThanOrEqualTo(48));
              expect(tester.getSize(cell).height, greaterThanOrEqualTo(48));
            }
            await tester.ensureVisible(_key('resume-offset-0'));
            await tester.pumpAndSettle();
            await tester.tap(_key('resume-offset-0'));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(
              _brokenIn(tester, _key('day-rotation-resume-scroll')),
              isEmpty,
            );
            // Its buttons are in reach whatever the picker takes.
            final dialog = tester.getRect(find.byType(Dialog));
            final ok = tester.getRect(_key('confirm-ok'));
            expect(ok.bottom, lessThanOrEqualTo(dialog.bottom));
            expect(dialog.bottom, lessThanOrEqualTo(size.height));
            await _confirm(tester);
            expect(tester.takeException(), isNull);
            expect(idsOn(_schedule(tester), _oct30), 'morning');
          });
        }
      }
    }
  });
}
