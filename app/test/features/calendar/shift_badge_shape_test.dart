import 'package:cuadrante/core/theme/app_theme.dart';
import 'package:cuadrante/features/calendar/presentation/shift_badge.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Rad.square is a quarter of the side, never more than Rad.input', () {
    expect(Rad.square(28), 7);
    expect(Rad.square(48), 12);
    expect(Rad.square(56), Rad.input);
    expect(Rad.square(200), Rad.input);
    expect(Rad.squareRadius(36), BorderRadius.circular(9));
    // Never a circle: the radius stays well under half the side.
    for (final size in <double>[8, 18, 24, 28, 36, 44, 48, 54, 72, 100]) {
      expect(Rad.square(size), lessThan(size / 2));
    }
  });

  for (final size in [Disc.s, Disc.m, Disc.l, Disc.puck]) {
    testWidgets('ShiftBadge of $size dp is a rounded square, not a circle', (
      tester,
    ) async {
      final shift = ShiftType(
        id: 'morning',
        code: 'M',
        name: 'Mañana',
        colorValue: ShiftPalette.morning.toARGB32(),
        category: ShiftCategory.work,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Center(
            child: ShiftBadge(shift: shift, size: size),
          ),
        ),
      );
      final box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(ShiftBadge),
          matching: find.byType(DecoratedBox),
        ),
      );
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.shape, BoxShape.rectangle);
      final radius = (decoration.borderRadius! as BorderRadius).topLeft.x;
      expect(radius, Rad.square(size));
      expect(radius, lessThan(size / 2));
      expect(tester.getSize(find.byType(ShiftBadge)), Size.square(size));
    });
  }
}
