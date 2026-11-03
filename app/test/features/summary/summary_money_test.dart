import 'package:cuadrante/app.dart';
import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/core/format/money.dart';
import 'package:cuadrante/core/router.dart';
import 'package:cuadrante/features/absences/application/absence_providers.dart';
import 'package:cuadrante/features/absences/domain/absence_balance.dart';
import 'package:cuadrante/features/absences/presentation/absences_screen.dart';
import 'package:cuadrante/features/schedule/data/schedule_repository.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/features/settings/application/preferences_controller.dart';
import 'package:cuadrante/features/settings/domain/preferences.dart';
import 'package:cuadrante/features/summary/application/summary_providers.dart';
import 'package:cuadrante/features/summary/domain/hours_goal.dart';
import 'package:cuadrante/features/summary/domain/summary_range.dart';
import 'package:cuadrante/features/summary/presentation/summary_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/real_font.dart';
import '../calendar/harness.dart';

// P9 · the summary with the net estimate, «Llevas ganado», «Trimestre» and the
// hours bank, and the vacation card (P3). 19 Oct 2026, 12:00.

const _october = CivilDate(2026, 10, 1);

Finder _key(String key) => find.byKey(ValueKey(key));

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(CuadranteApp)));

/// Lets the database answer (real time) and the screen draw what it got.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 15)),
    );
    await tester.pumpAndSettle();
  }
}

Future<void> _go(WidgetTester tester, String location) async {
  _container(tester).read(routerProvider).go(location);
  await _settle(tester);
}

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(_key(key)).data!;

String _money(WidgetTester tester, int cents) =>
    formatMoneyCents(tester.element(find.byType(SummaryScreen)), cents);

Future<void> _rates(ScheduleRepository repository) async {
  for (final (key, rate) in [
    ('morning', 1000),
    ('afternoon', 1100),
    ('night', 1200),
  ]) {
    await repository.saveShiftType(
      shiftTemplates
          .firstWhere((t) => t.key == key)
          .toShiftType(key)
          .copyWith(hourlyRateCents: rate),
    );
  }
}

