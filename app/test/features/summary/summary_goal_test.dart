import 'package:cuadrante/app.dart';
import 'package:cuadrante/core/router.dart';
import 'package:cuadrante/features/schedule/domain/civil_date.dart';
import 'package:cuadrante/features/summary/application/summary_providers.dart';
import 'package:cuadrante/features/summary/data/hours_goal_store.dart';
import 'package:cuadrante/features/summary/domain/hours_goal.dart';
import 'package:cuadrante/features/summary/presentation/summary_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../calendar/harness.dart';

// A3 (worked against planned hours) and C2 (hours goal) on the summary
// screen. The demo data around Monday 19 October 2026 (see
// summary_screen_test.dart): October has 160 h, 96 h of them before the 19th
// (Noche 1-2, Mañana 5-9, Tarde 12-16) and 64 h from the 19th on; September
// has 176 h and November 168 h.

Finder _key(String key) => find.byKey(ValueKey(key));

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(_key(key)).data!;

/// Keeps the goal in memory; [fail] makes every write throw.
class _MemoryGoalStore implements HoursGoalStore {
  _MemoryGoalStore([this.goal]);

  HoursGoal? goal;
  CivilDate? since;
  bool fail = false;

  @override
  Future<HoursGoal?> load() async => goal;

  @override
  Future<CivilDate?> loadSince() async => since;

  @override
  Future<void> save(HoursGoal value) async {
    if (fail) throw StateError('disk full');
    goal = value;
  }

  @override
  Future<void> saveSince(CivilDate date) async {
    if (fail) throw StateError('disk full');
    since = date;
  }

  @override
  Future<void> clear() async {
    if (fail) throw StateError('disk full');
    goal = null;
    since = null;
  }
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(CuadranteApp)));

Future<void> _open(
  WidgetTester tester,
  String month, {
  _MemoryGoalStore? store,
  DateTime Function()? clock,
  Size size = const Size(390, 844),
  double textScale = 1.0,
}) async {
  await pumpCalendar(
    tester,
    clock: clock,
    size: size,
    textScale: textScale,
    overrides: [
      if (store != null) hoursGoalStoreProvider.overrideWithValue(store),
    ],
  );
  _container(tester).read(routerProvider).go('/resumen?mes=$month');
  await tester.pumpAndSettle();
  expect(find.byType(SummaryScreen), findsOneWidget);
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(_key(key));
  await tester.pumpAndSettle();
  await tester.tap(_key(key));
  await tester.pumpAndSettle();
}

Future<void> _mode(WidgetTester tester, String mode) async {
  // Back to the top, where the period pills are.
  tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position
      .jumpTo(0);
  await tester.pumpAndSettle();
  await tester.tap(_key('summary-mode-$mode'));
  await tester.pumpAndSettle();
}

/// Closes the goal sheet as the back gesture would.
Future<void> _closeSheet(WidgetTester tester) async {
  Navigator.of(tester.element(_key('summary-goal-field'))).pop();
  await tester.pumpAndSettle();
}

/// The texts of the notes card.
Iterable<String> _notes(WidgetTester tester) => tester
    .widgetList<Text>(
      find.descendant(of: _key('summary-notes'), matching: find.byType(Text)),
    )
    .map((t) => t.data ?? '');

const _tenseNote =
    'Trabajadas: los días anteriores a hoy. Previstas: de hoy en adelante, '
    'según tu cuadrante.';

