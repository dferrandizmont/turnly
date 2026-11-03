import 'package:cuadrante/features/summary/domain/payroll.dart';
import 'package:flutter_test/flutter_test.dart';

// The net estimate (P9, fila 25 de `docs/paridad-pago.md`): the gross without
// the withholding the user set.

void main() {
  group('the net', () {
    test('is the gross without a withholding', () {
      expect(netCentsFrom(10000, 0), 10000);
      expect(netCentsFrom(10000, 15), 8500);
      expect(netCentsFrom(10000, 100), 0);
    });

    test('rounds to the cent, half away from zero', () {
      // 101 cents with a 15 % withholding: 85,85 -> 86.
      expect(netCentsFrom(101, 15), 86);
      expect(netCentsFrom(1, 50), 1);
      expect(netCentsFrom(-101, 15), -86);
    });

    test('cuts a percentage outside the range', () {
      expect(netCentsFrom(10000, -10), 10000);
      expect(netCentsFrom(10000, 150), 0);
    });
  });

  group('the estimate', () {
    test('holds the gross and the net', () {
      final estimate = earningsEstimate(10000, withholdingPercent: 20);
      expect(estimate.grossCents, 10000);
      expect(estimate.netCents, 8000);
      expect(estimate.hasMoney, isTrue);
      expect(estimate.withWithholding(0).netCents, 10000);
    });

    test('without money there is nothing to show', () {
      final estimate = earningsEstimate(null, withholdingPercent: 20);
      expect(estimate.grossCents, isNull);
      expect(estimate.netCents, isNull);
      expect(estimate.hasMoney, isFalse);
    });

    test('two estimates with the same numbers are the same', () {
      expect(
        earningsEstimate(100, withholdingPercent: 10),
        earningsEstimate(100, withholdingPercent: 10),
      );
      expect(
        earningsEstimate(100, withholdingPercent: 10) ==
            earningsEstimate(100, withholdingPercent: 20),
        isFalse,
      );
    });
  });
}
