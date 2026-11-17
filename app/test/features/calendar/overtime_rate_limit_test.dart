import 'package:cuadrante/core/format/money.dart';
import 'package:cuadrante/core/l10n/l10n.dart';
import 'package:cuadrante/features/calendar/presentation/month_screen.dart';
import 'package:cuadrante/features/calendar/presentation/overtime_types_sheet.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

Finder _key(String key) => find.byKey(ValueKey(key));

void main() {
  for (final baseRate in [false, true]) {
    testWidgets(
      'exceeding the ${baseRate ? 'base' : 'fixed'} rate shows its maximum',
      (tester) async {
        await pumpCalendar(tester);
        final context = tester.element(find.byType(MonthScreen));
        final expected = context.l10n.overtimeRateAtMax(
          formatMoneyCents(context, maxHourlyRateCents),
        );
        expect(expected, contains('9.999,99'));
        if (baseRate) {
          editOvertimeBaseRate(context);
        } else {
          editOvertimeType(context);
        }
        await tester.pumpAndSettle();
        if (!baseRate) {
          await tester.enterText(_key('overtime-type-name'), 'Tarifa');
          await tester.ensureVisible(_key('overtime-mode-fixed'));
          await tester.tap(_key('overtime-mode-fixed'));
          await tester.pumpAndSettle();
        }
        final field = _key(
          baseRate ? 'overtime-base-rate' : 'overtime-type-rate',
        );
        await tester.ensureVisible(field);
        TextField rate() => tester.widget<TextField>(field);

        for (final text in ['9', '99', '999', '9999']) {
          await tester.enterText(field, text);
          await tester.pumpAndSettle();
          expect(rate().controller!.text, text);
          expect(rate().decoration!.helperText, isNull);
        }
        for (final text in ['99999', '99999999', '10000,001', '10000.001']) {
          await tester.enterText(field, text);
          await tester.pumpAndSettle();
          expect(rate().controller!.text, '9999');
          expect(rate().decoration!.helperText, expected);
          expect(find.text(expected), findsOneWidget);
        }
        await tester.enterText(field, '9999,99');
        await tester.pumpAndSettle();
        expect(rate().decoration!.helperText, isNull);
        expect(rate().controller!.text, '9999,99');
        await tester.enterText(field, '');
        await tester.pumpAndSettle();
        expect(rate().decoration!.helperText, isNull);
        await tester.enterText(field, '25');
        await tester.pumpAndSettle();
        final save = _key(
          baseRate ? 'overtime-base-rate-save' : 'overtime-type-save',
        );
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing);
        if (baseRate) {
          expect(scheduleOf(tester).baseHourlyRateCents, 2500);
        } else {
          expect(scheduleOf(tester).overtimeTypes.last.hourlyRateCents, 2500);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
