import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/core/icons/app_icons.dart';
import 'package:cuadrante/features/calendar/presentation/day_cell.dart';
import 'package:cuadrante/features/calendar/presentation/month_grid.dart';
import 'package:cuadrante/features/schedule/data/schedule_repository.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/features/settings/application/preferences_controller.dart';
import 'package:cuadrante/features/settings/domain/preferences.dart';
import 'package:cuadrante/l10n/app_localizations_es.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

/// «Ver la nota en el mes» (UX · Extras visuales): with the preference on the
/// first line of the note is written in the cell (in place of its clip): beside
/// the day number where the cell is wide, on a line of its own at the bottom
/// of the cell where it is narrow (a phone in portrait, an iPhone in
/// landscape next to the side panel). The month grid gives the row of such a
/// day the room of that line, so the code and the time keep their size. With
/// the setting off the cell keeps the clip of always. It never overflows, at
/// the campaign sizes, with large text and in both themes; where even the
/// grown row is not enough, the clip stays.
void main() {
  setUpAll(initializeLocale);

  const noted = CivilDate(2026, 10, 20);
  const note = 'Compra y farmacia\nsegunda línea que no cabe';

  // The week of the noted day only has single-shift days: its neighbour has
  // the same shift and no note. The next week (it starts on Monday 26) holds a
  // day of two shifts with a note (and its twin without one), an empty day
  // with a note and another day with a note, all in the same row.
  const neighbour = CivilDate(2026, 10, 21);
  const multi = CivilDate(2026, 10, 27);
  const multiTwin = CivilDate(2026, 10, 29);
  const empty = CivilDate(2026, 10, 28);
  const another = CivilDate(2026, 10, 30);

  Future<void> prepare(ScheduleRepository repository) => repository.apply(
    'main',
    ScheduleChange(
      patch: EntriesPatch({
        noted: EntryChange(
          null,
          const DayEntry(date: noted, shiftTypeIds: ['morning'], note: note),
        ),
        neighbour: EntryChange(
          null,
          const DayEntry(date: neighbour, shiftTypeIds: ['morning']),
        ),
        multi: EntryChange(
          null,
          const DayEntry(
            date: multi,
            shiftTypeIds: ['morning', 'night'],
            note: 'Reunión de equipo',
          ),
        ),
        multiTwin: EntryChange(
          null,
          const DayEntry(date: multiTwin, shiftTypeIds: ['morning', 'night']),
        ),
        empty: EntryChange(
          null,
          const DayEntry(date: empty, shiftTypeIds: [], note: 'Dentista 10:30'),
        ),
        another: EntryChange(
          null,
          const DayEntry(
            date: another,
            shiftTypeIds: ['morning'],
            note: 'Cumpleaños de Marta',
          ),
        ),
      }),
    ),
  );

  List<Override> withNote(
    bool on, {
    bool weekNumbers = false,
    CellTextSize cellTextSize = CellTextSize.normal,
  }) => [
    initialPreferencesProvider.overrideWithValue(
      Preferences(
        showNoteInMonth: on,
        weekNumbers: weekNumbers,
        cellTextSize: cellTextSize,
      ),
    ),
  ];

  Finder noteTextOf(CivilDate date) =>
      find.byKey(ValueKey('note-text-${date.toIso()}'));

  Finder clipOf(CivilDate date) =>
      find.descendant(of: cell(date), matching: find.byIcon(AppIcons.note));

  Finder codeOf(CivilDate date, String code) =>
      find.descendant(of: cell(date), matching: find.text(code));

  Finder noteText() => noteTextOf(noted);
  Finder cellClip() => clipOf(noted);

  Finder cellTime() => find.descendant(
    of: cell(noted),
    matching: find.byWidgetPredicate(
      (w) => w is Text && (w.data ?? '').contains('–'),
    ),
  );

  /// The size the code is really drawn at: its font size and the height it
  /// takes on screen (so a code squeezed by a FittedBox shows too).
  (double font, double height) codeSizeOf(
    WidgetTester tester,
    CivilDate date,
    String code,
  ) {
    final finder = codeOf(date, code);
    expect(finder, findsOneWidget, reason: 'código $code en $date');
    return (
      tester.widget<Text>(finder).style!.fontSize!,
      tester.getSize(finder).height,
    );
  }

  void expectSameCode(
    WidgetTester tester,
    CivilDate a,
    CivilDate b,
    String code,
  ) {
    final (fontA, heightA) = codeSizeOf(tester, a, code);
    final (fontB, heightB) = codeSizeOf(tester, b, code);
    expect(fontA, closeTo(fontB, 0.01), reason: 'tamaño del código $code');
    expect(heightA, closeTo(heightB, 0.01), reason: 'altura del código $code');
  }

  /// The note line of [date] sits under the code and the time of the last
  /// band, inside the cell, and nothing overlaps it.
  void expectNoteLineClear(
    WidgetTester tester,
    CivilDate date, {
    required String code,
    String? time,
  }) {
    final box = tester.getRect(cell(date));
    final line = tester.getRect(noteTextOf(date));
    expect(line.bottom, lessThanOrEqualTo(box.bottom + 0.01));
    expect(line.left, greaterThanOrEqualTo(box.left - 0.01));
    expect(line.right, lessThanOrEqualTo(box.right + 0.01));
    final codeRect = tester.getRect(codeOf(date, code).first);
    expect(line.top, greaterThanOrEqualTo(codeRect.bottom - 0.01));
    if (time != null) {
      // The whole range (06–14) or, in a narrow cell, only its start.
      final timeFinder = find.descendant(
        of: cell(date),
        matching: find.byWidgetPredicate(
          (w) => w is Text && (w.data ?? '').startsWith(time),
        ),
      );
      expect(timeFinder, findsOneWidget, reason: 'hora $time visible');
      expect(
        line.top,
        greaterThanOrEqualTo(tester.getRect(timeFinder).bottom - 0.01),
      );
    }
  }

  testWidgets('on, wide cell: the first line is at the bottom, as on a phone', (
    tester,
  ) async {
    await pumpCalendar(
      tester,
      size: const Size(768, 1000),
      prepare: prepare,
      overrides: withNote(true),
    );
    await revealCell(tester, noted);

    expect(noteText(), findsOneWidget);
    expect(tester.widget<Text>(noteText()).data, 'Compra y farmacia');
    // The clip of always gives way to the text.
    expect(cellClip(), findsNothing);
    // The same place as on a phone (iPad QA F4): the foot of the cell, not
    // beside the day number.
    final box = tester.getRect(cell(noted));
    expect(tester.getCenter(noteText()).dy, greaterThan(box.center.dy));
    expectNoteLineClear(tester, noted, code: 'M', time: '06');
    expect(tester.takeException(), isNull);
  });

  testWidgets('on, wide cell in landscape: the note is still at the foot', (
    tester,
  ) async {
    await pumpCalendar(
      tester,
      size: const Size(1200, 800),
      prepare: prepare,
      overrides: withNote(true),
    );
    await revealCell(tester, noted);

    expect(noteText(), findsOneWidget);
    final box = tester.getRect(cell(noted));
    expect(tester.getCenter(noteText()).dy, greaterThan(box.center.dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'on, phone: the first line is written at the bottom of the cell',
    (tester) async {
      await pumpCalendar(tester, prepare: prepare, overrides: withNote(true));
      await revealCell(tester, noted);

      expect(noteText(), findsOneWidget);
      expect(tester.widget<Text>(noteText()).data, 'Compra y farmacia');
      expect(cellClip(), findsNothing);
      final box = tester.getRect(cell(noted));
      final line = tester.getRect(noteText());
      // On its own line at the bottom, across (almost) the whole cell width,
      // never over the code or the time.
      expect(line.center.dy, greaterThan(box.center.dy));
      expect(line.bottom, lessThanOrEqualTo(box.bottom));
      expect(line.width, greaterThan(box.width * 0.75));
      expectNoteLineClear(tester, noted, code: 'M', time: '06');
      expect(cellTime(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('on, phone: the code and the time stay in the noted cell', (
    tester,
  ) async {
    await pumpCalendar(tester, prepare: prepare, overrides: withNote(true));
    await revealCell(tester, noted);

    expect(codeOf(noted, 'M'), findsOneWidget);
    expect(cellTime(), findsOneWidget);
    expect(noteText(), findsOneWidget);
    // The spoken label of the cell still mentions the note.
    final handle = tester.ensureSemantics();
    expect(
      find.descendant(
        of: cell(noted),
        matching: find.bySemanticsLabel(
          RegExp(RegExp.escape(AppLocalizationsEs().daySemanticsNote)),
        ),
      ),
      findsOneWidget,
    );
    handle.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('off: the cell keeps the clip, writes no text and rows stay', (
    tester,
  ) async {
    await pumpCalendar(tester, prepare: prepare, overrides: withNote(false));
    await revealCell(tester, noted);

    expect(noteText(), findsNothing);
    expect(cellClip(), findsOneWidget);
    expect(clipOf(multi), findsOneWidget);
    expect(clipOf(empty), findsOneWidget);
    // The row of the noted day is not taller than any other plain row.
    expect(
      tester.getSize(cell(noted)).height,
      closeTo(tester.getSize(cell(neighbour)).height, 0.01),
    );
    expect(tester.takeException(), isNull);
  });

  // The grid gives the row of a noted day the room of the note line, so the
  // code of that cell is as big as the one of its neighbour (a phone in
  // portrait and a small phone, with and without larger text).
  for (final (size, scale) in [
    (const Size(390, 844), 1.0),
    (const Size(390, 844), 1.3),
    (const Size(320, 568), 1.0),
    (const Size(320, 568), 1.3),
  ]) {
    testWidgets(
      'on, ${size.width.toInt()}x${size.height.toInt()}, text x$scale: the '
      "text is written and the code is as big as the neighbour's",
      (tester) async {
        await pumpCalendar(
          tester,
          size: size,
          textScale: scale,
          prepare: prepare,
          overrides: withNote(true),
        );
        await revealCell(tester, noted);

        expect(noteText(), findsOneWidget, reason: 'texto de la nota');
        expect(cellClip(), findsNothing, reason: 'sin el clip');
        expect(tester.widget<Text>(noteText()).data, 'Compra y farmacia');
        expectSameCode(tester, noted, neighbour, 'M');
        expectNoteLineClear(tester, noted, code: 'M', time: '06');
        // Same row, same height.
        expect(
          tester.getSize(cell(noted)).height,
          closeTo(tester.getSize(cell(neighbour)).height, 0.01),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  // The iPhone in landscape: the month shares the screen with the side panel
  // and the rail, so its cells are about as narrow as in portrait.
  for (final (size, scale) in [
    (const Size(932, 430), 1.0),
    (const Size(932, 430), 1.3),
    (const Size(844, 390), 1.0),
    (const Size(844, 390), 1.3),
  ]) {
    testWidgets(
      'on, landscape ${size.width.toInt()}x${size.height.toInt()}, text '
      "x$scale: the text is written and the code is as big as the neighbour's",
      (tester) async {
        await pumpCalendar(
          tester,
          size: size,
          textScale: scale,
          prepare: prepare,
          overrides: withNote(true),
        );
        await revealCell(tester, noted);

        expect(noteText(), findsOneWidget);
        expect(cellClip(), findsNothing);
        expectSameCode(tester, noted, neighbour, 'M');
        expectNoteLineClear(tester, noted, code: 'M', time: '06');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('on, phone: a day of two shifts with a note keeps its codes', (
    tester,
  ) async {
    await pumpCalendar(tester, prepare: prepare, overrides: withNote(true));
    await revealCell(tester, multi);

    expect(noteTextOf(multi), findsOneWidget);
    expect(clipOf(multi), findsNothing);
    expectSameCode(tester, multi, multiTwin, 'M');
    expectSameCode(tester, multi, multiTwin, 'N');
    expectNoteLineClear(tester, multi, code: 'N');
    expect(tester.takeException(), isNull);
  });

  testWidgets('on, phone: an empty day with a note writes it too', (
    tester,
  ) async {
    await pumpCalendar(tester, prepare: prepare, overrides: withNote(true));
    await revealCell(tester, empty);

    expect(noteTextOf(empty), findsOneWidget);
    expect(clipOf(empty), findsNothing);
    final box = tester.getRect(cell(empty));
    final line = tester.getRect(noteTextOf(empty));
    expect(line.bottom, lessThanOrEqualTo(box.bottom + 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'on, phone: the rows grow by one line, only where a note needs it',
    (tester) async {
      await pumpCalendar(tester, prepare: prepare, overrides: withNote(true));
      await revealCell(tester, noted);

      final gridContext = tester.element(find.byType(MonthGrid));
      final minCell = tester
          .widget<MonthGrid>(find.byType(MonthGrid))
          .minCellHeight;
      final days = tester
          .widgetList<DayCell>(find.byType(DayCell))
          .map((c) => c.day)
          .toList();
      expect(days, hasLength(42));
      final width = tester.getSize(cell(noted)).width;
      final plain = monthGridMinimumRowHeights(
        gridContext,
        days,
        minCellHeight: minCell,
      );
      final withNotes = monthGridMinimumRowHeights(
        gridContext,
        days,
        minCellHeight: minCell,
        showNoteInMonth: true,
        cellWidth: width,
      );
      final line = noteLineHeightOf(gridContext);
      final noteRows = {
        for (final date in [noted, multi])
          days.indexWhere((d) => d.date == date) ~/ 7,
      };
      expect(noteRows, hasLength(2));
      for (var r = 0; r < 6; r++) {
        if (noteRows.contains(r)) {
          // One single line of growth, even with several noted days in the
          // row, on top of the tallest day (the one of two shifts, in the
          // second week).
          expect(withNotes[r] - plain[r], closeTo(line, 0.01));
        } else {
          expect(withNotes[r], plain[r], reason: 'fila $r sin notas');
        }
      }
      // With the setting off the minima are the usual ones.
      expect(
        monthGridMinimumRowHeights(
          gridContext,
          days,
          minCellHeight: minCell,
          showNoteInMonth: false,
          cellWidth: width,
        ),
        plain,
      );
    },
  );

  testWidgets('on, phone: week numbers on, the text is still written', (
    tester,
  ) async {
    await pumpCalendar(
      tester,
      prepare: prepare,
      overrides: withNote(true, weekNumbers: true),
    );
    await revealCell(tester, noted);

    expect(noteText(), findsOneWidget);
    expect(cellClip(), findsNothing);
    expectSameCode(tester, noted, neighbour, 'M');
    expectNoteLineClear(tester, noted, code: 'M', time: '06');
    expect(tester.takeException(), isNull);
  });

  testWidgets('on, phone, text x3: the note line keeps to x1.3', (
    tester,
  ) async {
    await pumpCalendar(
      tester,
      textScale: 3.0,
      prepare: prepare,
      overrides: withNote(true),
    );
    await revealCell(tester, noted);

    final text = noteText();
    if (text.evaluate().isNotEmpty) {
      // A few letters show, not «Q…» (iPhone QA F9).
      final scaler = tester.widget<Text>(text).textScaler!;
      expect(scaler.scale(10), lessThanOrEqualTo(13.01));
    } else {
      expect(cellClip(), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('on, phone: shift size x1.4 never overflows', (tester) async {
    await pumpCalendar(
      tester,
      prepare: prepare,
      overrides: withNote(true, cellTextSize: CellTextSize.extraLarge),
    );
    await revealCell(tester, noted);

    final hasText = noteText().evaluate().isNotEmpty;
    final hasClip = cellClip().evaluate().isNotEmpty;
    expect(hasText != hasClip, isTrue, reason: 'texto o clip, no ambos');
    if (hasText) expectSameCode(tester, noted, neighbour, 'M');
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(390, 844), const Size(320, 568)]) {
    testWidgets(
      'on, ${size.width.toInt()}x${size.height.toInt()}, text x2.0, several '
      'noted days in a row: no overflow',
      (tester) async {
        await pumpCalendar(
          tester,
          size: size,
          textScale: 2.0,
          prepare: prepare,
          overrides: withNote(true),
        );
        for (final date in [noted, multi, empty, another]) {
          await revealCell(tester, date);
          final hasText = noteTextOf(date).evaluate().isNotEmpty;
          final hasClip = clipOf(date).evaluate().isNotEmpty;
          expect(hasText != hasClip, isTrue, reason: '$date: texto o clip');
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final brightness in Brightness.values) {
    for (final (size, scale) in [
      (const Size(390, 844), 1.0),
      (const Size(390, 844), 2.0),
      (const Size(320, 568), 1.0),
      (const Size(320, 568), 2.0),
      (const Size(768, 1000), 1.0),
    ]) {
      testWidgets(
        'on, ${size.width.toInt()}x${size.height.toInt()}, text x$scale, '
        '${brightness.name}: the note mark never overflows',
        (tester) async {
          await pumpCalendar(
            tester,
            size: size,
            textScale: scale,
            brightness: brightness,
            prepare: prepare,
            overrides: withNote(true),
          );
          await revealCell(tester, noted);

          // The cell always keeps a note mark: the text when it fits, the clip
          // otherwise; never both and never neither.
          final hasText = noteText().evaluate().isNotEmpty;
          final hasClip = cellClip().evaluate().isNotEmpty;
          expect(hasText || hasClip, isTrue, reason: 'sin marca de nota');
          expect(hasText && hasClip, isFalse, reason: 'texto y clip a la vez');
          // The text is written on the phones and on a wide surface at the
          // normal text size; large text may leave the clip instead.
          if (scale == 1.0) {
            expect(hasText, isTrue, reason: 'la nota se escribe');
          }
          // The code and the time are there either way.
          expect(codeOf(noted, 'M'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
