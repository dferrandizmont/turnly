import 'package:cuadrante/core/format/money.dart';
import 'package:cuadrante/features/calendar/application/schedule_controller.dart';
import 'package:cuadrante/features/calendar/presentation/day_extra_amount_section.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/features/summary/application/summary_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'day_sheet_finders.dart';
import 'harness.dart';

// P9 · «Importe extra» in «Más opciones» of the day detail.
const _oct26 = CivilDate(2026, 10, 26);

Finder _key(String key) => find.byKey(ValueKey(key));

int? _extra(WidgetTester tester) =>
    containerOf(tester)
        .read(scheduleControllerProvider)
        .schedule
        .entries[_oct26]
        ?.extraAmountCents;

String _field(WidgetTester tester) =>
    tester.widget<TextField>(_key('day-extra-amount-field')).controller!.text;

Future<void> _open(WidgetTester tester) async {
  await revealCell(tester, _oct26);
  await tester.tap(cell(_oct26));
  await tester.pumpAndSettle();
  await openDayMore(tester);
  await tester.ensureVisible(_key('day-extra-amount-field'));
  await tester.pumpAndSettle();
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(
    DayExtraAmountSection.settle + const Duration(milliseconds: 50),
  );
  await tester.pumpAndSettle();
}

int _monthExtra(WidgetTester tester) =>
    containerOf(tester)
        .read(monthSummaryProvider(const CivilDate(2026, 10, 1)))
        .extraAmountCents;

void main() {
  testWidgets('is in «Más opciones», empty, and named in the folded line', (
    tester,
  ) async {
    await pumpCalendar(tester, size: const Size(390, 1400));
    await revealCell(tester, _oct26);
    await tester.tap(cell(_oct26));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(_key('day-more-summary')).data,
      contains('Importe extra'),
    );
    await openDayMore(tester);
    expect(find.text('Importe extra'), findsWidgets);
    expect(_field(tester), '');
    expect(_key('day-extra-amount-clear'), findsNothing);
  });

  testWidgets('what is typed is stored once, as one undo step, and counts', (
    tester,
  ) async {
    await pumpCalendar(tester, size: const Size(390, 1400));
    await _open(tester);
    final before = _monthExtra(tester);

    await tester.enterText(_key('day-extra-amount-field'), '2');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(_key('day-extra-amount-field'), '25,5');
    expect(_extra(tester), isNull, reason: 'not written while typing');
    await _settle(tester);
    expect(_extra(tester), 2550);
    expect(_monthExtra(tester) - before, 2550);
    final money = formatMoneyCents(tester.element(_key('day-more')), 2550);
    expect(
      tester.widget<Text>(_key('day-more-summary')).data,
      contains('Importe extra: $money'),
    );

    // The undo of the header takes it back and clears the field.
    await tester.tap(_key('day-undo'));
    await tester.pumpAndSettle();
    expect(_extra(tester), isNull);
    expect(_field(tester), '');
  });

  testWidgets('a negative amount is a deduction; the cross clears it', (
    tester,
  ) async {
    await pumpCalendar(tester, size: const Size(390, 1400));
    await _open(tester);
    await tester.enterText(_key('day-extra-amount-field'), '-10,50');
    await _settle(tester);
    expect(_extra(tester), -1050);

    await tester.tap(_key('day-extra-amount-clear'));
    await tester.pumpAndSettle();
    expect(_extra(tester), isNull);
    expect(_field(tester), '');
  });

  testWidgets('a stored amount shows when the day opens', (tester) async {
    await pumpCalendar(tester, size: const Size(390, 1400));
    containerOf(tester)
        .read(scheduleControllerProvider.notifier)
        .setDayExtraAmount(_oct26, 4000);
    await tester.pumpAndSettle();
    await _open(tester);
    expect(_field(tester), '40');
  });

  testWidgets('not an amount: the message shows and nothing is written', (
    tester,
  ) async {
    await pumpCalendar(tester, size: const Size(390, 1400));
    await _open(tester);
    await tester.enterText(_key('day-extra-amount-field'), '1,234');
    await _settle(tester);
    expect(
      find.text('Escribe un importe válido, por ejemplo 25 o -10,50'),
      findsOneWidget,
    );
    expect(_extra(tester), isNull);
  });

  testWidgets(
    'clearing the day straight away removes the amount for good; closing '
    'the sheet writes what is pending',
    (tester) async {
      await pumpCalendar(tester, size: const Size(390, 1400));
      await _open(tester);
      await tester.enterText(_key('day-extra-amount-field'), '12');
      // Straight to «Borrar día» without waiting for the quiet time.
      await tester.ensureVisible(_key('day-clear'));
      await tester.pumpAndSettle();
      await tester.tap(_key('day-clear'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
      expect(_extra(tester), isNull);

      await _open(tester);
      await tester.enterText(_key('day-extra-amount-field'), '12');
      Navigator.of(tester.element(find.byType(BottomSheet))).pop();
      await tester.pumpAndSettle();
      expect(_extra(tester), 1200);
    },
  );

  group('layout', () {
    for (final (size, scale, brightness) in [
      (const Size(390, 844), 1.0, Brightness.light),
      (const Size(390, 844), 2.0, Brightness.dark),
      (const Size(320, 568), 1.0, Brightness.dark),
      (const Size(320, 568), 2.0, Brightness.light),
    ]) {
      testWidgets(
        'the field at ${size.width.toInt()}x${size.height.toInt()}, text '
        '$scale, ${brightness.name}',
        (tester) async {
          await pumpCalendar(
            tester,
            size: size,
            textScale: scale,
            brightness: brightness,
          );
          await _open(tester);
          await tester.enterText(_key('day-extra-amount-field'), '-9999,99');
          await tester.pump();
          final rect = tester.getRect(_key('day-extra-amount'));
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(size.width));
          expect(tester.takeException(), isNull);
          await tester.enterText(_key('day-extra-amount-field'), 'abc-');
          await tester.pump();
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}
