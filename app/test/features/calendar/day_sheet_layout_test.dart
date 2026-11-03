import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/core/theme/theme_context.dart';
import 'package:cuadrante/features/calendar/presentation/holiday_label.dart';
import 'package:cuadrante/features/calendar/application/schedule_controller.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/l10n/app_localizations_es.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/real_font.dart';
import '../../support/text_lines.dart';
import 'day_sheet_finders.dart';
import 'harness.dart';

/// The day sheet on the widths and text sizes of the QA campaign (T03): as
/// tall as its content (option 4A of 31 Oct) up to a cap, a header that
/// closes it when dragged, chips with whole names, menu entries that look
/// disabled when they are.
Finder get sheet => find.byType(BottomSheet);

void main() {
  setUpAll(() async {
    await initializeLocale();
    // Heights measured with Roboto: the test font is twice as wide and
    // wraps every line.
    expect(await loadRoboto(), isTrue, reason: 'Roboto from the Flutter SDK');
  });

  const oct21 = CivilDate(2026, 10, 21); // Mañana + Tarde
  const oct24 = CivilDate(2026, 10, 24); // Libre
  const widths = [320.0, 360.0, 412.0];
  const scales = [1.0, 1.3, 2.0];

  Size sizeFor(double width) => Size(width, width < 400 ? 640 : 892);

  Finder key(String k) => find.byKey(ValueKey(k));

  Future<void> open(WidgetTester tester, CivilDate date) async {
    await revealCell(tester, date);
    await tester.tap(cell(date));
    await tester.pumpAndSettle();
    expect(sheet, findsOneWidget);
  }

  List<String> paletteIds(WidgetTester tester) => [
    for (final s in containerOf(
      tester,
    ).read(scheduleControllerProvider).palette)
      s.id,
  ];

  group('H-T03-1: disabled moves look disabled', () {
    for (final brightness in Brightness.values) {
      testWidgets('${brightness.name}: first up and last down are dimmed', (
        tester,
      ) async {
        await pumpCalendar(tester, brightness: brightness);
        await open(tester, oct21);
        final tokens = tester.element(sheet).colors;

        Color? colorOf(String k) {
          final icon = find.descendant(of: key(k), matching: find.byType(Icon));
          return tester.widget<Icon>(icon).color;
        }

        bool enabled(String k) =>
            tester.widget<PopupMenuItem<Object?>>(key(k)).enabled;

        // Two shifts: up of the first and down of the last do nothing.
        await revealDayControl(tester, 'day-up-0');
        expect(enabled('day-up-0'), isFalse);
        expect(enabled('day-down-0'), isTrue);
        expect(colorOf('day-up-0'), tokens.disabledContent);
        expect(colorOf('day-down-0'), tokens.textSecondary);
        await dismissMenu(tester);
        await revealDayControl(tester, 'day-down-1');
        expect(enabled('day-down-1'), isFalse);
        expect(enabled('day-up-1'), isTrue);
        expect(colorOf('day-down-1'), tokens.disabledContent);
        expect(colorOf('day-up-1'), tokens.textSecondary);
        expect(tokens.disabledContent, isNot(tokens.textSecondary));
      });
    }
  });

  group('H-T03-2: the header closes the sheet', () {
    testWidgets('dragging the date down closes it', (tester) async {
      await pumpCalendar(tester);
      await open(tester, oct21);
      await tester.fling(
        find.text('Miércoles, 21 de octubre'),
        const Offset(0, 500),
        1500,
      );
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);
    });

    testWidgets('the body still scrolls without closing it', (tester) async {
      await pumpCalendar(tester, size: const Size(320, 640));
      await open(tester, oct21);
      // Unfolded, «Más opciones» makes the content taller than the sheet.
      await openDayMore(tester);
      final scrollable = find.descendant(
        of: sheet,
        matching: find.byType(Scrollable),
      );
      final vertical = scrollable.evaluate().firstWhere(
        (e) => (e.widget as Scrollable).axis == Axis.vertical,
      );
      final position = tester
          .state<ScrollableState>(find.byWidget(vertical.widget))
          .position;
      position.jumpTo(0);
      await tester.pump();
      // Dragging up on the first shift scrolls the body, down brings it back; the
      // sheet stays open the whole time.
      await tester.drag(key('day-shift-0'), const Offset(0, -150));
      await tester.pumpAndSettle();
      expect(position.pixels, greaterThan(0));
      expect(sheet, findsOneWidget);
      await tester.dragFrom(
        tester.getBottomLeft(sheet) + const Offset(160, -100),
        const Offset(0, 400),
      );
      await tester.pumpAndSettle();
      expect(position.pixels, 0);
      expect(sheet, findsOneWidget);
    });
  });

  group('H-T03-3: the holiday line does not repeat the word', () {
    final l10n = AppLocalizationsEs();

    test('a name that already says "festivo" stands alone', () {
      expect(holidayLine(l10n, 'Festivo propio'), 'Festivo propio');
      expect(holidayLine(l10n, 'festivo local'), 'festivo local');
      expect(holidaySpoken(l10n, 'Festivo propio'), 'Festivo propio');
    });

    test('any other name keeps the word', () {
      expect(
        holidayLine(l10n, 'Fiesta Nacional de España'),
        'Festivo: Fiesta Nacional de España',
      );
      expect(holidayLine(l10n, 'Cumple de Ana'), 'Festivo: Cumple de Ana');
      expect(holidaySpoken(l10n, 'Cumple de Ana'), 'festivo: Cumple de Ana');
    });

    testWidgets('a cell reads it once', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpCalendar(tester);
      await open(tester, oct24);
      await tapDayControl(tester, 'day-holiday-switch');
      await Navigator.of(tester.element(sheet)).maybePop();
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel(RegExp(r'festivo: Festivo propio')),
        findsNothing,
      );
      expect(
        find.bySemanticsLabel(
          RegExp(r'sábado 24 de octubre.*, Festivo propio'),
        ),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('H-T03-4 and H-T03-5: the chips', () {
    for (final width in widths) {
      for (final scale in scales) {
        testWidgets('at $width dp, text $scale: wrapped, whole names', (
          tester,
        ) async {
          await pumpCalendar(tester, size: sizeFor(width), textScale: scale);
          await open(tester, oct21);

          final ids = paletteIds(tester);
          final first = key('day-add-${ids.first}');
          await revealDayControl(tester, 'day-add-${ids.first}');

          // The chips wrap (H-T17-3): no sideways scroll, every chip inside
          // the sheet...
          final row = key('day-add-wrap');
          expect(
            find.descendant(
              of: row,
              matching: find.byType(SingleChildScrollView),
            ),
            findsNothing,
          );
          final sheetRect = tester.getRect(sheet);
          for (final id in ids) {
            await tester.ensureVisible(key('day-add-$id'));
            await tester.pumpAndSettle();
            final chip = tester.getRect(key('day-add-$id'));
            expect(chip.left, greaterThanOrEqualTo(sheetRect.left));
            expect(chip.right, lessThanOrEqualTo(sheetRect.right));
          }
          await tester.ensureVisible(first);
          await tester.pumpAndSettle();
          // ... and inside the palette panel, which lines up with the date.
          final panel = tester.getRect(key('day-palette'));
          final title = tester.getRect(find.text('Miércoles, 21 de octubre'));
          expect(panel.left, closeTo(title.left, 0.5));
          expect(tester.getRect(first).left, greaterThan(panel.left));

          // Every name is whole: no ellipsis, no word split.
          for (final id in ids) {
            final label = find.descendant(
              of: key('day-add-$id'),
              matching: find.byType(Text),
            );
            final paragraph = tester.renderObject<RenderParagraph>(label.last);
            expect(paragraph.didExceedMaxLines, isFalse, reason: '$id is cut');
            expect(
              wrapsOnlyBetweenWords(paragraph),
              isTrue,
              reason: '$id breaks a word',
            );
          }
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('4A: the height follows the content', () {
    double room(WidgetTester tester) =>
        tester.view.physicalSize.height / tester.view.devicePixelRatio;

    testWidgets('a simple day takes about half the screen and the month '
        'stays in sight', (tester) async {
      await pumpCalendar(tester);
      await open(tester, oct24); // Libre, nothing else
      final rect = tester.getRect(sheet);
      expect(rect.height, lessThan(room(tester) * 0.6));
      // Not the old fixed 88 %.
      expect(rect.height, lessThan(room(tester) * 0.88 - 1));
      expect(rect.bottom, closeTo(room(tester), 0.5));
      // The first weeks of the month are still in sight above the sheet.
      expect(
        tester.getRect(cell(const CivilDate(2026, 10, 5))).top,
        lessThan(rect.top),
      );
    });

    testWidgets('it grows with «Más opciones» and shrinks back', (
      tester,
    ) async {
      await pumpCalendar(tester);
      await open(tester, oct24);
      final folded = tester.getRect(sheet).height;
      await openDayMore(tester);
      final unfolded = tester.getRect(sheet).height;
      expect(unfolded, greaterThan(folded + 100));
      await tester.tap(key('day-more'));
      await tester.pumpAndSettle();
      expect(tester.getRect(sheet).height, closeTo(folded, 0.5));
    });

    for (final (width, height, scale) in [
      for (final width in widths)
        for (final scale in scales) (width, sizeFor(width).height, scale),
      (412.0, 1600.0, 1.0),
    ]) {
      testWidgets('at ${width}x$height dp, text $scale: never above the cap, '
          'and what does not fit scrolls', (tester) async {
        await pumpCalendar(tester, size: Size(width, height), textScale: scale);
        await open(tester, oct21);
        await revealDayControl(tester, 'day-add-${paletteIds(tester).first}');
        await openDayMore(tester);
        final rect = tester.getRect(sheet);
        expect(rect.height, lessThanOrEqualTo(room(tester) * 0.88 + 0.5));
        // The last control can be reached.
        await tester.ensureVisible(key('day-clear'));
        await tester.pumpAndSettle();
        final clear = tester.getRect(key('day-clear'));
        expect(clear.bottom, lessThanOrEqualTo(rect.bottom));
        expect(clear.top, greaterThanOrEqualTo(rect.top));
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('point 5: the sheet respects the keyboard (viewInsets)', () {
    testWidgets('with the keyboard up the body ends above it', (tester) async {
      await pumpCalendar(tester);
      await open(tester, oct21);
      await revealDayControl(tester, 'day-note');
      await tester.tap(key('day-note'));
      await tester.pumpAndSettle();

      // Without a keyboard the body reaches the bottom of the screen...
      final room =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      expect(tester.getRect(key('day-sheet-body')).bottom, closeTo(room, 1));

      // ...and with one up it stops above it (viewInsets, not padding).
      const keyboard = 340.0;
      tester.view.viewInsets = FakeViewPadding(
        bottom: keyboard * tester.view.devicePixelRatio,
      );
      addTearDown(() => tester.view.resetViewInsets());
      await tester.pumpAndSettle();

      await tester.ensureVisible(key('day-note'));
      await tester.pumpAndSettle();
      final body = tester.getRect(key('day-sheet-body'));
      expect(body.bottom, lessThanOrEqualTo(room - keyboard + 0.5));
      final note = tester.getRect(key('day-note'));
      expect(note.bottom, lessThanOrEqualTo(body.bottom + 0.5));
      expect(note.top, greaterThanOrEqualTo(body.top));
      expect(tester.takeException(), isNull);
    });
  });
}
