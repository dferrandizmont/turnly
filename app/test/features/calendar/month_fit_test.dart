import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/features/calendar/application/month_presentation.dart';
import 'package:cuadrante/features/calendar/presentation/month_fit.dart';
import 'package:cuadrante/features/calendar/presentation/paint_bar.dart';
import 'package:cuadrante/features/calendar/presentation/today_card.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/real_font.dart';
import 'harness.dart';

/// Decision 28 (`docs/preguntas.md`): the grid rules. The whole month fits
/// without scrolling in the two modes; what gives way is the card of today
/// (folded by default when the month would not fit) and the paint sheet
/// (it takes what the rows leave, never the other way round).
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeLocale();
    expect(await loadRoboto(), isTrue, reason: 'Roboto from the Flutter SDK');
  });

  // A Pixel 9: 1080 x 2424 px at 2.625, a status bar and the gesture bar.
  const pixel9 = Size(1080 / 2.625, 2424 / 2.625);
  const pixel9Insets = EdgeInsets.only(top: 32, bottom: 24);

  Finder key(String id) => find.byKey(ValueKey(id));
  bool folded() => key('today-card-collapsed').evaluate().isNotEmpty;
  bool open() => key('today-card-open').evaluate().isNotEmpty;

  /// Every day of the six rows of October 2026 (28 Sep - 8 Nov).
  Iterable<CivilDate> gridDays() sync* {
    for (var i = 0; i < 42; i++) {
      yield const CivilDate(2026, 9, 28).addDays(i);
    }
  }

  ScrollableState monthScrollable(WidgetTester tester) => tester.state(
    find
        .descendant(of: key('month-scroll'), matching: find.byType(Scrollable))
        .first,
  );

  Rect scrollViewport(WidgetTester tester) =>
      tester.getRect(key('month-scroll'));

  void expectWholeMonth(WidgetTester tester, {required String why}) {
    final viewport = scrollViewport(tester);
    for (final day in gridDays()) {
      final rect = tester.getRect(cell(day));
      expect(
        rect.top >= viewport.top - 0.01 &&
            rect.bottom <= viewport.bottom + 0.01,
        isTrue,
        reason: '$day is cut ($why): $rect in $viewport',
      );
      expect(
        cell(day).hitTestable(),
        findsOneWidget,
        reason: '$day cannot be hit ($why)',
      );
    }
    final scrollable = monthScrollable(tester);
    expect(
      scrollable.position.maxScrollExtent,
      lessThan(0.5),
      reason: 'the month does not scroll ($why)',
    );
  }

  group('the card of today starts folded when the month would not fit', () {
    testWidgets('a Pixel 9: folded, and the whole month is in view', (
      tester,
    ) async {
      await pumpCalendar(
        tester,
        size: pixel9,
        pixelRatio: 2.625,
        insets: pixel9Insets,
        openCard: false,
      );
      expect(folded(), isTrue);
      expect(open(), isFalse);
      expectWholeMonth(tester, why: 'folded card');
      // Only the month: no tip, no extra row between the card and the month.
      expect(key('onboarding-tip'), findsNothing);
    });

    testWidgets('390 x 844 dp: folded', (tester) async {
      await pumpCalendar(tester, size: const Size(390, 844), openCard: false);
      expect(folded(), isTrue);
      expectWholeMonth(tester, why: '390 x 844');
    });

    testWidgets('a tall tablet: open, as it was', (tester) async {
      await pumpCalendar(
        tester,
        size: const Size(768, 1024),
        insets: const EdgeInsets.only(top: 24, bottom: 20),
        openCard: false,
      );
      expect(open(), isTrue);
      expect(folded(), isFalse);
      expectWholeMonth(tester, why: 'tablet with the card open');
    });

    testWidgets('large text on a phone: folded', (tester) async {
      await pumpCalendar(
        tester,
        size: pixel9,
        pixelRatio: 2.625,
        insets: pixel9Insets,
        textScale: 2.0,
        openCard: false,
      );
      expect(folded(), isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the rule never reads the keyboard: it does not flip', (
      tester,
    ) async {
      await pumpCalendar(
        tester,
        size: const Size(768, 1024),
        insets: const EdgeInsets.only(top: 24, bottom: 20),
        openCard: false,
      );
      expect(open(), isTrue);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300 * 3);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(open(), isTrue);
    });

    testWidgets('the person\'s choice wins, and it is remembered', (
      tester,
    ) async {
      await pumpCalendar(
        tester,
        size: pixel9,
        pixelRatio: 2.625,
        insets: pixel9Insets,
        openCard: false,
      );
      expect(folded(), isTrue);
      // Opened by hand where it does not fit: it stays open, the month
      // scrolls under the pinned row of the month.
      await tester.tap(key('today-card-toggle'));
      await tester.pumpAndSettle();
      expect(open(), isTrue);
      final container = containerOf(tester);
      expect(container.read(todayCardCollapsedProvider), isFalse);
      final scrollable = tester.state<ScrollableState>(
        find
            .descendant(
              of: key('month-scroll'),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(scrollable.position.maxScrollExtent, greaterThan(0));
      final pinned = tester.getRect(key('month-pinned-header'));
      await tester.drag(key('month-scroll'), const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(key('month-pinned-header')).top,
        lessThan(pinned.top),
      );
      expect(
        key('month-pinned-header').hitTestable(),
        findsOneWidget,
        reason: 'the row of the month stays fixed',
      );
      expect(
        tester.getRect(cell(const CivilDate(2026, 11, 8))).bottom,
        lessThanOrEqualTo(scrollViewport(tester).bottom + 0.01),
      );
    });

    testWidgets('folded by choice where it would fit', (tester) async {
      await pumpCalendar(
        tester,
        size: const Size(768, 1024),
        insets: const EdgeInsets.only(top: 24, bottom: 20),
        openCard: false,
      );
      await tester.tap(key('today-card-toggle'));
      await tester.pumpAndSettle();
      expect(folded(), isTrue);
      expect(containerOf(tester).read(todayCardCollapsedProvider), isTrue);
    });

    testWidgets('the estimate of the open card is the real height', (
      tester,
    ) async {
      await pumpCalendar(
        tester,
        size: pixel9,
        pixelRatio: 2.625,
        insets: pixel9Insets,
      );
      expect(open(), isTrue);
      final card = tester.getSize(find.byType(TodayCard)).height;
      final estimate = TodayCard.openHeightEstimate(
        tester.element(find.byType(TodayCard)),
      );
      // The card of a day with a shift, the usual one.
      expect(estimate, closeTo(card, 28));
      // It is the 200-240 dp the decision talks about.
      expect(estimate, inInclusiveRange(200, 260));
    });
  });

  group('the fixed row under the grid', () {
    testWidgets('the button floats over it, never over a day', (tester) async {
      await pumpCalendar(
        tester,
        size: pixel9,
        pixelRatio: 2.625,
        insets: pixel9Insets,
        openCard: false,
      );
      final fab = tester.getRect(find.byType(FloatingActionButton));
      final row = tester.getRect(key('month-select-days'));
      final bar = tester.getRect(key('month-nav-bar'));
      for (final day in gridDays()) {
        expect(
          tester.getRect(cell(day)).bottom,
          lessThanOrEqualTo(fab.top + 0.01),
          reason: '$day is under the button',
        );
      }
      // «Seleccionar días» and the button share the row: 56 + 8 dp at least.
      expect(bar.top - fab.top, greaterThanOrEqualTo(56 + 8));
      expect(row.bottom, closeTo(bar.top, 0.01));
    });
  });

  group('paint mode', () {
    testWidgets('a Pixel 9: all six rows in view, the sheet under them', (
      tester,
    ) async {
      await pumpCalendar(
        tester,
        size: pixel9,
        pixelRatio: 2.625,
        insets: pixel9Insets,
      );
      await enterPaintMode(tester);
      expectWholeMonth(tester, why: 'paint mode');
      // Nothing to scroll: no arrows.
      expect(key('paint-scroll-up'), findsNothing);
      expect(key('paint-scroll-down'), findsNothing);

      final sheet = tester.getRect(find.byType(PaintBar));
      final lastRow = tester.getRect(cell(const CivilDate(2026, 11, 8)));
      expect(sheet.top, greaterThanOrEqualTo(lastRow.bottom));
      expect(sheet.bottom, closeTo(pixel9.height, 0.01));
      // The floor of the sheet and the room the rows leave.
      final context = tester.element(find.byType(PaintBar));
      expect(sheet.height, greaterThanOrEqualTo(PaintBar.minHeight(context)));
      expect(sheet.height, lessThan(pixel9.height * 0.4));

      // The modes and the preview with undo / redo are fixed; the pucks are
      // reachable: only their area scrolls, vertically.
      for (final id in ['paint-mode-replace', 'tool-double', 'undo', 'redo']) {
        expect(key(id).hitTestable(), findsOneWidget, reason: id);
      }
      final tools = tester.widget<SingleChildScrollView>(
        key('paint-tools-scroll'),
      );
      expect(tools.scrollDirection, Axis.vertical);
      // The chosen shift is in view as the sheet opens.
      expect(key('tool-morning').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the same in the month of six weeks (November)', (
      tester,
    ) async {
      await pumpCalendar(
        tester,
        size: pixel9,
        pixelRatio: 2.625,
        insets: pixel9Insets,
        clock: () => DateTime(2026, 11, 1, 12),
      );
      await enterPaintMode(tester);
      final viewport = scrollViewport(tester);
      // 26 Oct - 6 Dec: all of November and the six rows.
      for (var i = 0; i < 42; i++) {
        final day = const CivilDate(2026, 10, 26).addDays(i);
        final rect = tester.getRect(cell(day));
        expect(rect.bottom, lessThanOrEqualTo(viewport.bottom + 0.01));
        expect(cell(day).hitTestable(), findsOneWidget, reason: '$day');
      }
    });

    testWidgets('the sheet has the same height whichever tool is chosen', (
      tester,
    ) async {
      await pumpCalendar(
        tester,
        size: pixel9,
        pixelRatio: 2.625,
        insets: pixel9Insets,
      );
      await enterPaintMode(tester);
      final height = tester.getSize(find.byType(PaintBar)).height;
      final top = tester.getTopLeft(key('month-scroll')).dy;
      for (final id in ['tool-eraser', 'tool-night', 'tool-double']) {
        await tester.tap(key(id));
        await tester.pumpAndSettle();
        expect(
          tester.getSize(find.byType(PaintBar)).height,
          closeTo(height, 0.01),
        );
        expect(tester.getTopLeft(key('month-scroll')).dy, closeTo(top, 0.01));
      }
    });

    testWidgets('text x2: the fallback keeps the old behaviour', (
      tester,
    ) async {
      await pumpCalendar(
        tester,
        size: pixel9,
        pixelRatio: 2.625,
        insets: pixel9Insets,
        textScale: 2.0,
      );
      await enterPaintMode(tester);
      expect(tester.takeException(), isNull);
      // The month scrolls above the sheet and the arrows say so.
      final scrollable = tester.state<ScrollableState>(
        find
            .descendant(
              of: key('month-scroll'),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(scrollable.position.maxScrollExtent, greaterThan(0));
      expect(key('paint-scroll-down').hitTestable(), findsOneWidget);
      // The pucks keep within a quarter of the screen, as before.
      expect(
        tester.getSize(key('paint-tools-scroll')).height,
        lessThanOrEqualTo(pixel9.height * 0.25 + 0.5),
      );
    });

    testWidgets('the list view is as it was', (tester) async {
      await pumpCalendar(
        tester,
        size: pixel9,
        pixelRatio: 2.625,
        insets: pixel9Insets,
      );
      containerOf(tester)
          .read(monthPresentationProvider.notifier)
          .choose(MonthPresentation.list);
      await tester.pumpAndSettle();
      await enterPaintMode(tester);
      expect(tester.takeException(), isNull);
      expect(key('paint-scroll-up'), findsNothing);
      expect(find.byType(PaintBar), findsOneWidget);
    });
  });

  test('the model of the month adds up', () {
    // The rows of the grid are always six, so the rule does not depend on
    // the weeks of the month.
    expect(MonthFit.monthGridRows, 6);
    expect(MonthFit.fixedRow, greaterThanOrEqualTo(56 + 8));
  });
}
