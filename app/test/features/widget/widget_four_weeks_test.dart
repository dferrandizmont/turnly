import 'dart:convert';

import 'package:cuadrante/core/bootstrap/bootstrap.dart' show initializeLocale;
import 'package:cuadrante/features/holidays/domain/holiday.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/features/widget/domain/widget_snapshot.dart';
import 'package:cuadrante/features/widget/domain/widget_snapshot_builder.dart';
import 'package:cuadrante/features/widget/domain/widget_strings.dart';
import 'package:flutter_test/flutter_test.dart';

import '../schedule/domain/fixtures.dart';

/// The optional `notes` extension of the snapshot (UW,
/// `docs/widget-contrato.md`): the first line of the note of each displayed
/// day that has one and is not an absence, so the four-week widget can show
/// it under the day number. The text never travels from a health day.
void main() {
  setUpAll(initializeLocale);

  const monday = CivilDate(2026, 10, 19); // a Monday

  Schedule rotation({Map<CivilDate, DayEntry> entries = const {}}) => Schedule(
    shiftTypes: allTypes,
    patterns: const [
      Pattern(
        id: 'rot',
        name: 'rot',
        steps: [
          ['night'],
          ['afternoon'],
          ['morning'],
          ['rest'],
        ],
      ),
    ],
    runs: [PatternRun(id: 'r', patternId: 'rot', startDate: monday, seq: 1)],
    entries: entries,
  );

  WidgetSnapshot build({
    Schedule? from,
    CivilDate today = monday,
    int days = 35,
    WidgetStrings strings = WidgetStrings.es,
  }) => buildWidgetSnapshot(
    schedule: from ?? rotation(),
    holidays: const <CivilDate, Holiday>{},
    today: today,
    timeZone: 'Europe/Madrid',
    strings: strings,
    days: days,
    generatedAt: DateTime.utc(2026, 10, 19, 8),
  );

  test('only the first line of the note travels, trimmed', () {
    final snapshot = build(
      from: rotation(
        entries: {
          monday.addDays(2): DayEntry(
            date: monday.addDays(2),
            shiftTypeIds: const ['morning'],
            note: 'Cambio de turno\nhablado con Ana',
          ),
        },
      ),
    );
    expect(snapshot.notes!['2026-10-21'], 'Cambio de turno');
  });

  test('a long note is cut at 120 characters, never inside an emoji', () {
    Schedule withNote(String note) => rotation(
      entries: {
        monday.addDays(2): DayEntry(
          date: monday.addDays(2),
          shiftTypeIds: const ['morning'],
          note: note,
        ),
      },
    );

    final plain = build(from: withNote('a' * 5000));
    final line = plain.notes!['2026-10-21']!;
    expect(line, hasLength(widgetNoteMaxChars));
    expect(widgetNoteMaxChars, 120);
    // The payload does not grow with the note: 5000 characters add 119.
    final tiny = build(from: withNote('a'));
    expect(
      jsonEncode(plain.toJson()).length - jsonEncode(tiny.toJson()).length,
      lessThan(200),
    );

    // 119 letters and then two emoji (two UTF-16 units each): the cut falls
    // between them, never inside one.
    final emoji = build(from: withNote('${'a' * 119}\u{1F600}\u{1F600}'));
    final cut = emoji.notes!['2026-10-21']!;
    expect(cut.runes.length, 120);
    expect(cut.endsWith('\u{1F600}'), isTrue);

    // A short note is untouched.
    expect(
      build(from: withNote('Cambio de turno')).notes!['2026-10-21'],
      'Cambio de turno',
    );
    expect(truncateWidgetNote('x' * 120), 'x' * 120);
  });

  test('a first line that is only blanks falls back to the whole note', () {
    final snapshot = build(
      from: rotation(
        entries: {
          monday.addDays(2): DayEntry(
            date: monday.addDays(2),
            shiftTypeIds: const ['morning'],
            note: '\n   Entregar informe   ',
          ),
        },
      ),
    );
    expect(snapshot.notes!['2026-10-21'], 'Entregar informe');
  });

  test('a note never travels from an absence day', () {
    final snapshot = build(
      from: rotation(
        entries: {
          monday.addDays(4): DayEntry(
            date: monday.addDays(4),
            shiftTypeIds: const ['vacation'],
            note: 'Cita médica',
          ),
        },
      ),
    );
    expect(snapshot.notes, isNull);
    expect(snapshot.toJson().containsKey('notes'), isFalse);
    final day = snapshot.displayDays.singleWhere((d) => d.date == '2026-10-23');
    expect(day.hasNote, isFalse);
    expect(day.shifts.single.category, 'absence');
    final text = jsonEncode(snapshot.toJson());
    expect(text, isNot(contains('Cita médica')));
  });

  test('without any note the extension is absent', () {
    final snapshot = build();
    expect(snapshot.notes, isNull);
    expect(snapshot.toJson().containsKey('notes'), isFalse);
  });

  test('it survives encode and decode, and is part of the hash', () {
    final snapshot = build(
      from: rotation(
        entries: {
          monday.addDays(5): DayEntry(
            date: monday.addDays(5),
            shiftTypeIds: const ['morning'],
            note: 'Formación',
          ),
        },
      ),
    );
    final decoded = WidgetSnapshot.decode(snapshot.encode());
    expect(decoded.notes!['2026-10-24'], 'Formación');
    expect(decoded.contentHash, snapshot.contentHash);
    expect(decoded.computeContentHash(), snapshot.contentHash);
    final without = WidgetSnapshot.decode(
      jsonEncode(
        (jsonDecode(snapshot.encode()) as Map<String, Object?>)
          ..remove('notes'),
      ),
    );
    expect(without.notes, isNull, reason: 'older snapshots still decode');
    expect(without.computeContentHash(), isNot(snapshot.contentHash));
  });

  test('the note of a day before today still travels: the grid starts Monday',
      () {
    // Today is Thursday; the four-week grid starts on the Monday of this week,
    // three days before today, and both days keep their note.
    final thursday = monday.addDays(3);
    final snapshot = build(
      today: thursday,
      from: rotation(
        entries: {
          monday: DayEntry(
            date: monday,
            shiftTypeIds: const ['morning'],
            note: 'Dentista a las cinco',
          ),
          thursday: DayEntry(
            date: thursday,
            shiftTypeIds: const ['morning'],
            note: 'Cena con Marta',
          ),
        },
      ),
    );
    expect(snapshot.notes!['2026-10-19'], 'Dentista a las cinco');
    expect(snapshot.notes!['2026-10-22'], 'Cena con Marta');
    expect(snapshot.displayDays.first.date, '2026-10-19');
    expect(snapshot.displayDays.first.weekdayShort, 'lun');
  });

  test('four weeks need 28 Monday-first days', () {
    expect(kWidgetFourWeeksDays, 28);
    final snapshot = build(today: monday);
    expect(snapshot.displayDays, hasLength(greaterThanOrEqualTo(28)));
    // The first 28 display days are exactly four weeks, Monday first.
    final four = snapshot.displayDays.take(kWidgetFourWeeksDays).toList();
    for (var i = 0; i < four.length; i++) {
      final date = monday.addDays(i);
      expect(four[i].date, date.toIso());
      expect(date.weekday, (i % 7) + 1);
    }
    expect(four.last.date, '2026-11-15');
  });

  test('the same schedule always gives the same notes', () {
    final schedule = rotation(
      entries: {
        monday.addDays(2): DayEntry(
          date: monday.addDays(2),
          shiftTypeIds: const ['morning'],
          note: 'Cambio',
        ),
      },
    );
    expect(
      jsonEncode(build(from: schedule).toJson()['notes']),
      jsonEncode(build(from: schedule).toJson()['notes']),
    );
  });

  test('the full 60-day timeline stays under the snapshot limit', () {
    final snapshot = build(
      days: kWidgetDays,
      from: rotation(
        entries: {
          for (var i = 0; i < 10; i++)
            monday.addDays(i): DayEntry(
              date: monday.addDays(i),
              shiftTypeIds: const ['morning'],
              note: 'Nota del día $i con algo de texto',
            ),
        },
      ),
    );
    expect(snapshot.notes, isNotNull);
    expect(
      utf8.encode(snapshot.encode()).length,
      lessThan(kWidgetSnapshotMaxBytes),
    );
  });

  test('it does not grow the timeline or the spoken descriptions', () {
    final snapshot = build(
      from: rotation(
        entries: {
          monday.addDays(2): DayEntry(
            date: monday.addDays(2),
            shiftTypeIds: const ['morning'],
            note: 'Cambio',
          ),
        },
      ),
    );
    expect(snapshot.days, hasLength(35));
    // The description only announces presence, never the text.
    expect(
      snapshot.descriptions!.days['2026-10-21'],
      isNot(contains('Cambio')),
    );
  });
}
