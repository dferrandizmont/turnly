import 'package:cuadrante/app.dart';
import 'package:cuadrante/core/router.dart';
import 'package:cuadrante/core/widgets/empty_illustration.dart';
import 'package:cuadrante/features/summary/application/summary_providers.dart';
import 'package:cuadrante/features/summary/data/hours_goal_store.dart';
import 'package:cuadrante/features/summary/domain/hours_goal.dart';
import 'package:cuadrante/features/schedule/domain/civil_date.dart';
import 'package:cuadrante/features/summary/presentation/how_am_i_doing_card.dart';
import 'package:cuadrante/features/summary/presentation/summary_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../calendar/harness.dart';

// Design 5A (B5): «¿Cómo voy?» on top, the breakdown under it, what has no
// data folded. Demo data around Monday 19 October 2026: October has 96 h
// worked before the 19th and 64 h planned from it; no shift has a price and
// there are two days of Vacaciones.

Finder _key(String key) => find.byKey(ValueKey(key));

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(_key(key)).data!;

class _Goal implements HoursGoalStore {
  _Goal(this.goal);

  HoursGoal? goal;
  CivilDate? since;

  @override
  Future<HoursGoal?> load() async => goal;

  @override
  Future<CivilDate?> loadSince() async => since;

  @override
  Future<void> save(HoursGoal value) async => goal = value;

  @override
  Future<void> saveSince(CivilDate date) async => since = date;

  @override
  Future<void> clear() async {
    goal = null;
    since = null;
  }
}

Future<void> _open(
  WidgetTester tester,
  String query, {
  HoursGoal? goal,
  Size size = const Size(390, 844),
  double textScale = 1,
  Brightness brightness = Brightness.light,
}) async {
  await pumpCalendar(
    tester,
    size: size,
    textScale: textScale,
    brightness: brightness,
    overrides: [hoursGoalStoreProvider.overrideWithValue(_Goal(goal))],
  );
  ProviderScope.containerOf(tester.element(find.byType(CuadranteApp)))
      .read(routerProvider)
      .go('/resumen?$query');
  await tester.pumpAndSettle();
  expect(find.byType(SummaryScreen), findsOneWidget);
}

void main() {
  testWidgets('the card comes first, then the breakdown, then the folds', (
    tester,
  ) async {
    await _open(tester, 'mes=2026-10', size: const Size(390, 2600));
    expect(_text(tester, 'summary-how-title'), '¿CÓMO VOY?');
    final how = tester.getTopLeft(_key('summary-how')).dy;
    final breakdown = tester.getTopLeft(_key('summary-breakdown')).dy;
    final folds = tester.getTopLeft(_key('summary-estimate-fold')).dy;
    expect(how, lessThan(breakdown));
    expect(breakdown, lessThan(folds));
    // The comparison with September lives in the breakdown now.
    expect(
      find.descendant(
        of: _key('summary-breakdown'),
        matching: _key('summary-delta'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('worked in big, planned striped in the same bar, and the goal '
      'chip says the difference', (tester) async {
    await _open(
      tester,
      'mes=2026-10',
      goal: const HoursGoal(HoursGoalPeriod.month, 200),
    );
    expect(_text(tester, 'summary-hours'), '96 h');
    expect(_key('summary-how-bar'), findsOneWidget);
    expect(_text(tester, 'summary-legend-done'), '96 h');
    expect(_text(tester, 'summary-legend-planned'), '64 h');
    expect(_text(tester, 'summary-goal-target-value'), '200 h');
    // 96 + 64 = 160 h against 200 h.
    expect(
      _text(tester, 'summary-goal-verdict'),
      'Con lo previsto, te faltan 40 h',
    );
    final bar = tester.widget<HoursBar>(find.byType(HoursBar));
    expect(bar.doneMinutes, 96 * 60);
    expect(bar.plannedMinutes, 64 * 60);
    expect(bar.goalMinutes, 200 * 60);
  });

  testWidgets('a past month has no planned part and the bar is all worked', (
    tester,
  ) async {
    await _open(tester, 'mes=2026-09');
    final bar = tester.widget<HoursBar>(find.byType(HoursBar));
    expect(bar.plannedMinutes, 0);
    expect(bar.goalMinutes, isNull);
    expect(_key('summary-goal-add'), findsOneWidget);
  });

  testWidgets('the year view opens with the card above the table', (
    tester,
  ) async {
    await _open(tester, 'mes=2026-10&vista=ano');
    expect(_key('summary-how'), findsOneWidget);
    expect(_text(tester, 'summary-hours-title'), 'trabajadas hasta ayer');
    expect(_text(tester, 'summary-planned-rest'), startsWith('y '));
    expect(_text(tester, 'summary-planned-rest'), endsWith('31 dic'));
  });

  testWidgets('absences and pay without data fold into one line each; the '
      'pay opens', (tester) async {
    // September has no absences; nothing has a price.
    await _open(tester, 'mes=2026-09', size: const Size(390, 2600));
    expect(
      find.descendant(
        of: _key('summary-absences-fold'),
        matching: find.text('Ninguna'),
      ),
      findsOneWidget,
    );
    expect(_key('summary-estimate'), findsNothing);
    await tester.tap(_key('summary-estimate-fold'));
    await tester.pumpAndSettle();
    expect(_key('summary-estimate'), findsOneWidget);
    expect(_key('summary-rate-action'), findsOneWidget);
    await tester.tap(_key('summary-estimate-fold'));
    await tester.pumpAndSettle();
    expect(_key('summary-estimate'), findsNothing);
  });

  testWidgets('a month with absences lists them instead of folding them', (
    tester,
  ) async {
    await _open(tester, 'mes=2026-10', size: const Size(390, 2600));
    expect(_key('summary-absences-fold'), findsNothing);
    expect(_key('summary-type-vacation'), findsOneWidget);
    expect(_key('summary-estimate-fold'), findsOneWidget);
  });

  testWidgets('screen readers hear the figure with its meaning, the bar as '
      'words and the fold as expandable', (tester) async {
    final handle = tester.ensureSemantics();
    await _open(tester, 'mes=2026-09', size: const Size(390, 2600));
    expect(find.bySemanticsLabel('176 h trabajadas'), findsOneWidget);
    expect(
      find.bySemanticsLabel('176 h trabajadas, 0 h previstas'),
      findsOneWidget,
    );
    expect(
      tester.getSemantics(_key('summary-estimate-fold')),
      matchesSemantics(
        isButton: true,
        hasExpandedState: true,
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
        label: 'Ingresos estimados\nSin precios',
      ),
    );
    handle.dispose();
  });

  testWidgets('an empty month draws the shift cells', (tester) async {
    await _open(tester, 'mes=2026-06');
    expect(_key('summary-empty'), findsOneWidget);
    expect(find.byType(EmptyIllustration), findsOneWidget);
  });

  for (final brightness in Brightness.values) {
    testWidgets('fits 320 dp at x2 in ${brightness.name}', (tester) async {
      await _open(
        tester,
        'mes=2026-10',
        size: const Size(320, 568),
        textScale: 2,
        brightness: brightness,
        goal: const HoursGoal(HoursGoalPeriod.year, 1642),
      );
      expect(tester.takeException(), isNull);
      for (final key in [
        'summary-goal-verdict',
        'summary-breakdown',
        'summary-notes',
      ]) {
        await tester.scrollUntilVisible(
          _key(key),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.takeException(), isNull, reason: key);
      }
    });
  }
}
