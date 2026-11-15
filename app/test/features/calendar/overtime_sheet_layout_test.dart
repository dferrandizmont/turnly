import 'package:cuadrante/features/calendar/application/schedule_controller.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/real_font.dart';
import '../../support/text_lines.dart';
import 'day_sheet_finders.dart';
import 'harness.dart';

// The sheets of the extra hours (schema v7) at 360 and 412 dp, text x1.0,
// x1.3 and x2.0, light and dark: nothing overflows and no word is split.
const _oct26 = CivilDate(2026, 10, 26);

Finder _key(String key) => find.byKey(ValueKey(key));

Future<void> _show(WidgetTester tester, String key) async {
  await tester.ensureVisible(_key(key));
  await tester.pumpAndSettle();
  await tester.tap(_key(key));
  await tester.pumpAndSettle();
}

/// The paragraphs under [root] that split a word.
List<String> _broken(WidgetTester tester, Finder root) => [
  for (final element
      in find.descendant(of: root, matching: find.byType(RichText)).evaluate())
    if (!wrapsOnlyBetweenWords(element.renderObject! as RenderParagraph))
      paragraphLines(element.renderObject! as RenderParagraph).join(' | '),
];

/// Scrolls the open sheet to its end, checking every screenful of [root].
Future<void> _expectClean(WidgetTester tester, Finder root, String what) async {
  for (var i = 0; i < 6; i++) {
    expect(tester.takeException(), isNull, reason: what);
    expect(_broken(tester, root), isEmpty, reason: what);
    final scrollables = find.descendant(
      of: find.byType(BottomSheet).last,
      matching: find.byType(Scrollable),
    );
    if (scrollables.evaluate().isEmpty) return;
    final position = tester.state<ScrollableState>(scrollables.first).position;
    if (position.pixels >= position.maxScrollExtent) return;
    position.jumpTo(
      (position.pixels + 300).clamp(0.0, position.maxScrollExtent),
    );
    await tester.pumpAndSettle();
  }
}

