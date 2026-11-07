import 'package:cuadrante/app.dart';
import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/core/format/money.dart';
import 'package:cuadrante/core/router.dart';
import 'package:cuadrante/features/calendar/application/schedule_controller.dart';
import 'package:cuadrante/features/schedule/data/schedule_repository.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/features/summary/application/summary_providers.dart';
import 'package:cuadrante/features/summary/domain/month_summary.dart';
import 'package:cuadrante/features/summary/domain/overtime_cap.dart';
import 'package:cuadrante/features/summary/presentation/summary_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/real_font.dart';
import '../calendar/harness.dart';

// Propuestas 2 y 8 in the summary: the breakdown of the pluses, the cap of
// the overtime and the payroll month of a closing day, with normal and large
// text. Demo data of October 2026 (19 Oct 2026, 12:00).

const _october = CivilDate(2026, 10, 1);

Finder _key(String key) => find.byKey(ValueKey(key));

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(CuadranteApp)));

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

Future<void> _reveal(WidgetTester tester, String key) async {
  await tester.scrollUntilVisible(
    _key(key),
    200,
    scrollable: find.byType(Scrollable).first,
  );
}

/// Mañana and Tarde with a rate; Noche with a plus per night and holiday
/// hour.
Future<void> _pluses(ScheduleRepository repository) async {
  for (final (key, rate) in [('morning', 1000), ('afternoon', 1100)]) {
    await repository.saveShiftType(
      shiftTemplates
          .firstWhere((t) => t.key == key)
          .toShiftType(key)
          .copyWith(hourlyRateCents: rate),
    );
  }
  await repository.saveShiftType(
    shiftTemplates
        .firstWhere((t) => t.key == 'night')
        .toShiftType('night')
        .copyWith(nightPlusCentsPerHour: 200, holidayPlusCentsPerHour: 300),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeLocale();
    expect(await loadRoboto(), isTrue, reason: 'Roboto from the Flutter SDK');
  });

  for (final (size, scale) in [
    (const Size(390, 2400), 1.0),
    (const Size(320, 2400), 2.0),
  ]) {
    final label = '${size.width.toInt()} dp, text $scale';

    testWidgets('the estimate breaks down the night plus at $label', (
      tester,
    ) async {
      await pumpCalendar(
        tester,
        size: size,
        textScale: scale,
        prepare: _pluses,
      );
      await _go(tester, '/resumen?mes=2026-10');
      final summary = _container(tester).read(monthSummaryProvider(_october));
      expect(summary.nightPlusCents, greaterThan(0));
      await _reveal(tester, 'summary-night-plus');
      expect(
        tester.widget<Text>(_key('summary-night-plus-value')).data,
        formatMoneyCents(
          tester.element(find.byType(SummaryScreen)),
          summary.nightPlusCents,
        ),
      );
      expect(find.text('Plus nocturno'), findsOneWidget);
      // Without a cap, no card of the cap.
      expect(_key('summary-overtime-cap'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the overtime cap warns when it is reached at $label', (
      tester,
    ) async {
      await pumpCalendar(tester, size: size, textScale: scale);
      final container = _container(tester);
      await tester.runAsync(
        () => container
            .read(payRulesStoreProvider)
            .setOvertimeCap(const OvertimeCap(OvertimeCapPeriod.month, 2)),
      );
      final controller = container.read(scheduleControllerProvider.notifier);
      controller.setDayExtras(
        const CivilDate(2026, 10, 26),
        overtimeMinutes: 90,
      );
      await tester.pumpAndSettle();
      await _go(tester, '/resumen?mes=2026-10');

      // 1 h 30 of 2 h: 75 %, no warning yet.
      expect(_key('summary-overtime-cap'), findsOneWidget);
      expect(_key('summary-overtime-cap-near'), findsNothing);
      expect(find.text('Te quedan 30 min'), findsOneWidget);

      controller.setDayExtras(
        const CivilDate(2026, 10, 19),
        overtimeMinutes: 30,
      );
      await _settle(tester);
      expect(_key('summary-overtime-cap-reached'), findsOneWidget);
      expect(find.text('Has llegado al tope de horas extra.'), findsOneWidget);

      controller.setDayExtras(
        const CivilDate(2026, 10, 19),
        overtimeMinutes: 90,
      );
      await _settle(tester);
      expect(_key('summary-overtime-cap-over'), findsOneWidget);
      expect(
        find.text('Has pasado el tope de horas extra en 1 h.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a closing day makes the month the payroll month at $label', (
      tester,
    ) async {
      await pumpCalendar(tester, size: size, textScale: scale);
      final container = _container(tester);
      await tester.runAsync(
        () => container.read(payRulesStoreProvider).setClosingDay(20),
      );
      await _go(tester, '/resumen?mes=2026-10');

      expect(_key('summary-pay-period-dates'), findsOneWidget);
      final schedule = container.read(scheduleControllerProvider).schedule;
      final holidays = container.read(summaryHolidaysProvider);
      final expected = summarizeRange(
        schedule,
        const CivilDate(2026, 9, 21),
        const CivilDate(2026, 10, 20),
        holidays: holidays,
      );
      final shown = container.read(monthSummaryProvider(_october));
      expect(shown.workedMinutes, expected.workedMinutes);
      expect(shown.month, _october);

      await _reveal(tester, 'summary-notes');
      expect(find.textContaining('Mes de nómina'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
