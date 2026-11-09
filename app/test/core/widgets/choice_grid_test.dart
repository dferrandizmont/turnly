import 'package:cuadrante/core/theme/app_theme.dart';
import 'package:cuadrante/core/widgets/choice_grid.dart';
import 'package:cuadrante/core/widgets/choice_pill.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/text_lines.dart';

/// The jobs of «¿A qué te dedicas?», the longest labels a grid of pills has.
const _jobs = [
  'Enfermería, TCAE y celadores',
  'Medicina (guardias)',
  'Policía y Guardia Civil',
  'Bomberos',
  'Industria',
  'Seguridad privada',
  'Hostelería y comercio',
  'Otro',
];

const _periods = ['Mes', 'Trimestre', 'Año', 'Fechas…'];

Future<void> _pump(
  WidgetTester tester,
  Widget Function(BuildContext context) grid, {
  double width = 360,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = Size(width, 2000) * 2;
  tester.view.devicePixelRatio = 2;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearAllTestValues();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(child: Builder(builder: grid)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

ChoicePill _pill(String label) => ChoicePill(
  label: label,
  selected: false,
  onTap: () {},
  expand: true,
  reserveIcon: true,
);

List<ChoicePill> _pills(List<String> labels) => [
  for (final label in labels) _pill(label),
];

Finder _pillOf(String label) => find.widgetWithText(ChoicePill, label);

/// The pills as laid out, row by row (same top), each row left to right.
List<List<Rect>> _rowsOf(WidgetTester tester, List<String> labels) {
  final rects = [for (final label in labels) tester.getRect(_pillOf(label))];
  final tops = {for (final r in rects) r.top.roundToDouble()}.toList()..sort();
  return [
    for (final top in tops)
      [
        for (final r in rects)
          if (r.top.roundToDouble() == top) r,
      ]..sort((a, b) => a.left.compareTo(b.left)),
  ];
}

/// Every cell the same width, every row level (same top and height) and the
/// columns lined up from one row to the next.
void _expectAligned(List<List<Rect>> rows) {
  final first = rows.first.first;
  for (final row in rows) {
    for (final cell in row) {
      expect(cell.width, closeTo(first.width, 0.5), reason: 'equal widths');
      expect(cell.height, closeTo(row.first.height, 0.5), reason: 'level row');
      expect(cell.top, closeTo(row.first.top, 0.5));
    }
  }
  for (var c = 0; c < rows.first.length; c++) {
    for (final row in rows) {
      if (c < row.length) {
        expect(
          row[c].left,
          closeTo(rows.first[c].left, 0.5),
          reason: 'column $c lined up',
        );
      }
    }
  }
}

int _widestRow(List<List<Rect>> rows) =>
    rows.map((row) => row.length).reduce((a, b) => a > b ? a : b);

void main() {
  test('columnsFor fits one to maxColumns cells', () {
    expect(ChoiceGrid.columnsFor(320, 150), 2);
    expect(ChoiceGrid.columnsFor(320, 200), 1);
    expect(ChoiceGrid.columnsFor(2000, 150), 3);
    expect(ChoiceGrid.columnsFor(2000, 150, maxColumns: 5), 5);
    expect(ChoiceGrid.columnsFor(2000, 150, maxColumns: 2), 2);
    expect(ChoiceGrid.columnsFor(10, 150, maxColumns: 4), 1);
  });

  group('minCellWidthFor', () {
    Future<double> measure(
      WidgetTester tester, {
      required ChoiceGridSizing sizing,
      double scale = 1.0,
      List<String> labels = _jobs,
      List<String> details = const [],
    }) async {
      late double width;
      await _pump(tester, (context) {
        width = ChoiceGrid.minCellWidthFor(
          context,
          labels: labels,
          details: details,
          sizing: sizing,
        );
        return const SizedBox.shrink();
      }, textScale: scale);
      return width;
    }

    // A cell without a leading is centred with 12 dp sides, like compact.
    final chrome = ChoicePill.chromeWidth(compact: true, hasLeading: false);

    testWidgets('whole-label needs more than longest-word, both more than '
        'the chrome', (tester) async {
      final whole = await measure(tester, sizing: ChoiceGridSizing.wholeLabel);
      final word = await measure(tester, sizing: ChoiceGridSizing.longestWord);
      expect(word, greaterThan(chrome));
      expect(whole, greaterThan(word));
    });

    testWidgets("it follows the reader's text size", (tester) async {
      final word = await measure(tester, sizing: ChoiceGridSizing.longestWord);
      final scaled = await measure(
        tester,
        sizing: ChoiceGridSizing.longestWord,
        scale: 2.0,
      );
      expect(scaled - chrome, closeTo(2 * (word - chrome), 2));
    });

    testWidgets('longest-word measures a single word, whole-label the '
        'sentence', (tester) async {
      final sentence = await measure(
        tester,
        sizing: ChoiceGridSizing.wholeLabel,
        labels: const ['Policía y Guardia Civil'],
      );
      final longestWord = await measure(
        tester,
        sizing: ChoiceGridSizing.longestWord,
        labels: const ['Policía y Guardia Civil'],
      );
      final firstWord = await measure(
        tester,
        sizing: ChoiceGridSizing.longestWord,
        labels: const ['Guardia'],
      );
      // «Guardia» is the longest word of the label.
      expect(longestWord, closeTo(firstWord, 0.5));
      expect(sentence, greaterThan(longestWord + 40));
    });

    testWidgets('the details count too', (tester) async {
      final plain = await measure(
        tester,
        sizing: ChoiceGridSizing.wholeLabel,
        labels: const ['Mañana'],
      );
      final withHours = await measure(
        tester,
        sizing: ChoiceGridSizing.wholeLabel,
        labels: const ['Mañana'],
        details: const ['07:00–15:00 y bastante más'],
      );
      expect(withHours, greaterThan(plain));
    });
  });

  group('whole-label', () {
    testWidgets('a short group stays in one row of equal cells', (
      tester,
    ) async {
      await _pump(
        tester,
        (_) => ChoiceGrid.pills(
          sizing: ChoiceGridSizing.wholeLabel,
          maxColumns: _periods.length,
          pills: _pills(_periods),
        ),
        width: 1400,
      );
      final rows = _rowsOf(tester, _periods);
      expect(rows, hasLength(1));
      expect(rows.first, hasLength(4));
      _expectAligned(rows);
      expect(brokenParagraphs(tester), isEmpty);
    });

    testWidgets('it falls back to fewer columns when they do not fit, 2 and '
        '2', (tester) async {
      await _pump(
        tester,
        (_) => ChoiceGrid.pills(
          sizing: ChoiceGridSizing.wholeLabel,
          maxColumns: _periods.length,
          pills: _pills(_periods),
        ),
        width: 560, // the test font is twice as wide: room for two cells
      );
      final rows = _rowsOf(tester, _periods);
      expect([for (final row in rows) row.length], [2, 2]);
      _expectAligned(rows);
    });

    testWidgets('four choices that fit three columns go two and two', (
      tester,
    ) async {
      await _pump(
        tester,
        (_) => ChoiceGrid.pills(
          sizing: ChoiceGridSizing.wholeLabel,
          pills: _pills(_periods),
        ),
        width: 1400,
      );
      final rows = _rowsOf(tester, _periods);
      expect([for (final row in rows) row.length], [2, 2]);
    });

    testWidgets('two choices share the row in equal halves', (tester) async {
      const labels = ['Notas', 'Turnos'];
      await _pump(
        tester,
        (_) => ChoiceGrid.pills(
          sizing: ChoiceGridSizing.wholeLabel,
          maxColumns: 2,
          pills: _pills(labels),
        ),
      );
      final rows = _rowsOf(tester, labels);
      expect(rows, hasLength(1));
      _expectAligned(rows);
    });

    testWidgets('a grid with nothing in it draws nothing', (tester) async {
      await _pump(tester, (_) => ChoiceGrid.pills(pills: const []));
      expect(find.byType(ChoicePill), findsNothing);
    });
  });

  group('longest-word', () {
    testWidgets('the jobs go in aligned columns and wrap between words', (
      tester,
    ) async {
      await _pump(
        tester,
        (_) => ChoiceGrid.pills(pills: _pills(_jobs)),
        width: 700,
      );
      final rows = _rowsOf(tester, _jobs);
      expect(rows.length, greaterThan(1));
      expect(_widestRow(rows), greaterThan(1));
      _expectAligned(rows);
      expect(brokenParagraphs(tester), isEmpty);
    });

    testWidgets('a narrow cell wraps the label onto more lines, not inside a '
        'word', (tester) async {
      // Wide enough for the longest word, not for the whole label.
      await _pump(
        tester,
        (_) => ChoiceGrid.pills(pills: _pills(_jobs), maxColumns: 1),
        width: 400,
      );
      final label = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: _pillOf(_jobs.first),
          matching: find.text(_jobs.first),
        ),
      );
      expect(paragraphLines(label).length, greaterThan(1));
      expect(brokenParagraphs(tester), isEmpty);
    });

    for (final width in [360.0, 412.0]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        testWidgets('no word breaks at $width dp, text $scale', (tester) async {
          // The test font is about twice as wide as the app's: at text 2.0
          // the viewport is widened to hold the longest word.
          await _pump(
            tester,
            (_) => ChoiceGrid.pills(pills: _pills(_jobs)),
            width: scale == 2.0 ? 700 : width,
            textScale: scale,
          );
          final rows = _rowsOf(tester, _jobs);
          _expectAligned(rows);
          expect(_widestRow(rows), lessThanOrEqualTo(3));
          expect(brokenParagraphs(tester), isEmpty);
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('a pill with a leading and a detail is sized for both', (
      tester,
    ) async {
      final pills = [
        for (final name in ['Mañana', 'Tarde', 'Noche', 'Libre'])
          ChoicePill(
            label: name,
            detail: '07:00–15:00',
            leading: const SizedBox.square(dimension: 24),
            expand: true,
            compact: true,
            selected: false,
            onTap: () {},
          ),
      ];
      await _pump(
        tester,
        (_) => ChoiceGrid.pills(
          pills: pills,
          sizing: ChoiceGridSizing.wholeLabel,
          leadingSize: 24,
        ),
        width: 600,
      );
      expect(brokenParagraphs(tester), isEmpty);
      expect(tester.takeException(), isNull);
    });
  });
}
