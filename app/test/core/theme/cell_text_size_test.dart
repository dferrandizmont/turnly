import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/core/theme/theme_context.dart';
import 'package:cuadrante/features/schedule/data/schedule_repository.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/features/settings/application/preferences_controller.dart';
import 'package:cuadrante/features/settings/domain/preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/calendar/harness.dart';
import '../../features/calendar/rendered_cell_text.dart';
import '../../support/real_font.dart';

/// Ajustes › Apariencia › Tamaño del turno en el mes (P8, row 10 of
/// `docs/paridad-pago.md`): the theme scales the code and the time of the
/// cells; the cell still fits them (`cellCodeSize`, `cellTimeInCell`), so
/// nothing overflows on a 320 dp phone with the text at 160 %.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeLocale();
    expect(await loadRoboto(), isTrue, reason: 'Roboto from the Flutter SDK');
  });
  tearDownAll(() => AppTypography.debugFamily = null);

  // A morning (M, 06–14) and a night (N, 22–06).
  const morning = CivilDate(2026, 10, 21);
  const night = CivilDate(2026, 10, 23);

  Future<void> prepare(ScheduleRepository repository) => repository.apply(
    'main',
    ScheduleChange(
      patch: EntriesPatch({
        morning: EntryChange(
          null,
          const DayEntry(date: morning, shiftTypeIds: ['morning']),
        ),
        night: EntryChange(
          null,
          const DayEntry(date: night, shiftTypeIds: ['night']),
        ),
      }),
    ),
  );

  Finder codeOf(CivilDate day, String code) =>
      find.descendant(of: cell(day), matching: find.text(code));
  Finder timeOf(CivilDate day, String hour) =>
      find.descendant(of: cell(day), matching: find.textContaining(hour));

  Future<void> open(
    WidgetTester tester, {
    required Size size,
    required double scale,
    required CellTextSize cellSize,
    Brightness brightness = Brightness.light,
  }) async {
    await pumpCalendar(
      tester,
      size: size,
      textScale: scale,
      brightness: brightness,
      prepare: prepare,
      overrides: [
        initialPreferencesProvider.overrideWithValue(
          Preferences(cellTextSize: cellSize),
        ),
      ],
    );
    await revealCell(tester, night);
  }

  for (final (size, scale) in [
    (const Size(320, 640), 1.6),
    (const Size(320, 640), 1.0),
    (const Size(390, 844), 1.6),
  ]) {
    for (final cellSize in CellTextSize.values) {
      for (final brightness in Brightness.values) {
        testWidgets(
          '${size.width.toInt()} dp, text x$scale, ${cellSize.stored}, '
          '${brightness.name}: code and time fit, nothing overflows',
          (tester) async {
            await open(
              tester,
              size: size,
              scale: scale,
              cellSize: cellSize,
              brightness: brightness,
            );
            expect(tester.takeException(), isNull);
            expect(
              tester
                  .widget<MaterialApp>(find.byType(MaterialApp))
                  .theme!
                  .extension<AppTypography>()!
                  .cellCode
                  .fontSize,
              closeTo(20 * cellSize.factor, 1e-9),
            );
            for (final (day, code, hour) in [
              (morning, 'M', '06'),
              (night, 'N', '22'),
            ]) {
              // The code is there, drawn at its real size (no FittedBox
              // squeeze) and inside its cell.
              expectUnscaledCellText(tester, codeOf(day, code));
              // The time keeps its line: the cell is never only a code.
              expect(timeOf(day, hour), findsOneWidget);
              final box = tester.getRect(cell(day));
              final codeRect = renderedTextRect(tester, codeOf(day, code));
              final timeRect = renderedTextRect(tester, timeOf(day, hour));
              expect(box.contains(codeRect.center), isTrue);
              expect(codeRect.left, greaterThanOrEqualTo(box.left - 0.5));
              expect(codeRect.right, lessThanOrEqualTo(box.right + 0.5));
              expect(timeRect.bottom, lessThanOrEqualTo(box.bottom + 0.5));
            }
          },
        );
      }
    }
  }

  testWidgets('390 dp, normal text: the size changes live and a bigger '
      'size draws a bigger code', (tester) async {
    await open(
      tester,
      size: const Size(390, 844),
      scale: 1,
      cellSize: CellTextSize.normal,
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    final heights = [renderedTextRect(tester, codeOf(night, 'N')).height];
    for (final cellSize in [CellTextSize.large, CellTextSize.extraLarge]) {
      await tester.runAsync(
        () => container
            .read(preferencesProvider.notifier)
            .setCellTextSize(cellSize),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      heights.add(renderedTextRect(tester, codeOf(night, 'N')).height);
    }
    expect(heights[1], greaterThan(heights[0]), reason: '$heights');
    expect(heights[2], greaterThan(heights[1]), reason: '$heights');
  });
}
