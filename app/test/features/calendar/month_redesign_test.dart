import 'dart:ui' show Tristate;

import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/core/router.dart';
import 'package:cuadrante/core/theme/theme_context.dart';
import 'package:cuadrante/features/calendar/application/month_presentation.dart';
import 'package:cuadrante/features/calendar/application/paint_controller.dart';
import 'package:cuadrante/features/calendar/application/schedule_controller.dart';
import 'package:cuadrante/features/calendar/application/visible_month.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';
import '../../support/real_font.dart';

/// B1 (Mes, option 1A of the 31-oct canvas), B3 (Pintar, option 3A) and B7
/// (Grid or List remembered): the bar of destinations, the foldable «Hoy»
/// card, the small Grid/List switch, the two paint modes with their preview,
/// and the change of month.
void main() {
  setUpAll(initializeLocale);

  Finder key(String value) => find.byKey(ValueKey(value));

  Future<T> stored<T>(WidgetTester tester, Future<T> Function() read) async =>
      (await tester.runAsync(read)) as T;

  group('bar of destinations', () {
    testWidgets('four destinations with their name; Mes is the current one', (
      tester,
    ) async {
      expect(await tester.runAsync(loadRoboto), isTrue);
      addTearDown(() => AppTypography.debugFamily = null);
      await pumpCalendar(tester, size: const Size(390, 844));
      final bar = tester.widget<NavigationBar>(key('month-nav-bar'));
      expect(bar.selectedIndex, 0);
      expect(bar.labelBehavior, NavigationDestinationLabelBehavior.alwaysShow);
      for (final name in ['Mes', 'Rotación', 'Agenda', 'Resumen']) {
        expect(
          find.descendant(of: key('month-nav-bar'), matching: find.text(name)),
          findsOneWidget,
        );
      }
      // The old header button is gone: the agenda lives in the bar now.
      expect(
        find.descendant(of: key('month-nav-bar'), matching: key('open-agenda')),
        findsOneWidget,
      );
      // The floating «Pintar» sits above the bar.
      final fab = tester.getRect(find.byType(FloatingActionButton));
      expect(
        fab.bottom,
        lessThanOrEqualTo(tester.getRect(key('month-nav-bar')).top),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('Agenda and Resumen open their screens', (tester) async {
      await pumpCalendar(tester);
      await tester.tap(key('open-agenda'));
      await tester.pumpAndSettle();
      expect(find.text('Agenda'), findsWidgets);
      expect(key('month-nav-bar'), findsNothing);
      rootNavigatorKey.currentState!.pop();
      await tester.pumpAndSettle();

      containerOf(tester)
          .read(visibleMonthProvider.notifier)
          .goTo(const CivilDate(2026, 12, 1));
      await tester.pumpAndSettle();
      await tester.tap(key('open-summary'));
      await tester.pumpAndSettle();
      // The summary of the month on screen.
      expect(find.textContaining('Diciembre'), findsWidgets);
    });

    testWidgets('Rotación: my rotations, or the wizard when there is none', (
      tester,
    ) async {
      await pumpCalendar(tester);
      final runs = scheduleOf(tester).runs;
      expect(runs, isNotEmpty, reason: 'the demo data has a rotation');
      await tester.tap(key('open-rotation'));
      await tester.pumpAndSettle();
      expect(find.text('Mis rotaciones'), findsOneWidget);
      rootNavigatorKey.currentState!.pop();
      await tester.pumpAndSettle();

      final controller = containerOf(tester)
          .read(scheduleControllerProvider.notifier);
      for (final run in runs) {
        controller.deleteRun(run.id);
      }
      await tester.pumpAndSettle();
      await tester.tap(key('open-rotation'));
      await tester.pumpAndSettle();
      expect(find.text('Mis rotaciones'), findsNothing);
      expect(find.textContaining('1 de 3'), findsWidgets);
    });

    testWidgets('Mes brings back the month of today', (tester) async {
      await pumpCalendar(tester);
      final container = containerOf(tester);
      container
          .read(visibleMonthProvider.notifier)
          .goTo(const CivilDate(2027, 3, 1));
      await tester.pumpAndSettle();
      await tester.tap(key('nav-month'));
      await tester.pumpAndSettle();
      expect(
        container.read(visibleMonthProvider),
        const CivilDate(2026, 10, 1),
      );
    });

    testWidgets('hidden while painting, selecting and with the keyboard', (
      tester,
    ) async {
      await pumpCalendar(tester);
      await enterPaintMode(tester);
      expect(key('month-nav-bar'), findsNothing);
      paintOf(tester).exit();
      await tester.pumpAndSettle();
      expect(key('month-nav-bar'), findsOneWidget);
      await tester.tap(key('month-select-days'));
      await tester.pumpAndSettle();
      expect(key('month-nav-bar'), findsNothing);
    });

    for (final scale in [1.6, 2.0]) {
      testWidgets('320 dp, text x$scale: the names stay, drawn at most at '
          'x1.3 (QA 0.9.0 F4)', (tester) async {
        final handle = tester.ensureSemantics();
        await pumpCalendar(
          tester,
          size: const Size(320, 640),
          textScale: scale,
        );
        final bar = tester.widget<NavigationBar>(key('month-nav-bar'));
        expect(
          bar.labelBehavior,
          NavigationDestinationLabelBehavior.alwaysShow,
        );
        for (final name in ['Mes', 'Rotación', 'Agenda', 'Resumen']) {
          final label = find.descendant(
            of: key('month-nav-bar'),
            matching: find.text(name),
          );
          expect(label, findsOneWidget, reason: name);
          expect(tester.getRect(label).right, lessThanOrEqualTo(320.5));
          expect(
            tester.widget<Text>(label).maxLines,
            anyOf(isNull, 1),
            reason: '$name on one line',
          );
        }
        expect(find.bySemanticsLabel(RegExp('Resumen')), findsWidgets);
        for (final destination in [
          'nav-month',
          'open-rotation',
          'open-agenda',
          'open-summary',
        ]) {
          final rect = tester.getRect(key(destination));
          expect(rect.width, greaterThanOrEqualTo(48));
          expect(rect.right, lessThanOrEqualTo(320.5));
        }
        expect(tester.takeException(), isNull);
        handle.dispose();
      });
    }

    testWidgets('two panes: the destinations go in a rail', (tester) async {
      await pumpCalendar(tester, size: const Size(1280, 800));
      expect(key('month-nav-bar'), findsNothing);
      expect(key('month-nav-rail'), findsOneWidget);
      expect(
        tester.widget<NavigationRail>(key('month-nav-rail')).selectedIndex,
        0,
      );
      expect(tester.takeException(), isNull);
    });

    Future<void> openFromRail(WidgetTester tester, String destination) async {
      await tester.tap(key(destination));
      await tester.pumpAndSettle();
    }

    int railSelected(WidgetTester tester) =>
        tester.widget<NavigationRail>(key('month-nav-rail')).selectedIndex!;

    testWidgets('two panes: Rotación, Agenda and Resumen keep the rail', (
      tester,
    ) async {
      await pumpCalendar(tester, size: const Size(1280, 800));

      await openFromRail(tester, 'open-agenda');
      expect(find.text('Agenda'), findsWidgets);
      expect(key('month-nav-rail'), findsOneWidget);
      expect(railSelected(tester), 2);

      // From one screen to another: no stack of pages, one back to the month.
      await openFromRail(tester, 'open-summary');
      expect(key('month-nav-rail'), findsOneWidget);
      expect(railSelected(tester), 3);

      await openFromRail(tester, 'open-rotation');
      expect(find.text('Mis rotaciones'), findsOneWidget);
      expect(key('month-nav-rail'), findsOneWidget);
      expect(railSelected(tester), 1);

      // Tapping the screen on screen does nothing.
      await openFromRail(tester, 'open-rotation');
      expect(find.text('Mis rotaciones'), findsOneWidget);

      rootNavigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(railSelected(tester), 0);
      expect(find.text('Mis rotaciones'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('two panes: Mes in the rail goes back to the month', (
      tester,
    ) async {
      await pumpCalendar(tester, size: const Size(1280, 800));
      await openFromRail(tester, 'open-agenda');
      await openFromRail(tester, 'open-summary');
      await openFromRail(tester, 'nav-month');
      expect(railSelected(tester), 0);
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(key('pane-divider'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('two panes: the screens fit beside the rail', (tester) async {
      await pumpCalendar(tester, size: const Size(1280, 800));
      await openFromRail(tester, 'open-summary');
      final rail = tester.getRect(key('month-nav-rail'));
      final scaffold = tester.getRect(find.byType(Scaffold).last);
      expect(scaffold.left, greaterThanOrEqualTo(rail.right - 0.5));
      // The app bar sees the width left beside the rail.
      final media = MediaQuery.of(tester.element(find.byType(Scaffold).last));
      expect(media.size.width, closeTo(scaffold.width, 0.5));
      expect(tester.takeException(), isNull);
    });

    for (final size in const [Size(390, 844), Size(800, 1280)]) {
      testWidgets('one column ${size.width.toInt()}x${size.height.toInt()}: '
          'the screens open without a rail', (tester) async {
        await pumpCalendar(tester, size: size);
        await tester.tap(key('open-agenda'));
        await tester.pumpAndSettle();
        expect(find.byType(NavigationRail), findsNothing);
        expect(key('month-nav-bar'), findsNothing);
        expect(find.byType(BackButton), findsWidgets);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('foldable «Hoy» card', () {
    Finder toggle() => key('today-card-toggle');

    /// Brings the fold button clear of the floating «Pintar» (it can float
    /// over the card on a small screen with big text) and taps it.
    Future<void> tapToggle(WidgetTester tester) async {
      // In the middle of the screen: at the top the pinned row of the month
      // would cover it.
      await Scrollable.ensureVisible(tester.element(toggle()), alignment: 0.5);
      await tester.pumpAndSettle();
      final fab = tester.getRect(find.byType(FloatingActionButton));
      for (var i = 0; i < 10 && tester.getRect(toggle()).overlaps(fab); i++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -60));
        await tester.pumpAndSettle();
      }
      await tester.tap(toggle());
      await tester.pumpAndSettle();
    }

    testWidgets('folds to one line, unfolds, and is remembered', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpCalendar(tester, clock: () => DateTime(2026, 10, 19, 18, 20));
      expect(key('today-card-open'), findsOneWidget);
      // The next day off stays on the open card, beside the button.
      expect(key('today-off-line'), findsOneWidget);
      expect(find.byTooltip('Plegar la tarjeta de hoy'), findsOneWidget);
      expect(
        tester
            .getSemantics(toggle())
            .getSemanticsData()
            .flagsCollection
            .isExpanded,
        Tristate.isTrue,
      );
      final openHeight = tester.getSize(find.byType(DecoratedBox).first).height;

      await tester.tap(toggle());
      await tester.pumpAndSettle();
      expect(key('today-card-collapsed'), findsOneWidget);
      expect(key('today-card-open'), findsNothing);
      // Name, hours and countdown in one line; the next day off below it.
      expect(find.text('ESTA NOCHE'), findsOneWidget);
      expect(find.text('Empieza en 3 h 40 min'), findsOneWidget);
      expect(key('today-off-compact'), findsOneWidget);
      expect(find.textContaining('Libras el'), findsOneWidget);
      expect(find.textContaining('Mañana ('), findsNothing);
      expect(find.byTooltip('Desplegar la tarjeta de hoy'), findsOneWidget);
      expect(
        tester
            .getSemantics(toggle())
            .getSemanticsData()
            .flagsCollection
            .isExpanded,
        Tristate.isFalse,
      );
      expect(openHeight, greaterThan(0));

      final container = containerOf(tester);
      final repository = container.read(monthViewSettingsRepositoryProvider);
      expect(await stored(tester, repository.readTodayCardCollapsed), isTrue);
      // A new opening reads it back.
      container.invalidate(todayCardCollapsedProvider);
      await tester.pumpAndSettle();
      expect(key('today-card-collapsed'), findsOneWidget);

      await tester.tap(toggle());
      await tester.pumpAndSettle();
      expect(key('today-card-open'), findsOneWidget);
      expect(await stored(tester, repository.readTodayCardCollapsed), isFalse);
      handle.dispose();
    });

    testWidgets('the folded card is shorter and reads what it shows', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpCalendar(tester, clock: () => DateTime(2026, 10, 19, 12));
      final gridTop = tester.getTopLeft(cell(fixedToday)).dy;
      await tester.tap(toggle());
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(cell(fixedToday)).dy, lessThan(gridTop));
      final label = tester.getSemantics(key('today-off-compact')).label;
      expect(label, contains('Libras el jueves 22'));
      expect(label, isNot(contains('Mañana (')));
      handle.dispose();
    });

    testWidgets('a row stored by hand that is not a boolean keeps it open', (
      tester,
    ) async {
      await pumpCalendar(tester);
      final container = containerOf(tester);
      final repository = container.read(monthViewSettingsRepositoryProvider);
      await tester.runAsync(() => repository.writePresentation('nonsense'));
      container.invalidate(monthPresentationProvider);
      await tester.pumpAndSettle();
      expect(container.read(monthPresentationProvider), MonthPresentation.grid);
      expect(key('today-card-open'), findsOneWidget);
    });

    testWidgets('not foldable in the right pane of two panes', (tester) async {
      await pumpCalendar(tester, size: const Size(1280, 800));
      expect(toggle(), findsNothing);
      expect(key('today-card-open'), findsOneWidget);
    });

    for (final brightness in Brightness.values) {
      for (final (size, scale) in [
        (const Size(320, 640), 1.6),
        (const Size(320, 640), 2.0),
        (const Size(412, 915), 1.0),
      ]) {
        testWidgets(
          '${brightness.name}, ${size.width} dp, text x$scale: both forms fit',
          (tester) async {
            await pumpCalendar(
              tester,
              size: size,
              textScale: scale,
              brightness: brightness,
            );
            expect(tester.takeException(), isNull);
            expect(tester.getSize(toggle()).height, greaterThanOrEqualTo(48));
            await tapToggle(tester);
            expect(key('today-card-collapsed'), findsOneWidget);
            expect(tester.getSize(toggle()).width, greaterThanOrEqualTo(48));
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  });

  group('Grid or List', () {
    testWidgets('the chosen one is remembered between openings', (
      tester,
    ) async {
      await pumpCalendar(tester);
      final container = containerOf(tester);
      final repository = container.read(monthViewSettingsRepositoryProvider);
      expect(await stored(tester, repository.readPresentation), isNull);
      await tester.tap(key('month-presentation-list'));
      await tester.pumpAndSettle();
      expect(container.read(monthPresentationProvider), MonthPresentation.list);
      expect(await stored(tester, repository.readPresentation), 'list');

      container.invalidate(monthPresentationProvider);
      await tester.pumpAndSettle();
      expect(container.read(monthPresentationProvider), MonthPresentation.list);

      await tester.tap(key('month-presentation-grid'));
      await tester.pumpAndSettle();
      expect(await stored(tester, repository.readPresentation), 'grid');
    });

    testWidgets('never changes on its own, even when the list is suggested', (
      tester,
    ) async {
      await pumpCalendar(tester, size: const Size(320, 640), textScale: 2);
      final container = containerOf(tester);
      await revealOnMonth(tester, key('month-list-recommendation'));
      expect(key('month-list-recommendation'), findsOneWidget);
      expect(container.read(monthPresentationProvider), MonthPresentation.grid);
      final repository = container.read(monthViewSettingsRepositoryProvider);
      expect(await stored(tester, repository.readPresentation), isNull);
    });

    testWidgets('small, in the row of the month, with 48 dp targets', (
      tester,
    ) async {
      expect(await tester.runAsync(loadRoboto), isTrue);
      addTearDown(() => AppTypography.debugFamily = null);
      final handle = tester.ensureSemantics();
      await pumpCalendar(tester);
      final title = tester.getRect(key('month-title'));
      for (final presentation in ['grid', 'list']) {
        final rect = tester.getRect(key('month-presentation-$presentation'));
        expect(rect.height, greaterThanOrEqualTo(48));
        expect(rect.width, greaterThanOrEqualTo(48));
        // Same row as the title of the month.
        expect((rect.center.dy - title.center.dy).abs(), lessThan(1));
      }
      final semantics = tester.getSemantics(key('month-presentation-grid'));
      expect(
        semantics.getSemanticsData().flagsCollection.isSelected,
        Tristate.isTrue,
      );
      expect(
        semantics.getSemanticsData().flagsCollection.isInMutuallyExclusiveGroup,
        isTrue,
      );
      handle.dispose();
    });

    testWidgets('stays at the top while the days scroll under it', (
      tester,
    ) async {
      await pumpCalendar(tester, size: const Size(390, 700));
      await tester.tap(key('month-presentation-list'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
      await tester.pumpAndSettle();
      final rect = tester.getRect(key('month-presentation-grid'));
      expect(rect.top, greaterThanOrEqualTo(0));
      await tester.tap(key('month-presentation-grid'));
      await tester.pumpAndSettle();
      expect(
        containerOf(tester).read(monthPresentationProvider),
        MonthPresentation.grid,
      );
    });
  });

  group('paint modes and preview', () {
    String previewLabel(WidgetTester tester) =>
        tester.getSemantics(key('paint-preview')).label;

    String textOf(WidgetTester tester, String k) {
      final widget = tester.widget<Text>(key(k));
      return widget.data ?? widget.textSpan!.toPlainText();
    }

    testWidgets('Cambiar el turno | Añadir otro turno, with the effect drawn', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpCalendar(tester);
      await enterPaintMode(tester);
      final paint = paintOf(tester);
      final container = containerOf(tester);

      // The default: change the shift.
      expect(container.read(paintControllerProvider).doubling, isFalse);
      expect(find.text('Cambiar el turno'), findsOneWidget);
      expect(find.text('Añadir otro turno'), findsOneWidget);
      expect(textOf(tester, 'paint-mode-label'), ' · CAMBIAR EL TURNO');
      expect(previewLabel(tester), startsWith('Al tocar un día:'));
      expect(previewLabel(tester), contains('Sustituye al que haya'));
      final chosen = scheduleOf(tester)
          .shiftTypeById(container.read(paintControllerProvider).shiftTypeId!)!;
      expect(
        find.descendant(
          of: key('paint-preview-after'),
          matching: find.text(chosen.code),
        ),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(key('paint-preview')).label,
        contains('pasa a ${chosen.name}'),
      );
      var replace = tester.getSemantics(key('paint-mode-replace'));
      expect(
        replace.getSemanticsData().flagsCollection.isSelected,
        Tristate.isTrue,
      );

      // Add another shift (doblar): the preview and the header follow.
      await tester.tap(key('tool-double'));
      await tester.pumpAndSettle();
      expect(container.read(paintControllerProvider).doubling, isTrue);
      expect(textOf(tester, 'paint-mode-label'), ' · AÑADIR OTRO TURNO');
      expect(previewLabel(tester), startsWith('Al tocar un día (doblar):'));
      expect(previewLabel(tester), contains('Se suma al que ya hay'));
      final codes = tester
          .widgetList<Text>(
            find.descendant(
              of: key('paint-preview-after'),
              matching: find.byType(Text),
            ),
          )
          .map((t) => t.data)
          .toList();
      expect(codes, hasLength(2));
      expect(codes.last, chosen.code);
      final add = tester.getSemantics(key('tool-double'));
      expect(add.label, 'Añadir otro turno (doblar)');
      expect(
        add.getSemanticsData().flagsCollection.isSelected,
        Tristate.isTrue,
      );
      // Tapping the chosen mode again keeps it (a segmented control).
      await tester.tap(key('tool-double'));
      await tester.pumpAndSettle();
      expect(container.read(paintControllerProvider).doubling, isTrue);

      // Another shift: the preview changes with it.
      final other = container
          .read(scheduleControllerProvider)
          .palette
          .firstWhere((t) => t.id != chosen.id);
      paint.selectShift(other.id);
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(key('paint-preview')).label,
        contains(other.name),
      );

      // Back to change.
      await tester.tap(key('paint-mode-replace'));
      await tester.pumpAndSettle();
      expect(container.read(paintControllerProvider).doubling, isFalse);
      replace = tester.getSemantics(key('paint-mode-replace'));
      expect(
        replace.getSemanticsData().flagsCollection.isSelected,
        Tristate.isTrue,
      );
      handle.dispose();
    });

    testWidgets('the eraser: an empty day, and no mode to choose', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpCalendar(tester);
      await enterPaintMode(tester);
      await tester.tap(key('tool-eraser'));
      await tester.pumpAndSettle();
      expect(previewLabel(tester), contains('Deja el día vacío'));
      // The eraser has no mode: the header says the tool instead.
      expect(tester.widget<Text>(key('paint-mode-label')).data, ' · BORRAR');
      expect(
        find.descendant(
          of: key('paint-preview-after'),
          matching: find.byType(Text),
        ),
        findsNothing,
      );
      final add = tester.getSemantics(key('tool-double'));
      expect(
        add.getSemanticsData().flagsCollection.isEnabled,
        Tristate.isFalse,
      );
      await tester.tap(key('tool-double'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(
        containerOf(tester).read(paintControllerProvider).doubling,
        isFalse,
      );
      handle.dispose();
    });

    testWidgets('a tap in «Añadir otro turno» doubles the day', (tester) async {
      await pumpCalendar(tester);
      await enterPaintMode(tester);
      final before = idsOn(scheduleOf(tester), fixedToday);
      expect(before, isNotEmpty);
      final container = containerOf(tester);
      final chosen = container.read(paintControllerProvider).shiftTypeId!;
      await tester.tap(key('tool-double'));
      await tester.pumpAndSettle();
      await revealCell(tester, fixedToday);
      await tester.tap(cell(fixedToday));
      await tester.pumpAndSettle();
      expect(idsOn(scheduleOf(tester), fixedToday), '$before+$chosen');
      // Undo is right there, beside the preview.
      expect(tester.widget<IconButton>(key('undo')).onPressed, isNotNull);
      await tester.tap(key('undo'));
      await tester.pumpAndSettle();
      expect(idsOn(scheduleOf(tester), fixedToday), before);
      expect(tester.widget<IconButton>(key('redo')).onPressed, isNotNull);
    });

    for (final brightness in Brightness.values) {
      for (final (size, scale) in [
        (const Size(320, 640), 1.6),
        (const Size(320, 640), 2.0),
        (const Size(390, 844), 1.0),
      ]) {
        testWidgets(
          '${brightness.name}, ${size.width} dp, text x$scale: the bar fits',
          (tester) async {
            await pumpCalendar(
              tester,
              size: size,
              textScale: scale,
              brightness: brightness,
            );
            await enterPaintMode(tester);
            await tester.tap(key('tool-double'));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            for (final k in ['paint-mode-replace', 'tool-double']) {
              final rect = tester.getRect(key(k));
              expect(rect.height, greaterThanOrEqualTo(48));
              expect(rect.left, greaterThanOrEqualTo(0));
              expect(rect.right, lessThanOrEqualTo(size.width));
            }
            for (final k in ['undo', 'redo']) {
              final rect = tester.getRect(key(k));
              expect(rect.right, lessThanOrEqualTo(size.width));
              expect(rect.bottom, lessThanOrEqualTo(size.height));
            }
            // The cell of the preview uses the colours of this theme.
            final context = tester.element(key('paint-preview-after'));
            expect(context.colors.brightness, brightness);
          },
        );
      }
    }
  });

  group('change of month', () {
    testWidgets('the days fade in from the side, in 200 ms', (tester) async {
      await pumpCalendar(tester);
      await tester.tap(find.byTooltip('Mes siguiente'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final moving = tester
          .widgetList<Opacity>(
            find.ancestor(
              of: cell(const CivilDate(2026, 11, 10)),
              matching: find.byType(Opacity),
            ),
          )
          .first;
      expect(moving.opacity, lessThan(1));
      await tester.pumpAndSettle();
      final still = tester
          .widgetList<Opacity>(
            find.ancestor(
              of: cell(const CivilDate(2026, 11, 10)),
              matching: find.byType(Opacity),
            ),
          )
          .first;
      expect(still.opacity, 1);
    });

    testWidgets('at once with «reducir movimiento»', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      await pumpCalendar(tester);
      await tester.tap(find.byTooltip('Mes siguiente'));
      await tester.pump();
      final opacity = tester
          .widgetList<Opacity>(
            find.ancestor(
              of: cell(const CivilDate(2026, 11, 10)),
              matching: find.byType(Opacity),
            ),
          )
          .first;
      expect(opacity.opacity, 1);
    });
  });
}
