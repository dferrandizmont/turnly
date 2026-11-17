import 'package:cuadrante/features/shift_types/presentation/money_input_formatter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

TextEditingValue _value(String text) => TextEditingValue(
  text: text,
  selection: TextSelection.collapsed(offset: text.length),
);

void main() {
  for (final (decimals, maximum, integerMaximum, tooMuch) in [
    (0, '999999', '999999', '1000000'),
    (2, '9999,99', '9999', '10000'),
    (3, '999,999', '999', '1000'),
  ]) {
    test('reports the limit for $decimals currency decimals', () {
      var calls = 0;
      final formatter = MoneyInputFormatter(
        decimals: decimals,
        onAtLimit: () => calls++,
      );
      final old = _value(integerMaximum);
      final maxValue = _value(maximum);
      expect(
        formatter.formatEditUpdate(TextEditingValue.empty, maxValue),
        maxValue,
      );
      expect(calls, 0);
      expect(formatter.formatEditUpdate(old, _value(tooMuch)), old);
      expect(calls, 1);
      expect(formatter.formatEditUpdate(old, _value('25')).text, '25');
      expect(calls, 1);
    });
  }

  for (final separator in [',', '.']) {
    for (final paste in [false, true]) {
      test('reports the limit with excess precision when '
          '${paste ? 'pasting' : 'typing'} with $separator', () {
        var calls = 0;
        final formatter = MoneyInputFormatter(onAtLimit: () => calls++);
        final old = _value(paste ? '12' : '10000${separator}00');

        expect(
          formatter.formatEditUpdate(old, _value('10000${separator}001')),
          old,
        );
        expect(calls, 1);
      });
    }
  }
}