void main() {
  // Ahem (the test font) is twice as wide as a real one: the layout is
  // measured with Roboto, as on a phone.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    expect(await loadRoboto(), isTrue, reason: 'Roboto from the Flutter SDK');
  });

  testWidgets('412 dp: four-hour duration stays beside the block heading', (
    tester,
  ) async {
    await pumpCalendar(tester, size: const Size(412, 800));
    containerOf(tester)
        .read(scheduleControllerProvider.notifier)
        .setOvertimeBlocks(_oct26, [
          const OvertimeBlock(
            id: 'night',
            date: _oct26,
            typeId: overtimeTypeId,
            startMinute: 22 * 60,
            endMinute: 2 * 60,
          ),
        ]);
    await tester.pumpAndSettle();
    await revealCell(tester, _oct26);
    await tester.tap(cell(_oct26));
    await tester.pumpAndSettle();
    await openDayMore(tester);
    final row = _key('day-overtime-night');
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    final title = find.descendant(of: row, matching: find.text('Horas extra'));
    final duration = _key('day-overtime-duration-night');
    expect(tester.widget<Text>(duration).data, '4 h');
    expect(tester.getTopLeft(duration).dy, tester.getTopLeft(title).dy);
    expect(
      tester.getTopLeft(duration).dx,
      greaterThan(tester.getTopRight(title).dx),
    );
    expect(_broken(tester, row), isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final width in [360.0, 412.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      for (final brightness in Brightness.values) {
        final name = '${width.toInt()} dp, x$scale, ${brightness.name}';
        testWidgets('the block sheet, $name', (tester) async {
          await pumpCalendar(
            tester,
            size: Size(width, 800),
            textScale: scale,
            brightness: brightness,
          );
          final controller = containerOf(tester)
              .read(scheduleControllerProvider.notifier);
          controller.saveOvertimeType(
            const OvertimeType(
              id: 'ot-long',
              name: 'Guardia localizada de fin de semana',
              colorValue: 0xFFE5484D,
              rateMode: OvertimeRateMode.fixed,
              hourlyRateCents: 123456,
              countsForGoal: false,
              sortOrder: 2,
            ),
          );
          controller.setOvertimeBlocks(_oct26, [
            const OvertimeBlock(
              id: 'b1',
              date: _oct26,
              typeId: 'ot-long',
              startMinute: 22 * 60,
              endMinute: 2 * 60,
              breakMinutes: 30,
              note: 'Aviso a las 23:40 por la alarma del almacén',
            ),
          ]);
          await tester.pumpAndSettle();
          await revealCell(tester, _oct26);
          await tester.tap(cell(_oct26));
          await tester.pumpAndSettle();
          await openDayMore(tester);
          await tester.ensureVisible(_key('day-extras'));
          await tester.pumpAndSettle();
          await _expectClean(tester, _key('day-extras'), 'day section, $name');
          final duration = _key('day-overtime-duration-b1');
          final schedule = find.textContaining('22:00–02:00');
          expect(
            tester.getTopLeft(duration).dy,
            lessThan(tester.getTopLeft(schedule).dy),
          );

          await _show(tester, 'day-overtime-b1');
          expect(_key('overtime-sheet'), findsOneWidget);
          await _expectClean(
            tester,
            _key('overtime-sheet'),
            'edit sheet, $name',
          );
          await tester.ensureVisible(_key('overtime-note'));
          await tester.enterText(_key('overtime-note'), 'Cambio pendiente');
          await tester.pumpAndSettle();
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(find.text('¿Descartar los cambios?'), findsOneWidget);
          expect(brokenParagraphs(tester), isEmpty);
          await tester.tap(_key('confirm-cancel'));
          await tester.pumpAndSettle();
          expect(
            tester.widget<TextField>(_key('overtime-note')).controller!.text,
            'Cambio pendiente',
          );
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          await tester.tap(_key('confirm-ok'));
          await tester.pumpAndSettle();
          expect(_key('overtime-sheet'), findsNothing);
          expect(
            scheduleOf(tester).entries[_oct26]!.overtimeBlocks.single.note,
            'Aviso a las 23:40 por la alarma del almacén',
          );
        });
      }
    }
  }

  for (final width in [360.0, 412.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      for (final brightness in Brightness.values) {
        testWidgets(
          'the types and the type form, $width dp, x$scale, ${brightness.name}',
          (tester) async {
            await pumpCalendar(
              tester,
              size: Size(width, 800),
              textScale: scale,
              brightness: brightness,
            );
            await revealCell(tester, _oct26);
            await tester.tap(cell(_oct26));
            await tester.pumpAndSettle();
            await openDayMore(tester);
            await _show(tester, 'day-add-overtime');
            await _expectClean(
              tester,
              _key('overtime-sheet'),
              'new block, x$scale',
            );
            await _show(tester, 'overtime-manage-types');
            expect(_key('overtime-types-sheet'), findsOneWidget);
            await _expectClean(
              tester,
              _key('overtime-types-sheet'),
              'types, x$scale',
            );
            await _show(tester, 'overtime-type-new');
            expect(_key('overtime-type-form'), findsOneWidget);
            await _show(tester, 'overtime-mode-multiplier');
            await _expectClean(
              tester,
              _key('overtime-type-form'),
              'type form, x$scale',
            );
            await tester.binding.handlePopRoute();
            await tester.pumpAndSettle();
            expect(find.text('¿Descartar los cambios?'), findsOneWidget);
            expect(brokenParagraphs(tester), isEmpty);
            expect(tester.takeException(), isNull);
            await tester.tap(_key('confirm-cancel'));
            await tester.pumpAndSettle();
            expect(_key('overtime-type-form'), findsOneWidget);
            await tester.binding.handlePopRoute();
            await tester.pumpAndSettle();
            await tester.tap(_key('confirm-ok'));
            await tester.pumpAndSettle();
            expect(_key('overtime-type-form'), findsNothing);
          },
        );
      }
    }
  }
}