void main() {
  group('A3: worked and planned hours', () {
    testWidgets('the current month: worked until yesterday in big, then '
        'the planned ones', (tester) async {
      await _open(tester, '2026-10');
      expect(_text(tester, 'summary-hours'), '96 h');
      expect(_text(tester, 'summary-hours-title'), 'trabajadas hasta ayer');
      expect(
        _text(tester, 'summary-planned-rest'),
        'y 64 h previstas hasta el sáb 31 oct',
      );
      expect(_text(tester, 'summary-legend-done'), '96 h');
      expect(_text(tester, 'summary-legend-planned'), '64 h');
      await tester.scrollUntilVisible(
        _key('summary-notes'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(_notes(tester), contains(_tenseNote));
    });

    testWidgets('a past month says worked, with no second figure', (
      tester,
    ) async {
      await _open(tester, '2026-09');
      expect(_text(tester, 'summary-hours-title'), 'trabajadas');
      expect(_text(tester, 'summary-hours'), '176 h');
      expect(_key('summary-planned-rest'), findsNothing);
      expect(_key('summary-legend-planned'), findsNothing);
      await tester.scrollUntilVisible(
        _key('summary-notes'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(_notes(tester), isNot(contains(_tenseNote)));
    });

    testWidgets('a future month says planned', (tester) async {
      await _open(tester, '2026-11');
      expect(_text(tester, 'summary-hours-title'), 'previstas');
      expect(_text(tester, 'summary-hours'), '168 h');
      expect(_key('summary-planned-rest'), findsNothing);
      expect(_key('summary-legend-done'), findsNothing);
    });

    testWidgets('today comes from the clock: a day later, 8 h more worked', (
      tester,
    ) async {
      // On the 20th the Noche of the 19th is already worked.
      await _open(tester, '2026-10', clock: () => DateTime(2026, 10, 20, 9));
      expect(_text(tester, 'summary-hours'), '104 h');
      expect(
        _text(tester, 'summary-planned-rest'),
        'y 56 h previstas hasta el sáb 31 oct',
      );
    });

    testWidgets('on the first of the next month October is worked', (
      tester,
    ) async {
      await _open(tester, '2026-10', clock: () => DateTime(2026, 11, 1, 9));
      expect(_text(tester, 'summary-hours-title'), 'trabajadas');
      expect(_text(tester, 'summary-hours'), '160 h');
      expect(_key('summary-planned-rest'), findsNothing);
    });

    testWidgets('a free range across today shows both figures', (tester) async {
      await _open(tester, '2026-10');
      await _mode(tester, 'range');
      // The range starts as the month on screen.
      expect(_text(tester, 'summary-hours-title'), 'trabajadas hasta ayer');
      expect(_text(tester, 'summary-hours'), '96 h');
      expect(_key('summary-planned-rest'), findsOneWidget);
    });
  });

  group('C2: hours goal', () {
    testWidgets('without a goal only a quiet button shows', (tester) async {
      await _open(tester, '2026-10', store: _MemoryGoalStore());
      expect(_key('summary-goal-add'), findsOneWidget);
      expect(find.text('Fijar un objetivo de horas'), findsOneWidget);
      expect(_key('summary-goal'), findsNothing);
    });

    testWidgets('a yearly goal set from the sheet is stored and shown for '
        'the month', (tester) async {
      await _open(tester, '2026-10');
      await _tap(tester, 'summary-goal-add');
      expect(find.text('Objetivo de horas'), findsOneWidget);
      expect(
        find.textContaining('Por ejemplo, 1.642 h, una jornada anual'),
        findsOneWidget,
      );
      await tester.enterText(_key('summary-goal-field'), '1642');
      await _tap(tester, 'summary-goal-save');

      expect(_key('summary-goal-add'), findsNothing);
      expect(_key('summary-goal'), findsOneWidget);
      // 1642 h / 12 = 136 h 50 min; 96 h worked + 64 h planned = 160 h.
      expect(_text(tester, 'summary-goal-target-value'), '136 h 50 min');
      expect(
        _text(tester, 'summary-goal-target-detail'),
        '1642 h al año, entre 12',
      );
      expect(_text(tester, 'summary-legend-done'), '96 h');
      expect(_text(tester, 'summary-legend-planned'), '64 h');
      expect(
        _text(tester, 'summary-goal-verdict'),
        'Con lo previsto, 23 h 10 min de más',
      );

      // It is in the database.
      final stored = await tester.runAsync(
        () => _container(tester).read(hoursGoalStoreProvider).load(),
      );
      expect(stored, const HoursGoal(HoursGoalPeriod.year, 1642));
    });

    testWidgets('a past month: worked against the goal', (tester) async {
      await _open(
        tester,
        '2026-09',
        store: _MemoryGoalStore(const HoursGoal(HoursGoalPeriod.year, 1642)),
      );
      expect(_text(tester, 'summary-legend-done'), '176 h');
      expect(_key('summary-legend-planned'), findsNothing);
      expect(
        _text(tester, 'summary-goal-verdict'),
        'Llevas 39 h 10 min de más',
      );
    });

    testWidgets('a past month short of the goal', (tester) async {
      await _open(
        tester,
        '2026-09',
        store: _MemoryGoalStore(const HoursGoal(HoursGoalPeriod.month, 200)),
      );
      expect(_text(tester, 'summary-goal-target-detail'), 'Objetivo mensual');
      expect(_text(tester, 'summary-goal-verdict'), 'Te faltan 24 h');
    });

    testWidgets('a future month with a monthly goal: only planned hours', (
      tester,
    ) async {
      await _open(
        tester,
        '2026-11',
        store: _MemoryGoalStore(const HoursGoal(HoursGoalPeriod.month, 200)),
      );
      expect(_text(tester, 'summary-goal-target-value'), '200 h');
      expect(_key('summary-legend-done'), findsNothing);
      expect(_text(tester, 'summary-legend-planned'), '168 h');
      expect(
        _text(tester, 'summary-goal-verdict'),
        'Con lo previsto, te faltan 32 h',
      );
    });

    testWidgets('exactly on the goal', (tester) async {
      await _open(
        tester,
        '2026-10',
        store: _MemoryGoalStore(const HoursGoal(HoursGoalPeriod.month, 160)),
      );
      expect(
        _text(tester, 'summary-goal-verdict'),
        'Con lo previsto, justo el objetivo',
      );
    });

    testWidgets('the year view takes the yearly goal, or 12 monthly ones', (
      tester,
    ) async {
      final store = _MemoryGoalStore(
        const HoursGoal(HoursGoalPeriod.year, 1642),
      );
      await _open(tester, '2026-10', store: store);
      await _mode(tester, 'year');
      expect(_text(tester, 'summary-goal-target-value'), '1642 h');
      expect(_text(tester, 'summary-goal-target-detail'), 'Objetivo anual');
      expect(_key('summary-legend-done'), findsOneWidget);
      expect(_key('summary-legend-planned'), findsOneWidget);
      expect(_key('summary-year-total'), findsOneWidget);

      store.goal = const HoursGoal(HoursGoalPeriod.month, 140);
      _container(tester).invalidate(hoursGoalProvider);
      await tester.pumpAndSettle();
      expect(_text(tester, 'summary-goal-target-value'), '1680 h');
      expect(
        _text(tester, 'summary-goal-target-detail'),
        '140 h al mes, por 12',
      );
    });

    testWidgets('a free range takes its share of the days', (tester) async {
      await _open(
        tester,
        '2026-10',
        store: _MemoryGoalStore(const HoursGoal(HoursGoalPeriod.year, 1642)),
      );
      await _mode(tester, 'range');
      // 98 520 min x 31 / 365 = 8367.4 -> 139 h 27 min.
      expect(_text(tester, 'summary-goal-target-value'), '139 h 27 min');
      expect(
        _text(tester, 'summary-goal-target-detail'),
        '1642 h al año, la parte de 31 días',
      );
    });

    testWidgets('the notes explain the goal when there is one', (tester) async {
      await _open(
        tester,
        '2026-10',
        store: _MemoryGoalStore(const HoursGoal(HoursGoalPeriod.year, 1642)),
      );
      await tester.scrollUntilVisible(
        _key('summary-notes'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        _notes(tester).any((n) => n.startsWith('Objetivo: en un mes cuenta')),
        isTrue,
      );
    });

    testWidgets('the sheet refuses a number out of range', (tester) async {
      final store = _MemoryGoalStore();
      await _open(tester, '2026-10', store: store);
      await _tap(tester, 'summary-goal-add');
      await tester.enterText(_key('summary-goal-field'), '0');
      await _tap(tester, 'summary-goal-save');
      expect(find.text('Escribe entre 1 y 8784 horas.'), findsOneWidget);
      // Another period clears the message and has its own limit.
      await _tap(tester, 'summary-goal-month');
      expect(find.text('Escribe entre 1 y 8784 horas.'), findsNothing);
      expect(find.text('Horas al mes'), findsOneWidget);
      await tester.enterText(_key('summary-goal-field'), '800');
      await _tap(tester, 'summary-goal-save');
      expect(find.text('Escribe entre 1 y 744 horas.'), findsOneWidget);
      // Typing again clears it.
      await tester.enterText(_key('summary-goal-field'), '80');
      await tester.pump();
      expect(find.text('Escribe entre 1 y 744 horas.'), findsNothing);
      // Closing the sheet keeps everything as it was.
      await _closeSheet(tester);
      expect(store.goal, isNull);
      expect(_key('summary-goal-add'), findsOneWidget);
    });

    testWidgets('change and remove the goal', (tester) async {
      final store = _MemoryGoalStore(
        const HoursGoal(HoursGoalPeriod.year, 1642),
      );
      await _open(tester, '2026-10', store: store);
      await _tap(tester, 'summary-goal-edit');
      // The sheet opens on the current goal.
      expect(
        tester.widget<TextField>(_key('summary-goal-field')).controller!.text,
        '1642',
      );
      await _tap(tester, 'summary-goal-month');
      await tester.enterText(_key('summary-goal-field'), '150');
      await _tap(tester, 'summary-goal-save');
      expect(store.goal, const HoursGoal(HoursGoalPeriod.month, 150));
      expect(_text(tester, 'summary-goal-target-value'), '150 h');
      expect(
        _text(tester, 'summary-goal-verdict'),
        'Con lo previsto, 10 h de más',
      );

      await _tap(tester, 'summary-goal-edit');
      await _tap(tester, 'summary-goal-remove');
      expect(store.goal, isNull);
      expect(_key('summary-goal'), findsNothing);
      expect(_key('summary-goal-add'), findsOneWidget);
    });

    testWidgets('a write that fails says so and changes nothing', (
      tester,
    ) async {
      final store = _MemoryGoalStore()..fail = true;
      await _open(tester, '2026-10', store: store);
      await _tap(tester, 'summary-goal-add');
      await tester.enterText(_key('summary-goal-field'), '1642');
      await _tap(tester, 'summary-goal-save');
      expect(find.text('No se ha podido guardar el objetivo.'), findsOneWidget);
      expect(_key('summary-goal'), findsNothing);
      expect(_key('summary-goal-add'), findsOneWidget);
    });

    testWidgets('a month with no shifts shows the empty state only', (
      tester,
    ) async {
      await _open(
        tester,
        '2026-06',
        store: _MemoryGoalStore(const HoursGoal(HoursGoalPeriod.year, 1642)),
      );
      expect(_key('summary-empty'), findsOneWidget);
      expect(_key('summary-goal'), findsNothing);
      expect(_key('summary-goal-add'), findsNothing);
    });

    for (final (size, scale) in [
      (const Size(320, 568), 1.6),
      (const Size(320, 568), 2.0),
      (const Size(390, 844), 1.0),
    ]) {
      testWidgets('the card and the sheet fit ${size.width.toInt()}x'
          '${size.height.toInt()} x$scale', (tester) async {
        await _open(
          tester,
          '2026-10',
          size: size,
          textScale: scale,
          store: _MemoryGoalStore(const HoursGoal(HoursGoalPeriod.year, 1642)),
        );
        await tester.scrollUntilVisible(
          _key('summary-goal-verdict'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.takeException(), isNull);
        await _tap(tester, 'summary-goal-edit');
        expect(tester.takeException(), isNull);
        await _closeSheet(tester);
        await _mode(tester, 'range');
        await tester.scrollUntilVisible(
          _key('summary-goal-verdict'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.takeException(), isNull);
        await _mode(tester, 'year');
        // A long list of month cards: dragged step by step.
        for (var i = 0; i < 30; i++) {
          if (_key('summary-year-total').evaluate().isNotEmpty) break;
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, -300),
          );
          await tester.pumpAndSettle();
        }
        expect(_key('summary-year-total'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
