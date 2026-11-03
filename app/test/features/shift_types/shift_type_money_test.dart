import 'package:cuadrante/core/router.dart';
import 'package:cuadrante/features/shift_types/presentation/shift_type_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/real_font.dart';
import '../calendar/harness.dart';
import 'shift_types_screen_test.dart';

// P9 · the night and holiday pluses per hour and the place of a shift type.

Finder _key(String key) => find.byKey(ValueKey(key));

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    expect(await loadRoboto(), isTrue);
  });

  testWidgets('the pluses and the place are saved, reopen and can be cleared', (
    tester,
  ) async {
    await pumpCalendar(tester, size: const Size(390, 2400));
    await openShiftTypes(tester);
    await openNewShift(tester);
    await typeInto(tester, 'shift-name', 'Guardia');
    await typeInto(tester, 'shift-rate', '12,50');
    await typeInto(tester, 'shift-night-plus', '1,75');
    await typeInto(tester, 'shift-holiday-plus', '3');
    await typeInto(tester, 'shift-location', 'Hospital, planta 3');
    await save(tester);

    final created = stateOf(tester).palette.last;
    expect(created.nightPlusCentsPerHour, 175);
    expect(created.holidayPlusCentsPerHour, 300);
    expect(created.location, 'Hospital, planta 3');
    final stored = (await storedSnapshot(tester)).palette.last;
    expect(stored.nightPlusCentsPerHour, 175);
    expect(stored.holidayPlusCentsPerHour, 300);
    expect(stored.location, 'Hospital, planta 3');

    await tester.scrollUntilVisible(
      _key('shift-row-${created.id}'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tapKey(tester, 'shift-row-${created.id}');
    String field(String key) =>
        tester.widget<TextField>(_key(key)).controller!.text;
    expect(field('shift-night-plus'), '1,75');
    expect(field('shift-holiday-plus'), '3');
    expect(field('shift-location'), 'Hospital, planta 3');

    await typeInto(tester, 'shift-night-plus', '');
    await typeInto(tester, 'shift-location', '');
    await save(tester);
    final cleared = (await storedSnapshot(tester)).palette.last;
    expect(cleared.nightPlusCentsPerHour, isNull);
    expect(cleared.holidayPlusCentsPerHour, 300);
    expect(cleared.location, isNull);
  });

  testWidgets('a plus that is not an amount blocks the save and says why', (
    tester,
  ) async {
    await pumpCalendar(tester, size: const Size(390, 2400));
    await openShiftTypes(tester);
    await openNewShift(tester);
    await typeInto(tester, 'shift-name', 'Guardia');
    await typeInto(tester, 'shift-holiday-plus', '1,234');
    await save(tester);
    expect(_key('shift-save'), findsOneWidget);
    expect(
      find.text('Escribe un importe válido, por ejemplo 12,50'),
      findsOneWidget,
    );
    await typeInto(tester, 'shift-holiday-plus', '1,23');
    await save(tester);
    expect(stateOf(tester).palette.last.holidayPlusCentsPerHour, 123);
  });

  testWidgets('a rest shift has no pluses and no place', (tester) async {
    await pumpCalendar(tester, size: const Size(390, 2400));
    await openShiftTypes(tester);
    await openNewShift(tester);
    await tapKey(tester, 'category-rest');
    expect(_key('shift-night-plus'), findsNothing);
    expect(_key('shift-holiday-plus'), findsNothing);
    expect(_key('shift-location'), findsNothing);
  });

  group('layout', () {
    for (final (size, scale, brightness) in [
      (const Size(390, 844), 1.0, Brightness.light),
      (const Size(390, 844), 2.0, Brightness.dark),
      (const Size(320, 568), 1.0, Brightness.dark),
      (const Size(320, 568), 2.0, Brightness.light),
    ]) {
      testWidgets(
        'the new fields at ${size.width.toInt()}x${size.height.toInt()}, '
        'text $scale, ${brightness.name}',
        (tester) async {
          await pumpCalendar(
            tester,
            size: size,
            textScale: scale,
            brightness: brightness,
          );
          appContainer(tester).read(routerProvider).go(AppRoutes.shiftTypeNew);
          await tester.pumpAndSettle();
          await typeInto(tester, 'shift-name', 'Plus');
          for (final key in [
            'shift-night-plus',
            'shift-holiday-plus',
            'shift-location',
          ]) {
            await typeInto(
              tester,
              key,
              key == 'shift-location' ? 'Hospital' : '99999',
            );
            final field = find
                .ancestor(of: _key(key), matching: find.byType(Column))
                .first;
            final rect = tester.getRect(field);
            expect(rect.left, greaterThanOrEqualTo(0), reason: key);
            expect(rect.right, lessThanOrEqualTo(size.width), reason: key);
            expect(tester.takeException(), isNull, reason: key);
          }
          // A bad amount at the largest text.
          await typeInto(tester, 'shift-night-plus', '1,2345');
          await save(tester);
          expect(tester.takeException(), isNull);
          expect(find.byType(ShiftTypeFormScreen), findsOneWidget);
        },
      );
    }
  });
}
