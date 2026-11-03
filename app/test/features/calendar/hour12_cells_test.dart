import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/core/theme/theme_context.dart';
import 'package:cuadrante/features/calendar/presentation/day_cell.dart'
    show cellContentInset, cellTimeInCell, textWidth;
import 'package:cuadrante/features/calendar/presentation/shift_format.dart';
import 'package:cuadrante/features/schedule/data/schedule_repository.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/features/settings/application/preferences_controller.dart';
import 'package:cuadrante/features/settings/domain/preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/real_font.dart';
import 'harness.dart';

// The 12 h clock in the month (docs/formatos.md): the cell has the same room
// as with 24 h, so the time is the compact form with a letter ("10p–6a").
// Demo data around Monday 19 October 2026 (Noche 19-23, Libre 24-25,
// Mañana 26-30).
const _night = CivilDate(2026, 10, 20);
const _morning = CivilDate(2026, 10, 26);
const _split = CivilDate(2026, 10, 24);

const _partido = ShiftType(
  id: 'partido',
  code: 'P',
  name: 'Partido',
  colorValue: 0xFF15AABF,
  category: ShiftCategory.work,
  startMinute: 9 * 60,
  endMinute: 13 * 60,
  segment2StartMinute: 17 * 60,
  segment2DurationMinutes: 4 * 60,
);

ShiftType _shift(int start, int end) => ShiftType(
  id: 's$start-$end',
  code: 'X',
  name: 'X',
  colorValue: 0xFF336699,
  category: ShiftCategory.work,
  startMinute: start,
  endMinute: end,
);

final _twelve = initialPreferencesProvider.overrideWithValue(
  const Preferences(timeFormat: TimeFormatPreference.h12),
);

Future<void> _prepare(ScheduleRepository repository) async {
  await repository.saveShiftType(_partido);
  await repository.apply(
    'main',
    ScheduleChange(
      patch: EntriesPatch({
        _split: EntryChange(
          null,
          DayEntry(date: _split, shiftTypeIds: const ['partido']),
        ),
      }),
    ),
  );
}

Finder _inCell(CivilDate date, Finder what) =>
    find.descendant(of: cell(date), matching: what);

