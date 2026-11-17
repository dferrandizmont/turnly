import 'dart:async';

import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/features/calendar/presentation/month_screen.dart';
import 'package:cuadrante/features/calendar/presentation/overtime_types_sheet.dart';
import 'package:cuadrante/features/shift_types/presentation/money_input_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

// iOS 1.2.0 QA, iPhone F5: the rate field of an overtime type refused the
// digits past the cap without a word.

Finder _key(String key) => find.byKey(ValueKey(key));

void main() {
  setUpAll(initializeLocale);

  group('MoneyInputFormatter.onAtLimit', () {
    TextEditingValue value(String text) => TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );

    test('a digit past the cap is refused and reported', () {
      var calls = 0;
      final formatter = MoneyInputFormatter(onAtLimit: () => calls++);
      final out = formatter.formatEditUpdate(value('9999'), value('99999'));
      expect(out.text, '9999');
      expect(calls, 1);
    });

    test('a third decimal is refused and reported', () {
      var calls = 0;
      final formatter = MoneyInputFormatter(onAtLimit: () => calls++);
      formatter.formatEditUpdate(value('12,34'), value('12,345'));
      expect(calls, 1);
    });

    test('a letter is refused without the message', () {
      var calls = 0;
      final formatter = MoneyInputFormatter(onAtLimit: () => calls++);
      final out = formatter.formatEditUpdate(value('12'), value('12a'));
      expect(out.text, '12');
      expect(calls, 0);
    });

    test('deleting never reports', () {
      var calls = 0;
      final formatter = MoneyInputFormatter(onAtLimit: () => calls++);
      formatter.formatEditUpdate(value('9999'), value('999'));
      expect(calls, 0);
    });
  });

  testWidgets('the rate of a new type says the highest it takes', (
    tester,
  ) async {
    await pumpCalendar(tester);
    unawaited(showOvertimeTypes(tester.element(find.byType(MonthScreen))));
    await tester.pumpAndSettle();
    await tester.tap(_key('overtime-type-new'));
    await tester.pumpAndSettle();
    await tester.tap(_key('overtime-mode-fixed'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(_key('overtime-type-rate'));
    await tester.pumpAndSettle();

    await tester.enterText(_key('overtime-type-rate'), '9999');
    await tester.pumpAndSettle();
    expect(find.textContaining('El máximo es'), findsNothing);

    await tester.enterText(_key('overtime-type-rate'), '99999');
    await tester.pumpAndSettle();
    expect(find.textContaining('El máximo es'), findsOneWidget);
    expect(
      tester.widget<TextField>(_key('overtime-type-rate')).controller!.text,
      '9999',
    );

    // Deleting a digit takes the message away.
    await tester.enterText(_key('overtime-type-rate'), '999');
    await tester.pumpAndSettle();
    expect(find.textContaining('El máximo es'), findsNothing);
  });
}
