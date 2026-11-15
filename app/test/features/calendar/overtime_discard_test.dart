import 'package:cuadrante/features/calendar/presentation/month_screen.dart';
import 'package:cuadrante/features/calendar/presentation/overtime_sheet.dart';
import 'package:cuadrante/features/calendar/presentation/overtime_types_sheet.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

const _date = CivilDate(2026, 10, 26);
Finder _key(String key) => find.byKey(ValueKey(key));

Future<void> _back(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(_key(key));
  await tester.pumpAndSettle();
  await tester.tap(_key(key));
  await tester.pumpAndSettle();
}

void main() {
  for (final editing in [false, true]) {
    for (final typeForm in [false, true]) {
      final label = '${typeForm ? 'type' : 'block'}, editing $editing';
      Future<void> open(WidgetTester tester) async {
        await pumpCalendar(tester);
        final context = tester.element(find.byType(MonthScreen));
        if (typeForm) {
          editOvertimeType(
            context,
            type: editing ? scheduleOf(tester).overtimeTypes.first : null,
          );
        } else {
          editOvertimeBlock(
            context,
            _date,
            block: editing
                ? const OvertimeBlock(
                    id: 'original',
                    date: _date,
                    typeId: overtimeTypeId,
                    startMinute: 840,
                    endMinute: 900,
                    note: 'Original',
                  )
                : null,
          );
        }
        await tester.pumpAndSettle();
      }

      testWidgets('unchanged sheet closes without asking, $label', (
        tester,
      ) async {
        await open(tester);
        await _back(tester);
        expect(find.byType(BottomSheet), findsNothing);
        expect(find.byType(AlertDialog), findsNothing);
      });

      testWidgets('reverting text closes without asking, $label', (
        tester,
      ) async {
        await open(tester);
        final field = _key(typeForm ? 'overtime-type-name' : 'overtime-note');
        final initial = tester.widget<TextField>(field).controller!.text;
        await tester.ensureVisible(field);
        await tester.enterText(field, 'Cambio');
        await tester.pumpAndSettle();
        await tester.enterText(field, initial);
        await tester.pumpAndSettle();
        await _back(tester);
        expect(find.byType(BottomSheet), findsNothing);
        expect(find.byType(AlertDialog), findsNothing);
      });

      for (final change
          in typeForm
              ? ['name', 'color', 'mode', 'counts', 'multiplier', 'rate']
              : ['note', 'break', 'duration', 'type']) {
        testWidgets('Back protects $change; keep and discard, $label', (
          tester,
        ) async {
          await open(tester);
          final before = scheduleOf(tester);
          String? field;
          switch (change) {
            case 'name':
              field = 'overtime-type-name';
            case 'note':
              field = 'overtime-note';
            case 'break':
              field = 'overtime-break';
            case 'multiplier':
              await _tap(tester, 'overtime-mode-multiplier');
              field = 'overtime-type-multiplier';
            case 'rate':
              await _tap(tester, 'overtime-mode-fixed');
              field = 'overtime-type-rate';
            case 'duration':
              await _tap(tester, 'overtime-quick-4');
            case 'type':
              await _tap(tester, 'overtime-type-$otherWorkTypeId');
            case 'mode':
              await _tap(tester, 'overtime-mode-none');
            case 'counts':
              await _tap(tester, 'overtime-type-counts');
            case 'color':
              await _tap(tester, 'shift-color-fff06a3f');
          }
          if (field != null) {
            await tester.ensureVisible(_key(field));
            await tester.enterText(
              _key(field),
              ['break', 'multiplier', 'rate'].contains(change)
                  ? '25'
                  : 'Cambio pendiente',
            );
          }
          await tester.pumpAndSettle();
          await _back(tester);
          expect(find.text('¿Descartar los cambios?'), findsOneWidget);
          // Back on the dialog returns to the editor, with no second prompt.
          await _back(tester);
          expect(find.byType(AlertDialog), findsNothing);
          await _back(tester);
          await _tap(tester, 'confirm-cancel');
          if (field != null) {
            expect(
              tester.widget<TextField>(_key(field)).controller!.text,
              ['break', 'multiplier', 'rate'].contains(change)
                  ? '25'
                  : 'Cambio pendiente',
            );
          }
          await _back(tester);
          await _tap(tester, 'confirm-ok');
          expect(find.byType(BottomSheet), findsNothing);
          expect(scheduleOf(tester), same(before));
        });
      }
    }
  }
}
