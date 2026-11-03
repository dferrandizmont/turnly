import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/core/theme/theme_context.dart';
import 'package:cuadrante/features/calendar/application/visible_month.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';
import '../../support/real_font.dart';

/// The controls of the month row (B1: the small Grid/List switch, "Hoy" and
/// the two arrows; the year opens from the title and the summary from the bar
/// of destinations) have to fit in a narrow phone with a big text, in every
/// language: the English "Today" is the longest one.
///
/// They are laid out in one row when they fit and in more rows when they do
/// not, and none of them loses its touch target.
void main() {
  setUpAll(initializeLocale);

  const languages = ['es', 'ca', 'gl', 'eu', 'en'];

  for (final language in languages) {
    final l10n = lookupAppLocalizations(Locale(language));

    for (final scale in [1.3, 2.0]) {
      testWidgets(
        '$language at 320 dp, text $scale: the controls of the month fit',
        (tester) async {
          await pumpCalendar(
            tester,
            size: const Size(320, 640),
            textScale: scale,
            locale: Locale(language),
          );

          // The controls of the month row.
          Finder year() => find.byKey(const ValueKey('month-title'));
          Finder grid() =>
              find.byKey(const ValueKey('month-presentation-grid'));
          Finder list() =>
              find.byKey(const ValueKey('month-presentation-list'));
          Finder today() => find.widgetWithText(TextButton, l10n.calendarToday);
          Finder previous() => find.byTooltip(l10n.calendarPreviousMonth);
          Finder next() => find.byTooltip(l10n.calendarNextMonth);

          /// Every control is on screen, with its touch target. Grid/List can
          /// sit on its own fixed line above the month with text from ×1.6
          /// (B1), centred: there it only has to be inside the screen.
          void expectControlsFit(List<Finder> controls) {
            for (final control in [grid(), list()]) {
              expect(control, findsOneWidget);
              final rect = tester.getRect(control);
              expect(rect.left, greaterThanOrEqualTo(0));
              expect(rect.right, lessThanOrEqualTo(320.5));
              expect(rect.height, greaterThanOrEqualTo(Sp.touch - 0.5));
            }
            for (final control in controls) {
              expect(control, findsOneWidget);
              final rect = tester.getRect(control);
              expect(
                rect.left,
                greaterThanOrEqualTo(Sp.l - 0.5),
                reason: 'the control is inside the page margin',
              );
              expect(
                rect.right,
                lessThanOrEqualTo(320 - Sp.xs + 0.5),
                reason: 'the control is inside the page margin',
              );
              expect(
                rect.height,
                greaterThanOrEqualTo(Sp.touch - 0.5),
                reason: 'the control keeps its touch target',
              );
            }
            expect(tester.takeException(), isNull);
          }

          // The row of the month can start below the «Hoy» card.
          await revealOnMonth(tester, year());
          // The current month: there is no "Hoy" button yet.
          expect(today(), findsNothing);
          expectControlsFit([year(), previous(), next()]);

          // Another month: the "Hoy" button appears.
          await tester.ensureVisible(next());
          await tester.pumpAndSettle();
          await tester.tap(next());
          await tester.pumpAndSettle();
          expect(today(), findsOneWidget);
          expectControlsFit([year(), today(), previous(), next()]);

          // Another year: the title says the month and the year.
          containerOf(tester)
              .read(visibleMonthProvider.notifier)
              .goTo(const CivilDate(2025, 12, 1));
          await tester.pumpAndSettle();
          expectControlsFit([year(), today(), previous(), next()]);
        },
      );
    }
  }
  testWidgets(
    'English Roboto: 48 dp targets, no overlap, two rows when needed',
    (tester) async {
      expect(await tester.runAsync(loadRoboto), isTrue);
      final l10n = lookupAppLocalizations(const Locale('en'));
      await pumpCalendar(
        tester,
        size: const Size(320, 640),
        textScale: 2,
        locale: const Locale('en'),
      );
      containerOf(tester)
          .read(visibleMonthProvider.notifier)
          .goTo(const CivilDate(2025, 12, 1));
      await tester.pumpAndSettle();
      await revealOnMonth(tester, find.byKey(const ValueKey('month-title')));
      // Text ×2: Grid/List is fixed on its own line above the month (B1);
      // "Today" and the arrows stay in the row, on two rows under the title.
      final switches = [
        find.byKey(const ValueKey('month-presentation-grid')),
        find.byKey(const ValueKey('month-presentation-list')),
      ].map(tester.getRect).toList();
      for (final rect in switches) {
        expect(rect.width, greaterThanOrEqualTo(Sp.touch));
        expect(rect.height, greaterThanOrEqualTo(Sp.touch));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(320));
      }
      expect(switches[0].overlaps(switches[1]), isFalse);
      final controls = [
        find.widgetWithText(TextButton, l10n.calendarToday),
        find.byTooltip(l10n.calendarPreviousMonth),
        find.byTooltip(l10n.calendarNextMonth),
      ];
      final rects = controls.map(tester.getRect).toList();
      for (var i = 0; i < rects.length; i++) {
        final rect = rects[i];
        expect(rect.width, greaterThanOrEqualTo(Sp.touch));
        expect(rect.height, greaterThanOrEqualTo(Sp.touch));
        expect(rect.left, greaterThanOrEqualTo(Sp.l));
        expect(rect.right, lessThanOrEqualTo(320 - Sp.xs));
        for (final other in rects.skip(i + 1)) {
          expect(rect.overlaps(other), isFalse);
        }
      }
      final title = tester.getRect(find.byKey(const ValueKey('month-title')));
      for (final rect in rects) {
        expect(rect.top, greaterThanOrEqualTo(title.top - 0.5));
      }
      expect(tester.takeException(), isNull);
    },
  );
}