void main() {
  // The test font (Ahem) is twice as wide as a real one: the cell tests need
  // the font of a phone to say anything about its room.
  setUpAll(() async {
    await initializeLocale();
    expect(await loadRoboto(), isTrue, reason: 'Roboto from the Flutter SDK');
  });
  tearDownAll(() => AppTypography.debugFamily = null);

  group('ShiftType compact forms', () {
    final night = _shift(22 * 60, 6 * 60);
    final minutes = _shift(7 * 60 + 30, 15 * 60 + 30);

    test('24 h is the default and does not change', () {
      expect(night.compactTimeRange(), '22–06');
      expect(minutes.compactTimeRange(), '07:30–15:30');
      expect(minutes.compactStart(), '07:30');
      expect(minutes.compactStartHour(), '07');
      expect(_partido.compactSplitStarts(), '09/17');
    });

    test('12 h: a letter after the hour', () {
      expect(night.compactTimeRange(hour12: true), '10p–6a');
      expect(night.compactTimeLabel(hour12: true), '10p–6a');
      expect(minutes.compactTimeRange(hour12: true), '7:30a–3:30p');
      expect(minutes.compactStart(hour12: true), '7:30a');
      expect(minutes.compactStartHour(hour12: true), '7a');
      expect(_partido.compactTimeRange(hour12: true), '9a–1p/5p–9p');
      expect(_partido.compactTimeLabel(hour12: true), '9a–1p · 5p–9p');
      expect(_partido.compactSplitStarts(hour12: true), '9a/5p');
    });

    test('a shift without schedule has none', () {
      const rest = ShiftType(
        id: 'l',
        code: 'L',
        name: 'Libre',
        colorValue: 0,
        category: ShiftCategory.rest,
      );
      expect(rest.compactTimeRange(hour12: true), isNull);
      expect(rest.compactStart(hour12: true), isNull);
      expect(rest.compactStartHour(hour12: true), isNull);
      expect(rest.compactSplitStarts(hour12: true), isNull);
    });
  });

  group('cellTimeInCell on the 12 h clock', () {
    testWidgets('the whole range fits where the 24 h one does', (tester) async {
      await pumpCalendar(tester, prepare: _prepare);
      final context = tester.element(cell(_night));
      final style = context.type.cellTime;
      const width = 53.0;
      for (final (start, end) in [
        (22 * 60, 6 * 60),
        (6 * 60, 14 * 60),
        (14 * 60, 22 * 60),
        (8 * 60, 20 * 60),
      ]) {
        final h24 = cellTimeInCell(
          shift: _shift(start, end),
          style: style,
          scaler: TextScaler.noScaling,
          width: width,
        )!;
        final h12 = cellTimeInCell(
          shift: _shift(start, end),
          style: style,
          scaler: TextScaler.noScaling,
          width: width,
          hour12: true,
        )!;
        expect(h12.text, contains('–'), reason: '$start-$end');
        expect(h12.text, matches(RegExp(r'^\d+[ap]–\d+[ap]$')));
        // As much room as the 24 h text: it does not need to shrink more.
        expect(h12.size, closeTo(h24.size, 1.5), reason: '$start-$end');
      }
    });

    testWidgets('whatever the width or the text size, the cell keeps the '
        'start of the shift', (tester) async {
      await pumpCalendar(tester, prepare: _prepare);
      final context = tester.element(cell(_night));
      final style = context.type.cellTime;
      for (final width in [40.0, 47.0, 53.0, 62.0, 100.0]) {
        for (final scale in [1.0, 1.3, 2.0]) {
          final scaler = TextScaler.linear(scale);
          for (final hour12 in [false, true]) {
            for (final shift in [
              _shift(10 * 60 + 30, 18 * 60 + 30),
              _shift(22 * 60 + 15, 6 * 60 + 45),
              _shift(0, 12 * 60),
              _partido,
            ]) {
              final time = cellTimeInCell(
                shift: shift,
                style: style,
                scaler: scaler,
                width: width,
                hour12: hour12,
              );
              final reason =
                  '$width x$scale 12h=$hour12 '
                  '${shift.compactTimeRange(hour12: hour12)}';
              expect(time, isNotNull, reason: reason);
              // Something that starts with the hour the shift starts at.
              final hour = RegExp(r'^\d+')
                  .stringMatch(shift.compactStartHour(hour12: hour12)!)!;
              expect(time!.text, startsWith(hour), reason: reason);
            }
          }
        }
      }
    });

    testWidgets('on the hour, "10:30 PM" shaped times fit a 53 dp cell', (
      tester,
    ) async {
      await pumpCalendar(tester, prepare: _prepare);
      final context = tester.element(cell(_night));
      final style = context.type.cellTime;
      const width = 53.0;
      final room = width - 2 * cellContentInset;
      for (final hour12 in [false, true]) {
        final time = cellTimeInCell(
          shift: _shift(7 * 60 + 30, 15 * 60 + 30),
          style: style,
          scaler: TextScaler.noScaling,
          width: width,
          hour12: hour12,
        )!;
        final measured = textWidth(
          time.text,
          style.copyWith(fontSize: time.size),
          TextScaler.noScaling,
        );
        expect(measured, lessThanOrEqualTo(room + 0.5), reason: '12h=$hour12');
      }
    });
  });

  group('the month on the 12 h clock', () {
    testWidgets('cells show "10p–6a" and nothing overflows', (tester) async {
      await pumpCalendar(tester, overrides: [_twelve], prepare: _prepare);
      expect(_inCell(_night, find.text('10p–6a')), findsOneWidget);
      expect(_inCell(_night, find.text('22–06')), findsNothing);
      expect(_inCell(_morning, find.text('6a–2p')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a narrow phone and big text: still a code and a time', (
      tester,
    ) async {
      await pumpCalendar(
        tester,
        overrides: [_twelve],
        size: const Size(320, 640),
        textScale: 1.3,
        prepare: _prepare,
      );
      // The «Hoy» card and the bar of destinations (B1) leave the row below
      // the fold: scroll to it.
      await revealCell(tester, _night);
      expect(_inCell(_night, find.text('N')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the split shift says when each range starts', (tester) async {
      await pumpCalendar(tester, overrides: [_twelve], prepare: _prepare);
      expect(_inCell(_split, find.text('P')), findsOneWidget);
      expect(_inCell(_split, find.text('9a/5p')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the spoken label of the cell reads the 12 h times', (
      tester,
    ) async {
      await pumpCalendar(tester, overrides: [_twelve], prepare: _prepare);
      final label = tester.getSemantics(cell(_night)).label;
      expect(label, contains('10:00'));
      expect(label, contains('6:00'));
      expect(label, isNot(contains('22:00')));
    });

    testWidgets('24 h cells are unchanged', (tester) async {
      await pumpCalendar(tester, prepare: _prepare);
      expect(_inCell(_night, find.text('22–06')), findsOneWidget);
    });
  });
}
