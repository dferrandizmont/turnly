import 'dart:async';

import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/core/widgets/keyboard_done_bar.dart';
import 'package:cuadrante/features/calendar/presentation/month_screen.dart';
import 'package:cuadrante/features/calendar/presentation/overtime_types_sheet.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/features/shift_types/presentation/money_input_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'day_sheet_finders.dart';
import 'harness.dart';

// 1.1.0 QA: F4 (the number pad of the overtime sheets has no way to close)
// and F10 (the hourly rate: leading zeros and a vague message).

const _oct21 = CivilDate(2026, 10, 21);

Finder _key(String key) => find.byKey(ValueKey(key));

/// A phone keyboard 300 dp tall.
void _keyboard(WidgetTester tester, {required bool up}) {
  tester.view.viewInsets = FakeViewPadding(bottom: up ? 900 : 0);
}

bool _fieldFocused(WidgetTester tester, String key) => tester
    .widget<EditableText>(
      find.descendant(of: _key(key), matching: find.byType(EditableText)),
    )
    .focusNode
    .hasFocus;

void main() {
  setUpAll(initializeLocale);

  group('F10: the hourly rate field', () {
    const formatter = MoneyInputFormatter();
    const noDecimals = MoneyInputFormatter(decimals: 0);

    TextEditingValue value(String text, [int? caret, int? extent]) =>
        TextEditingValue(
          text: text,
          selection: TextSelection(
            baseOffset: caret ?? text.length,
            extentOffset: extent ?? caret ?? text.length,
          ),
        );

    /// The text after the edit [from] -> [to].
    String edit(
      MoneyInputFormatter f,
      TextEditingValue from,
      TextEditingValue to,
    ) => f.formatEditUpdate(from, to).text;

    test('strips the leading zeros while typing', () {
      expect(edit(formatter, value(''), value('0')), '0');
      expect(edit(formatter, value('0'), value('09')), '9');
      expect(edit(formatter, value('0'), value('00')), '0');
      expect(edit(formatter, value(''), value(',')), '0,');
      expect(edit(formatter, value('0,'), value('0,5')), '0,5');
      expect(edit(formatter, value('0'), value('0,')), '0,');
    });

    test('refuses an edit that breaks the rules and keeps the field as it '
        'was', () {
      final old = value('9999', 2);
      // A fifth digit, a letter, a second separator, a third decimal.
      expect(formatter.formatEditUpdate(old, value('99999', 3)), old);
      expect(formatter.formatEditUpdate(old, value('99a99', 3)), old);
      final withMark = value('12,5', 4);
      expect(formatter.formatEditUpdate(withMark, value('12,5.', 5)), withMark);
      final cents = value('12,50', 5);
      expect(formatter.formatEditUpdate(cents, value('12,505', 6)), cents);
      // No separator at all without decimals.
      final whole = value('12', 2);
      expect(noDecimals.formatEditUpdate(whole, value('12,', 3)), whole);
    });

    test('deleting the 0 of 0,50 keeps the caret next to the comma', () {
      final result = formatter.formatEditUpdate(
        value('0,50', 1),
        value(',50', 0),
      );
      expect(result.text, '0,50');
      expect(result.selection, const TextSelection.collapsed(offset: 1));
    });

    test('a middle edit keeps the caret where it was typed', () {
      // 1234: a digit after the 1 would make five: refused, caret kept.
      final old = value('1234', 1);
      expect(formatter.formatEditUpdate(old, value('15234', 2)), old);
      // 12,50 -> 112,50 is fine and untouched.
      final ok = formatter.formatEditUpdate(
        value('12,50', 0),
        value('112,50', 1),
      );
      expect(ok.text, '112,50');
      expect(ok.selection, const TextSelection.collapsed(offset: 1));
      // 105, the 1 deleted: 05 loses its zero and the caret stays at 0.
      final zeros = formatter.formatEditUpdate(value('105', 1), value('05', 0));
      expect(zeros.text, '5');
      expect(zeros.selection, const TextSelection.collapsed(offset: 0));
    });

    test('a selection moves with the zeros that are dropped', () {
      final result = formatter.formatEditUpdate(
        value('105', 0, 2),
        value('05', 1),
      );
      expect(result.text, '5');
      expect(result.selection, const TextSelection.collapsed(offset: 0));
      final range = formatter.formatEditUpdate(
        value('1,50', 0, 4),
        value('007,50', 1, 3),
      );
      expect(range.text, '7,50');
      expect(
        range.selection,
        const TextSelection(baseOffset: 0, extentOffset: 1),
      );
    });

    test('a paste with grouping marks is read, not folded', () {
      // Spanish, Catalan, Galician and Basque write 1.234,56; English 1,234.56.
      expect(edit(formatter, value(''), value('1.234,56')), '1234,56');
      expect(edit(formatter, value(''), value('1,234.56')), '1234.56');
      expect(edit(formatter, value(''), value('1 234,5')), '1234,5');
      expect(edit(formatter, value(''), value('1 234')), '1234');
      expect(edit(formatter, value(''), value('1.234')), '1234');
      expect(edit(formatter, value(''), value('12,5')), '12,5');
      expect(edit(formatter, value(''), value('0.5')), '0.5');
      // Without decimals only grouping marks mean anything.
      expect(edit(noDecimals, value(''), value('1.234')), '1234');
      expect(edit(noDecimals, value(''), value('123,456')), '123456');
    });

    test('a paste that cannot be read without guessing is refused', () {
      final old = value('7', 1);
      for (final text in [
        '12,5.3', // two kinds of mark, none of them grouping
        '1.2345,6', // a wrong group
        '0.123', // a grouping mark after a zero
        '1.234.567', // seven digits: over the highest rate
        '99999', // five digits
        '12abc',
        '€12,50',
      ]) {
        expect(
          formatter.formatEditUpdate(old, value('7$text')),
          old,
          reason: text,
        );
      }
      // Never 12,5 -> 125 in a currency without decimals.
      expect(edit(noDecimals, value('7'), value('712,5')), '7');
      expect(edit(noDecimals, value(''), value('12,5')), '');
    });

    testWidgets('typing 0 then digits never shows a leading zero', (
      tester,
    ) async {
      await pumpCalendar(tester);
      unawaited(editOvertimeBaseRate(tester.element(find.byType(MonthScreen))));
      await tester.pumpAndSettle();
      String shown() =>
          tester.widget<TextField>(_key('overtime-base-rate')).controller!.text;
      for (final digit in '099999999'.split('')) {
        await tester.enterText(_key('overtime-base-rate'), shown() + digit);
        final text = shown();
        expect(
          text.length > 1 && text.startsWith('0') && text[1] != ',',
          isFalse,
          reason: text,
        );
      }
      // The fifth 9 was refused: the field keeps 9999.
      expect(shown(), '9999');
    });

    testWidgets('an empty rate says the range, with the currency', (
      tester,
    ) async {
      await pumpCalendar(tester);
      unawaited(showOvertimeTypes(tester.element(find.byType(MonthScreen))));
      await tester.pumpAndSettle();
      await tester.tap(_key('overtime-type-new'));
      await tester.pumpAndSettle();
      await tester.enterText(_key('overtime-type-name'), 'Guardia');
      await tester.tap(_key('overtime-mode-fixed'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(_key('overtime-type-save'));
      await tester.tap(_key('overtime-type-save'));
      await tester.pumpAndSettle();
      final message = find.textContaining(
        'Escribe un precio por hora entre 0 y',
      );
      expect(message, findsOneWidget);
      expect(
        tester.widget<Text>(message).data!.replaceAll(' ', ' '),
        'Escribe un precio por hora entre 0 y 9.999,99 €.',
      );
      expect(find.text('Escribe un precio por hora.'), findsNothing);
    });
  });

  group('F4: closing the number pad', () {
    Future<void> openBlockSheet(WidgetTester tester) async {
      await pumpCalendar(tester, size: const Size(390, 844));
      await revealCell(tester, _oct21);
      await tester.tap(cell(_oct21));
      await tester.pumpAndSettle();
      await openDayMore(tester);
      await tester.ensureVisible(_key('day-add-overtime'));
      await tester.pumpAndSettle();
      await tester.tap(_key('day-add-overtime'));
      await tester.pumpAndSettle();
      expect(_key('overtime-sheet'), findsOneWidget);
    }

    testWidgets('the break field: a Done bar above the pad closes it', (
      tester,
    ) async {
      await openBlockSheet(tester);
      addTearDown(() => _keyboard(tester, up: false));
      _keyboard(tester, up: true);
      await tester.pumpAndSettle();
      expect(_key('keyboard-done'), findsNothing);

      await tester.ensureVisible(_key('overtime-break'));
      await tester.tap(_key('overtime-break'));
      await tester.pumpAndSettle();
      expect(_fieldFocused(tester, 'overtime-break'), isTrue);
      expect(numberPadHasFocus(), isTrue);
      expect(_key('keyboard-done'), findsOneWidget);
      // The bar sits right above the keyboard, inside the sheet.
      final bar = tester.getRect(_key('keyboard-done'));
      expect(bar.bottom, lessThanOrEqualTo(844 - 300 + 0.5));

      await tester.tap(_key('keyboard-done'));
      await tester.pumpAndSettle();
      expect(_fieldFocused(tester, 'overtime-break'), isFalse);
      expect(_key('keyboard-done'), findsNothing);
    });

    testWidgets('a tap on an empty part of the sheet closes the pad', (
      tester,
    ) async {
      await openBlockSheet(tester);
      addTearDown(() => _keyboard(tester, up: false));
      _keyboard(tester, up: true);
      await tester.pumpAndSettle();
      await tester.ensureVisible(_key('overtime-break'));
      await tester.tap(_key('overtime-break'));
      await tester.pumpAndSettle();
      expect(_fieldFocused(tester, 'overtime-break'), isTrue);

      // The label of the field is not a control.
      await tester.tap(find.text('Nota corta (opcional)'));
      await tester.pumpAndSettle();
      expect(_fieldFocused(tester, 'overtime-break'), isFalse);
    });

    testWidgets('the text field of the note does not get the Done bar', (
      tester,
    ) async {
      await openBlockSheet(tester);
      addTearDown(() => _keyboard(tester, up: false));
      _keyboard(tester, up: true);
      await tester.pumpAndSettle();
      await tester.ensureVisible(_key('overtime-note'));
      await tester.tap(_key('overtime-note'));
      await tester.pumpAndSettle();
      expect(numberPadHasFocus(), isFalse);
      expect(_key('keyboard-done'), findsNothing);
    });

    testWidgets('the rate field of the type form closes the same way', (
      tester,
    ) async {
      await pumpCalendar(tester);
      unawaited(showOvertimeTypes(tester.element(find.byType(MonthScreen))));
      await tester.pumpAndSettle();
      await tester.tap(_key('overtime-type-new'));
      await tester.pumpAndSettle();
      await tester.tap(_key('overtime-mode-fixed'));
      await tester.pumpAndSettle();
      addTearDown(() => _keyboard(tester, up: false));
      _keyboard(tester, up: true);
      await tester.pumpAndSettle();
      await tester.ensureVisible(_key('overtime-type-rate'));
      await tester.tap(_key('overtime-type-rate'));
      await tester.pumpAndSettle();
      expect(_fieldFocused(tester, 'overtime-type-rate'), isTrue);
      expect(_key('keyboard-done'), findsOneWidget);
      await tester.tap(_key('keyboard-done'));
      await tester.pumpAndSettle();
      expect(_fieldFocused(tester, 'overtime-type-rate'), isFalse);
    });
  });
}
