import 'package:cuadrante/core/router.dart';
import 'package:cuadrante/features/calendar/application/schedule_controller.dart';
import 'package:cuadrante/features/schedule/data/schedule_repository.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/features/summary/presentation/summary_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../calendar/harness.dart';

// B2: in «Desglose», «Turnos trabajados» counts only the shifts before today
// (the footnote: «Trabajadas: los días anteriores a hoy») and adds the planned
// ones, like the hours card. A 24 h guard every 4th day from 19 October 2026
// (G, S, L, L), nothing else; today comes from clockProvider.

Finder _key(String key) => find.byKey(ValueKey(key));

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(_key(key)).data!;

const _guard = ShiftType(
  id: 'guard',
  code: 'G',
  name: 'Guardia',
  colorValue: 0xFFF5A524,
  category: ShiftCategory.work,
  startMinute: 8 * 60,
  endMinute: 8 * 60,
);

Future<void> _saveGuard(ScheduleRepository repository) =>
    repository.saveShiftType(_guard);

/// Opens [month] ('2026-11') of the summary with [today] as the date.
Future<void> _open(
  WidgetTester tester,
  String month,
  DateTime today, {
  bool year = false,
  double textScale = 1,
}) async {
  await pumpCalendar(
    tester,
    size: const Size(390, 2600),
    textScale: textScale,
    clock: () => today,
    prepare: _saveGuard,
  );
  final schedule = containerOf(tester)
      .read(scheduleControllerProvider.notifier);
  var guard = const CivilDate(2026, 10, 19);
  for (
    var d = const CivilDate(2026, 1, 1);
    !d.isAfter(const CivilDate(2026, 12, 31));
    d = d.addDays(1)
  ) {
    final isGuard = d == guard;
    if (isGuard) guard = guard.addDays(4);
    schedule.setDayShifts(d, isGuard ? const ['guard'] : const []);
  }
  await tester.pumpAndSettle();
  containerOf(tester)
      .read(routerProvider)
      .go('/resumen?mes=$month${year ? '&vista=ano' : ''}');
  await tester.pumpAndSettle();
  expect(find.byType(SummaryScreen), findsOneWidget);
}

void main() {
  testWidgets('November on Monday 23: 5 worked and 2 planned, 120 h + 48 h', (
    tester,
  ) async {
    await _open(tester, '2026-11', DateTime(2026, 11, 23, 12));

    expect(_text(tester, 'summary-hours'), '120 h');
    expect(_text(tester, 'summary-hours-title'), 'trabajadas hasta ayer');
    expect(_text(tester, 'summary-legend-planned'), '48 h');
    expect(_text(tester, 'summary-shifts-value'), '5');
    expect(_text(tester, 'summary-shifts-detail'), 'y 2 previstos');
    // The shift types add up the whole period, and say so.
    expect(_key('summary-types-total-Turnos de trabajo'), findsOneWidget);
    expect(_text(tester, 'summary-type-hours-guard'), startsWith('168 h'));
  });

  testWidgets('a past month: everything worked, nothing planned', (
    tester,
  ) async {
    await _open(tester, '2026-10', DateTime(2026, 11, 23, 12));

    expect(_text(tester, 'summary-hours'), '96 h');
    expect(_text(tester, 'summary-hours-title'), 'trabajadas');
    expect(_text(tester, 'summary-shifts-value'), '4');
    expect(_key('summary-shifts-detail'), findsNothing);
    expect(_key('summary-types-total-Turnos de trabajo'), findsNothing);
    expect(find.textContaining('previstos'), findsNothing);
  });

  testWidgets('a future month: 0 worked and all planned', (tester) async {
    await _open(tester, '2026-12', DateTime(2026, 11, 23, 12));

    expect(_text(tester, 'summary-hours-title'), 'previstas');
    expect(_text(tester, 'summary-hours'), '192 h');
    expect(_text(tester, 'summary-shifts-value'), '0');
    expect(_text(tester, 'summary-shifts-detail'), 'y 8 previstos');
    expect(_key('summary-types-total-Turnos de trabajo'), findsOneWidget);
  });

  testWidgets('a period that includes today: its shift is planned', (
    tester,
  ) async {
    // Tuesday 24 November is a guard day.
    await _open(tester, '2026-11', DateTime(2026, 11, 24, 12));

    expect(_text(tester, 'summary-hours'), '120 h');
    expect(_text(tester, 'summary-legend-planned'), '48 h');
    expect(_text(tester, 'summary-shifts-value'), '5');
    expect(_text(tester, 'summary-shifts-detail'), 'y 2 previstos');
  });

  testWidgets('one planned shift reads in the singular', (tester) async {
    // On the 25th only the guard of the 28th is left.
    await _open(tester, '2026-11', DateTime(2026, 11, 25, 12));

    expect(_text(tester, 'summary-shifts-value'), '6');
    expect(_text(tester, 'summary-shifts-detail'), 'y 1 previsto');
  });

  List<String?> cellsOf(WidgetTester tester, String key) => tester
      .widgetList<Text>(
        find.descendant(of: _key(key), matching: find.byType(Text)),
      )
      .map((t) => t.data?.replaceAll(' ', ' '))
      .toList();

  testWidgets('the year table splits each month at today (23 November)', (
    tester,
  ) async {
    await _open(tester, '2026-11', DateTime(2026, 11, 23, 12), year: true);

    // A past month: all worked, no plus.
    expect(cellsOf(tester, 'summary-year-row-10').sublist(1, 3), ['4', '96 h']);
    // The current month: 5 worked before today and 2 planned from it.
    expect(cellsOf(tester, 'summary-year-row-11').sublist(1, 3), [
      '5 + 2',
      '120 h + 48 h',
    ]);
    // A future month: nothing worked yet.
    expect(cellsOf(tester, 'summary-year-row-12').sublist(1, 3), [
      '0 + 8',
      '0 h + 192 h',
    ]);
    // Total: the worked before today, then the planned.
    expect(cellsOf(tester, 'summary-year-total').sublist(1, 3), [
      '9 + 10',
      '216 h + 240 h',
    ]);
    expect(_key('summary-year-hint-planned'), findsOneWidget);
  });

  testWidgets('a year that is all past has no plus and no explanation', (
    tester,
  ) async {
    await _open(tester, '2026-11', DateTime(2027, 2, 1, 12), year: true);

    expect(cellsOf(tester, 'summary-year-row-12').sublist(1, 3), [
      '8',
      '192 h',
    ]);
    expect(cellsOf(tester, 'summary-year-total').sublist(1, 3), [
      '19',
      '456 h',
    ]);
    expect(_key('summary-year-hint-planned'), findsNothing);
  });

  testWidgets(
    'the year cards (large text) say the same: worked, then planned',
    (tester) async {
      await _open(
        tester,
        '2026-11',
        DateTime(2026, 11, 23, 12),
        year: true,
        textScale: 1.5,
      );

      final nov = cellsOf(tester, 'summary-year-card-11');
      expect(nov, contains('5 turnos · 120 h'));
      expect(nov.join('|'), contains('y 2 previstos · 48 h previstas'));
      final oct = cellsOf(tester, 'summary-year-card-10').join('|');
      expect(oct, contains('4 turnos · 96 h'));
      expect(oct, isNot(contains('previstos')));
      final dec = cellsOf(tester, 'summary-year-card-12').join('|');
      expect(dec, contains('0 turnos · 0 h'));
      expect(dec, contains('y 8 previstos · 192 h previstas'));
    },
  );
}
