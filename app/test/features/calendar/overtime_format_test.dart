import 'package:cuadrante/features/calendar/presentation/overtime_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the multiplier field takes what its error says: 0,01 to 100', () {
    expect(parseMultiplier('1,25'), 12500);
    expect(parseMultiplier('1.5'), 15000);
    expect(parseMultiplier('2'), 20000);
    expect(parseMultiplier('0,01'), 100);
    expect(parseMultiplier('100'), 1000000);
    expect(parseMultiplier('0,0099'), isNull);
    expect(parseMultiplier('0'), isNull);
    expect(parseMultiplier('100,0001'), isNull);
    expect(parseMultiplier('1,23456'), isNull);
    expect(parseMultiplier('abc'), isNull);
  });
}