Future<void> _reveal(WidgetTester tester, String key) async {
  await tester.scrollUntilVisible(
    _key(key),
    200,
    scrollable: find.byType(Scrollable).first,
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeLocale();
    expect(await loadRoboto(), isTrue, reason: 'Roboto from the Flutter SDK');
  });

  testWidgets('shows the gross and the net estimate of the month', (
    tester,
  ) async {
    await pumpCalendar(
      tester,
      size: const Size(390, 1800),
      prepare: _rates,
      overrides: [
        initialPreferencesProvider.overrideWithValue(
          const Preferences(withholdingPercent: 20),
        ),
      ],
    );
    await _go(tester, '/resumen?mes=2026-10');

    final estimate = _container(tester).read(monthEarningsProvider(_october));
    expect(estimate.grossCents, isNotNull);
    expect(
      _text(tester, 'summary-earnings'),
      _money(tester, estimate.grossCents!),
    );
    expect(find.text('Bruto estimado'), findsOneWidget);
    expect(
      _text(tester, 'summary-net-value'),
      _money(tester, estimate.netCents!),
    );
    expect(_text(tester, 'summary-net-detail'), 'Con una retención del 20 %');
    expect(tester.takeException(), isNull);
  });

  testWidgets('without a withholding the net asks for it and stores it', (
    tester,
  ) async {
    await pumpCalendar(tester, size: const Size(390, 1800), prepare: _rates);
    await _go(tester, '/resumen?mes=2026-10');
    expect(_key('summary-net'), findsNothing);

    await _reveal(tester, 'summary-net-setup');
    await tester.tap(_key('summary-net-setup'));
    await _settle(tester);
    expect(find.text('Retención (%)'), findsOneWidget);

    // 150 is not a percentage.
    await tester.enterText(_key('withholding-field'), '150');
    await tester.tap(_key('withholding-save'));
    await _settle(tester);
    expect(
      find.text('Escribe un número entero entre 0 y 100.'),
      findsOneWidget,
    );

    await tester.enterText(_key('withholding-field'), '15');
    await tester.tap(_key('withholding-save'));
    await _settle(tester);

    expect(_container(tester).read(preferencesProvider).withholdingPercent, 15);
    final estimate = _container(tester).read(monthEarningsProvider(_october));
    expect(estimate.withholdingPercent, 15);
    await _reveal(tester, 'summary-net-value');
    expect(
      _text(tester, 'summary-net-value'),
      _money(tester, estimate.netCents!),
    );
    expect(_key('summary-net-setup'), findsNothing);
  });

  testWidgets('«Llevas ganado» is the month that is running', (tester) async {
    await pumpCalendar(
      tester,
      size: const Size(390, 2200),
      prepare: _rates,
      overrides: [
        initialPreferencesProvider.overrideWithValue(
          const Preferences(withholdingPercent: 10),
        ),
      ],
    );
    await _go(tester, '/resumen?mes=2026-10');
    await _reveal(tester, 'summary-earned');

    final earned = _container(tester).read(earnedSoFarProvider(_october));
    expect(earned.grossCents, isNotNull);
    expect(find.text('LLEVAS GANADO'), findsOneWidget);
    expect(
      _text(tester, 'summary-earned-gross'),
      _money(tester, earned.grossCents!),
    );
    expect(
      _text(tester, 'summary-earned-net-value'),
      _money(tester, earned.netCents!),
    );
    // Until now is less than the whole month.
    final month = _container(tester).read(monthEarningsProvider(_october));
    expect(earned.grossCents!, lessThan(month.grossCents!));

    // Another month is not the one running.
    await _go(tester, '/resumen?mes=2026-09');
    expect(_key('summary-earned'), findsNothing);
  });

  testWidgets('«Trimestre» shows a quarter and steps through quarters', (
    tester,
  ) async {
    await pumpCalendar(tester, size: const Size(390, 1800), prepare: _rates);
    await _go(tester, '/resumen?mes=2026-10');

    await tester.tap(_key('summary-mode-quarter'));
    await _settle(tester);
    expect(_text(tester, 'summary-period'), 'T4 2026');
    expect(_text(tester, 'summary-quarter-dates'), '1 oct 2026 – 31 dic 2026');
    final quarter = _container(tester)
        .read(rangeSummaryProvider(SummaryRange.quarter(2026, Quarter.fourth)));
    expect(quarter.earningsCents, isNotNull);
    expect(
      _text(tester, 'summary-earnings'),
      _money(tester, quarter.earningsCents!),
    );

    await tester.tap(_key('summary-next'));
    await _settle(tester);
    expect(_text(tester, 'summary-period'), 'T1 2027');
    await tester.tap(_key('summary-previous'));
    await tester.tap(_key('summary-previous'));
    await _settle(tester);
    expect(_text(tester, 'summary-period'), 'T3 2026');
    expect(_text(tester, 'summary-quarter-dates'), '1 jul 2026 – 30 sep 2026');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the hours bank sits under the goal of «¿Cómo voy?»', (
    tester,
  ) async {
    await pumpCalendar(tester, size: const Size(390, 2200), prepare: _rates);
    await tester.runAsync(
      () =>
          _container(tester)
              .read(hoursGoalStoreProvider)
              .save(const HoursGoal(HoursGoalPeriod.month, 140)),
    );
    await _go(tester, '/resumen?mes=2026-10');
    await _reveal(tester, 'summary-bag');

    final bag = _container(tester).read(hoursBalanceProvider(_october)).value!;
    expect(bag, isNotNull);
    final label = _text(tester, 'summary-bag-value');
    expect(
      label,
      bag.balanceMinutes == 0
          ? 'A cero'
          : bag.balanceMinutes > 0
          ? endsWith('de más')
          : startsWith('Te faltan'),
    );
    expect(find.text('Bolsa de horas'), findsOneWidget);
    expect(_text(tester, 'summary-bag-detail'), contains('octubre'));
  });

  testWidgets('no goal, no hours bank', (tester) async {
    await pumpCalendar(tester, size: const Size(390, 1800), prepare: _rates);
    await _go(tester, '/resumen?mes=2026-10');
    expect(_key('summary-bag'), findsNothing);
  });

  testWidgets('the vacation card tells what is left and opens the screen', (
    tester,
  ) async {
    await pumpCalendar(tester, size: const Size(390, 1800), prepare: _rates);
    await tester.runAsync(() async {
      final container = _container(tester);
      final listener = container.listen(
        absenceBalancesProvider(2026),
        (_, _) {},
      );
      await container
          .read(absenceBalancesProvider(2026).notifier)
          .save(
            const AbsenceBalance(
              year: 2026,
              type: 'vac',
              name: 'Vacaciones',
              allowedDays: 22,
              shiftTypeQuarters: {'vacation': 4},
            ),
          );
      listener.close();
    });
    await _go(tester, '/resumen?mes=2026-10');

    // 22 allowed - the 2 planned vacation days of the demo data.
    expect(
      _text(tester, 'absence-summary-line-0'),
      'Te quedan 20 días de vacaciones',
    );
    await tester.tap(_key('absence-summary'));
    await _settle(tester);
    expect(find.byType(AbsencesScreen), findsOneWidget);
    expect(_text(tester, 'absence-left-vac'), '20');
  });

  testWidgets('no balances, no vacation card', (tester) async {
    await pumpCalendar(tester, size: const Size(390, 1800), prepare: _rates);
    await _go(tester, '/resumen?mes=2026-10');
    expect(_key('absence-summary'), findsNothing);
  });

  group('layout', () {
    for (final (size, scale, brightness) in [
      (const Size(390, 844), 1.0, Brightness.light),
      (const Size(390, 844), 2.0, Brightness.dark),
      (const Size(320, 568), 1.0, Brightness.dark),
      (const Size(320, 568), 2.0, Brightness.light),
    ]) {
      testWidgets(
        'the money cards at ${size.width.toInt()}x${size.height.toInt()}, '
        'text $scale, ${brightness.name}',
        (tester) async {
          await pumpCalendar(
            tester,
            size: size,
            textScale: scale,
            brightness: brightness,
            prepare: _rates,
            overrides: [
              initialPreferencesProvider.overrideWithValue(
                const Preferences(withholdingPercent: 18),
              ),
            ],
          );
          await tester.runAsync(() async {
            final container = _container(tester);
            await container
                .read(hoursGoalStoreProvider)
                .save(const HoursGoal(HoursGoalPeriod.year, 1642));
            final listener = container.listen(
              absenceBalancesProvider(2026),
              (_, _) {},
            );
            await container
                .read(absenceBalancesProvider(2026).notifier)
                .save(
                  const AbsenceBalance(
                    year: 2026,
                    type: 'vac',
                    name: 'Asuntos propios y libre disposición',
                    allowedDays: 22,
                    shiftTypeQuarters: {'vacation': 4},
                  ),
                );
            listener.close();
          });
          await _go(tester, '/resumen?mes=2026-10');

          for (final key in [
            'absence-summary',
            'summary-bag',
            'summary-earnings',
            'summary-net',
            'summary-earned',
            'summary-earned-net',
          ]) {
            await _reveal(tester, key);
            final rect = tester.getRect(_key(key));
            expect(rect.left, greaterThanOrEqualTo(-0.5), reason: key);
            expect(
              rect.right,
              lessThanOrEqualTo(size.width + 0.5),
              reason: key,
            );
          }
          expect(tester.takeException(), isNull);

          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, 9000),
          );
          await tester.pumpAndSettle();
          await tester.tap(_key('summary-mode-quarter'));
          await _settle(tester);
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}
