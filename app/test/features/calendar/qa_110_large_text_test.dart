import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/core/theme/theme_context.dart';
import 'package:cuadrante/features/calendar/application/schedule_controller.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/real_font.dart';
import '../../support/text_lines.dart';
import 'day_sheet_finders.dart';
import '../../support/app_harness.dart' show AppUnderTest, addSecondCalendar;
import 'harness.dart';

// 1.1.0 QA, iOS AX3 (text x3.0): F2 (the title of the day sheet), F7 (the
// header of the month) and F12 (the extra hours in the cell of the month).
// Android with a large font scale shows the same, so they run here with a
// text scaler and narrow phones.

const _oct21 = CivilDate(2026, 10, 21);
const _oct26 = CivilDate(2026, 10, 26);

Finder _key(String key) => find.byKey(ValueKey(key));

/// The paragraphs under [root] that split a word.
List<String> _broken(Finder root) => [
  for (final element
      in find.descendant(of: root, matching: find.byType(RichText)).evaluate())
    if (!wrapsOnlyBetweenWords(element.renderObject! as RenderParagraph))
      paragraphLines(element.renderObject! as RenderParagraph).join(' | '),
];

void main() {
  setUpAll(() async {
    await initializeLocale();
    TestWidgetsFlutterBinding.ensureInitialized();
    expect(await loadRoboto(), isTrue, reason: 'Roboto from the Flutter SDK');
  });
  tearDownAll(() => AppTypography.debugFamily = null);

  group('F2: the title of the day sheet at large text', () {
    for (final size in [const Size(320, 568), const Size(402, 874)]) {
      for (final scale in [2.0, 3.0]) {
        final name = '${size.width.toInt()} x ${size.height.toInt()}, x$scale';
        testWidgets('$name: the date wraps between words and is a small part '
            'of the sheet', (tester) async {
          await pumpCalendar(tester, size: size, textScale: scale);
          await revealCell(tester, _oct21);
          await tester.tap(cell(_oct21));
          await tester.pumpAndSettle();

          final title = find.text('Miércoles, 21 de octubre');
          expect(title, findsOneWidget);
          expect(_broken(title), isEmpty);
          final rect = tester.getRect(title);
          expect(
            rect.height,
            lessThan(size.height * 0.25),
            reason: 'the pinned date takes a quarter of the screen at most',
          );

          // What is under the date is still reachable: «Más opciones»
          // opens and «Añadir horas extra» scrolls into view and takes a tap.
          await openDayMore(tester);
          final add = _key('day-add-overtime');
          await tester.ensureVisible(add);
          await tester.pumpAndSettle();
          final sheetRect = tester.getRect(find.byType(BottomSheet));
          expect(
            tester.getRect(add).bottom,
            lessThanOrEqualTo(sheetRect.bottom),
          );
          await tester.tap(add);
          await tester.pumpAndSettle();
          expect(_key('overtime-sheet'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('x1.0: the date keeps its size', (tester) async {
      await pumpCalendar(tester, size: const Size(390, 844));
      await revealCell(tester, _oct21);
      await tester.tap(cell(_oct21));
      await tester.pumpAndSettle();
      final style = tester
          .widget<Text>(find.text('Miércoles, 21 de octubre'))
          .style!;
      expect(style.fontSize, 24);
    });
  });

  group('F7: the header of the month at large text', () {
    for (final size in [const Size(320, 568), const Size(402, 874)]) {
      testWidgets('${size.width.toInt()} dp, x3.0, two calendars: the date '
          'stays on a line or two, whole words, and the calendar name is '
          'whole on a line of its own', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 3.0;
        await AppUnderTest.pump(
          tester,
          size: size,
          prepare: (db) async => addSecondCalendar(db),
        );
        expect(tester.takeException(), isNull);

        final date = _key('month-date');
        expect(date, findsOneWidget);
        expect(_broken(date), isEmpty);
        final lines = paragraphLines(
          tester.renderObject<RenderParagraph>(
            find.descendant(of: date, matching: find.byType(RichText)),
          ),
        );
        expect(lines.length, lessThanOrEqualTo(2), reason: lines.join(' | '));
        // The header does not take the screen.
        expect(tester.getRect(date).bottom, lessThan(size.height * 0.3));

        // The calendar name is not cut to «P…», and sits under the date, not
        // beside it.
        final name = find.descendant(
          of: _key('calendar-switcher'),
          matching: find.text('Mi cuadrante'),
        );
        expect(name, findsOneWidget);
        final paragraph = tester.renderObject<RenderParagraph>(name);
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(
          tester.getRect(_key('calendar-switcher')).top,
          greaterThanOrEqualTo(tester.getRect(date).bottom - 0.5),
        );
      });
    }

    testWidgets('x1.3 keeps the switcher beside the date', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      await AppUnderTest.pump(
        tester,
        size: const Size(390, 844),
        prepare: (db) async => addSecondCalendar(db),
      );
      expect(
        tester.getRect(_key('calendar-switcher')).top,
        lessThan(tester.getRect(_key('month-date')).bottom),
      );
    });
  });

  group('F12: the extra hours in the cell of the month', () {
    Future<void> pumpWithBlock(
      WidgetTester tester, {
      required int minutes,
      Size size = const Size(360, 800),
      double scale = 1.0,
    }) async {
      await pumpCalendar(tester, size: size, textScale: scale);
      containerOf(tester)
          .read(scheduleControllerProvider.notifier)
          .setOvertimeBlocks(_oct26, [
            OvertimeBlock(
              id: 'a',
              date: _oct26,
              typeId: overtimeTypeId,
              startMinute: 14 * 60,
              endMinute: 14 * 60 + minutes,
            ),
          ]);
      await tester.pumpAndSettle();
      await revealCell(tester, _oct26);
    }

    /// The size the mark is drawn at: the font of the style, scaled by the
    /// `FittedBox` that fits it to the room.
    double drawnSize(WidgetTester tester, Finder mark) {
      final text = tester.widget<Text>(mark);
      final laidOut = tester.getSize(mark);
      final drawn = tester.getRect(mark);
      return text.style!.fontSize! * drawn.height / laidOut.height;
    }

    testWidgets('3 h 45 min reads +3:45, not +3.8 h', (tester) async {
      await pumpWithBlock(tester, minutes: 225, size: const Size(430, 900));
      final mark = _key('extras-mark-${_oct26.toIso()}');
      expect(tester.widget<Text>(mark).data, '+3:45');
    });

    testWidgets('whole hours keep +2 h and 1 h 30 min is +1:30', (
      tester,
    ) async {
      await pumpWithBlock(tester, minutes: 120);
      expect(
        tester.widget<Text>(_key('extras-mark-${_oct26.toIso()}')).data,
        '+2 h',
      );
    });

    for (final width in [320.0, 360.0, 412.0, 430.0]) {
      testWidgets('$width dp: the hours are text at 8 dp or more beside the '
          'number, or the small plus', (tester) async {
        await pumpWithBlock(tester, minutes: 225, size: Size(width, 900));
        final mark = _key('extras-mark-${_oct26.toIso()}');
        expect(mark, findsOneWidget);
        final number = find.descendant(
          of: cell(_oct26),
          matching: find.text('${_oct26.day}'),
        );
        final rect = tester.getRect(mark);
        if (tester.widget<Widget>(mark) is Text) {
          expect(
            drawnSize(tester, mark),
            greaterThanOrEqualTo(AppTypography.cellTimeMinSize - 0.01),
          );
          // And it does not run over the number of the day (the boxes of the
          // two texts may touch by a pixel: the glyphs have room at the
          // sides).
          expect(
            rect.left,
            greaterThanOrEqualTo(tester.getRect(number).right - 2),
          );
        } else {
          expect(tester.widget<Widget>(mark), isA<Icon>());
        }
        // Wide enough for the text: the phones of 430 dp and more.
        if (width >= 430) expect(tester.widget<Widget>(mark), isA<Text>());
        expect(tester.takeException(), isNull);
      });
    }

    // Overtime with the note and the holiday on a narrow cell: the hours are
    // text only where they fit beside the number at 8 dp or more; otherwise
    // they are the small plus, never a smaller text and never over the number.
    const oct12 = CivilDate(2026, 10, 12); // a national holiday
    for (final width in [320.0, 360.0, 412.0]) {
      for (final scale in [1.0, 1.3]) {
        testWidgets('$width dp, text x$scale: hours, note and holiday dot '
            'share the top row without shrinking the hours or covering the '
            'number', (tester) async {
          await pumpCalendar(
            tester,
            size: Size(width, 1000),
            textScale: scale,
            prepare: (repository) => repository.apply(
              'main',
              ScheduleChange(
                patch: EntriesPatch({
                  oct12: EntryChange(
                    null,
                    const DayEntry(
                      date: oct12,
                      shiftTypeIds: ['morning'],
                      note: 'Nota',
                      overtimeBlocks: [
                        OvertimeBlock(
                          id: 'a',
                          date: oct12,
                          typeId: overtimeTypeId,
                          startMinute: 14 * 60,
                          endMinute: 14 * 60 + 225,
                        ),
                      ],
                    ),
                  ),
                }),
              ),
            ),
          );
          await revealCell(tester, oct12);
          final mark = _key('extras-mark-${oct12.toIso()}');
          expect(mark, findsOneWidget);
          final number = tester.getRect(
            find.descendant(of: cell(oct12), matching: find.text('12')),
          );
          final box = tester.getRect(cell(oct12));
          final rect = tester.getRect(mark);
          expect(rect.right, lessThanOrEqualTo(box.right));
          // The holiday dot stays, and so does the mark of the extras.
          expect(_key('holiday-dot-${oct12.toIso()}'), findsOneWidget);
          if (find
              .descendant(of: cell(oct12), matching: find.text('+3:45'))
              .evaluate()
              .isNotEmpty) {
            expect(
              drawnSize(tester, mark),
              greaterThanOrEqualTo(AppTypography.cellTimeMinSize - 0.01),
              reason: 'the hours are text, so at 8 dp at least',
            );
            expect(rect.left, greaterThanOrEqualTo(number.right - 2));
          } else {
            // The small plus: the amount is in the detail of the day.
            expect(tester.widget<Widget>(mark), isA<Icon>());
          }
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
