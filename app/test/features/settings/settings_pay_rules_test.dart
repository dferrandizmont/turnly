import 'package:cuadrante/features/calendar/application/schedule_controller.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/features/summary/data/hours_goal_store.dart';
import 'package:cuadrante/features/summary/data/pay_rules_store.dart';
import 'package:cuadrante/features/summary/domain/hours_goal.dart';
import 'package:cuadrante/features/summary/domain/overtime_cap.dart';
import 'package:cuadrante/features/summary/domain/pay_templates.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';

// Propuestas 2 y 8 in Ajustes › Horas y dinero: the closing day, the cap of
// the overtime and the templates of pluses, with normal and large text.
void main() {
  Finder key(String k) => find.byKey(ValueKey(k));

  Future<void> tapKey(WidgetTester tester, String k) async {
    await tester.ensureVisible(key(k));
    await tester.pumpAndSettle();
    await tester.tap(key(k));
    await tester.pumpAndSettle();
  }

  for (final (size, scale) in [
    (const Size(390, 2600), 1.0),
    (const Size(320, 2600), 2.0),
  ]) {
    final label = '${size.width.toInt()} dp, text $scale';

    testWidgets('stores the closing day and the overtime cap at $label', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      final app = await AppUnderTest.pump(tester, size: size);
      await app.openSettings();

      expect(find.text('Fin de mes'), findsOneWidget);
      expect(find.text('Sin tope'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // The closing day: 20, then a bad one, then empty again.
      await tapKey(tester, 'settings-closing-day');
      await tester.enterText(key('closing-day-field'), '20');
      await tapKey(tester, 'closing-day-save');
      expect(find.text('Día 20'), findsOneWidget);
      expect(
        (await app.real(() => PayRulesStore(app.database).load())).closingDay,
        20,
      );

      await tapKey(tester, 'settings-closing-day');
      await tester.enterText(key('closing-day-field'), '45');
      await tapKey(tester, 'closing-day-save');
      expect(
        find.text('Escribe un día del 1 al 30, o déjalo vacío para el mes natural.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.enterText(key('closing-day-field'), '');
      await tapKey(tester, 'closing-day-save');
      expect(find.text('Fin de mes'), findsOneWidget);

      // The cap starts at the legal 80 h a year.
      await tapKey(tester, 'settings-overtime-cap');
      expect(
        tester.widget<TextField>(key('overtime-cap-field')).controller!.text,
        '80',
      );
      expect(tester.takeException(), isNull);
      await tapKey(tester, 'overtime-cap-month');
      await tester.enterText(key('overtime-cap-field'), '12');
      await tapKey(tester, 'overtime-cap-save');
      expect(find.text('12 h al mes'), findsOneWidget);
      expect(
        (await app.real(() => PayRulesStore(app.database).load())).overtimeCap,
        const OvertimeCap(OvertimeCapPeriod.month, 12),
      );

      await tapKey(tester, 'settings-overtime-cap');
      await tapKey(tester, 'overtime-cap-remove');
      expect(find.text('Sin tope'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a template writes the pluses into the shifts at $label', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      final app = await AppUnderTest.pump(tester, size: size);
      await app.openSettings();

      await tapKey(tester, 'settings-pay-template');
      expect(tester.takeException(), isNull);
      // Every amount starts at 0: the app invents no salary.
      expect(
        tester
            .widget<TextField>(key('pay-template-amount-nightPerHour'))
            .controller!
            .text,
        '0',
      );

      // Vigilantes bring the annual hours of their national agreement.
      await tapKey(tester, 'pay-template-privateSecurity');
      expect(
        tester.widget<TextField>(key('pay-template-annual')).controller!.text,
        '1782',
      );
      expect(tester.takeException(), isNull);

      await tester.enterText(key('pay-template-amount-nightPerHour'), '1,50');
      await tester.enterText(key('pay-template-amount-holidayPerHour'), '3');
      await tapKey(tester, 'pay-template-apply');
      // The demo days already use these shifts: it asks which days.
      if (key('shift-scope-every-day').evaluate().isNotEmpty) {
        await tapKey(tester, 'shift-scope-every-day');
      }
      await tester.pumpAndSettle();

      final work = app.container
          .read(scheduleControllerProvider)
          .palette
          .where((t) => t.category == ShiftCategory.work && t.hasTimes);
      expect(work, isNotEmpty);
      for (final type in work) {
        // Only the types with night hours get the night plus (F3).
        expect(
          type.nightPlusCentsPerHour,
          hasNightHours(type) ? 150 : isNull,
          reason: type.name,
        );
        expect(type.holidayPlusCentsPerHour, 300, reason: type.name);
      }
      expect(
        await app.real(() => HoursGoalStore(app.database).load()),
        const HoursGoal(HoursGoalPeriod.year, 1782),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
