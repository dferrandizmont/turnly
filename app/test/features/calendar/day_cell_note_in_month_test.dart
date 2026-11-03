import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/core/icons/app_icons.dart';
import 'package:cuadrante/features/schedule/data/schedule_repository.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/features/settings/application/preferences_controller.dart';
import 'package:cuadrante/features/settings/domain/preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

/// «Ver la nota en el mes» (UX · Extras visuales): with the preference on the
/// first line of the note is written in the cell (in place of its clip); with
/// it off the cell keeps the clip of always. It never overflows, at the
/// campaign sizes, with large text and in both themes.
void main() {
  setUpAll(initializeLocale);

  const noted = CivilDate(2026, 10, 20);
  const note = 'Compra y farmacia\nsegunda línea que no cabe';

  Future<void> prepare(ScheduleRepository repository) => repository.apply(
    'main',
    ScheduleChange(
      patch: EntriesPatch({
        noted: EntryChange(
          null,
          const DayEntry(date: noted, shiftTypeIds: ['morning'], note: note),
        ),
      }),
    ),
  );

  List<Override> withNote(bool on) => [
    initialPreferencesProvider.overrideWithValue(
      Preferences(showNoteInMonth: on),
    ),
  ];

  Finder noteText() => find.byKey(ValueKey('note-text-${noted.toIso()}'));

  Finder cellClip() =>
      find.descendant(of: cell(noted), matching: find.byIcon(AppIcons.note));

  testWidgets('on: the first line of the note is written in the cell', (
    tester,
  ) async {
    // A surface wide enough for the note text; on a narrow phone the cell
    // keeps its clip instead (see the matrix below).
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
    expect(tester.takeException(), isNull);
  });

  testWidgets('off: the cell keeps the clip and writes no text', (
    tester,
  ) async {
    await pumpCalendar(tester, prepare: prepare, overrides: withNote(false));
    await revealCell(tester, noted);

    expect(noteText(), findsNothing);
    expect(cellClip(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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
          if (size.width >= 700) {
            expect(
              hasText,
              isTrue,
              reason: 'en una superficie ancha la nota se escribe',
            );
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
