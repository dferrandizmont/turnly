import 'package:cuadrante/core/l10n/l10n.dart';
import 'package:cuadrante/core/theme/app_theme.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'day_sheet_finders.dart';
import 'harness.dart';

// 0.11.2 QA (tablet): the overtime sheet kept the colours of the theme it was
// opened with when the system switched between light and dark under it.
const _oct26 = CivilDate(2026, 10, 26);

Finder _key(String key) => find.byKey(ValueKey(key));

void main() {
  // The phone opens the sheet over the month; the tablet, from the side
  // panel of the day.
  for (final (name, size) in [
    ('phone', const Size(390, 844)),
    ('tablet', const Size(1280, 800)),
  ]) {
    for (final (from, to) in [
      (Brightness.light, Brightness.dark),
      (Brightness.dark, Brightness.light),
    ]) {
      testWidgets('the overtime sheet follows the system going $from to $to '
          '($name)', (tester) async {
        await pumpCalendar(tester, brightness: from, size: size);
        await revealCell(tester, _oct26);
        await tester.tap(cell(_oct26));
        await tester.pumpAndSettle();
        await openDayMore(tester);
        await tester.ensureVisible(_key('day-add-overtime'));
        await tester.pumpAndSettle();
        await tester.tap(_key('day-add-overtime'));
        await tester.pumpAndSettle();

        final colors = {
          Brightness.light: AppTheme.light().extension<AppColors>()!,
          Brightness.dark: AppTheme.dark().extension<AppColors>()!,
        };
        Color surface() =>
            tester.element(_key('overtime-sheet')).colors.surface;
        Color? sheetBackground() => tester
            .widget<Material>(
              find
                  .descendant(
                    of: find.byType(BottomSheet).last,
                    matching: find.byType(Material),
                  )
                  .first,
            )
            .color;
        // The title is found by its text, not by its place in the tree.
        final title = tester
            .element(_key('overtime-sheet'))
            .l10n
            .overtimeSheetAdd;
        Color? titleColor() => tester
            .widget<RichText>(
              find.descendant(
                of: find.descendant(
                  of: _key('overtime-sheet'),
                  matching: find.text(title),
                ),
                matching: find.byType(RichText),
              ),
            )
            .text
            .style
            ?.color;
        expect(surface(), colors[from]!.surface);
        expect(sheetBackground(), colors[from]!.surface);
        expect(titleColor(), colors[from]!.textPrimary);

        tester.platformDispatcher.platformBrightnessTestValue = to;
        await tester.pumpAndSettle();

        expect(surface(), colors[to]!.surface);
        expect(sheetBackground(), colors[to]!.surface);
        expect(titleColor(), colors[to]!.textPrimary);
      });
    }
  }
}
