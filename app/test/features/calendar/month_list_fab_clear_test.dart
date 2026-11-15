import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/core/theme/theme_context.dart';
import 'package:cuadrante/features/calendar/presentation/month_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/real_font.dart';
import 'harness.dart';

/// «Pintar» floats over the bottom of the month. In the List no row may end
/// up under it: not today's right after choosing the list, and none at any
/// scroll position, on small phones and with large text.
void main() {
  setUpAll(() async {
    await initializeLocale();
    expect(await loadRoboto(), isTrue);
  });

  final scrollFinder = find.byKey(const ValueKey('month-scroll'));

  Rect visible(WidgetTester tester, Finder row) =>
      tester.getRect(row).intersect(tester.getRect(scrollFinder));

  void expectClear(WidgetTester tester, String when) {
    final fab = tester.getRect(find.byType(FloatingActionButton));
    final viewport = tester.getRect(scrollFinder);
    expect(
      viewport.bottom + Sp.s,
      lessThanOrEqualTo(fab.top),
      reason: '$when: no gap between the list and Pintar',
    );
    for (final row in tester.widgetList<MonthListDay>(
      find.byType(MonthListDay),
    )) {
      final rect = visible(
        tester,
        find.byKey(ValueKey('list-day-${row.day.date.toIso()}')),
      );
      if (rect.width <= 0 || rect.height <= 0) continue;
      expect(
        rect.overlaps(fab),
        isFalse,
        reason: '$when: ${row.day.date} $rect under Pintar $fab',
      );
    }
  }

  for (final size in const [Size(360, 640), Size(320, 568), Size(390, 844)]) {
    for (final scale in const [1.0, 1.5, 2.0]) {
      for (final brightness in Brightness.values) {
        testWidgets(
          'List keeps Pintar off the rows · $size · x$scale · ${brightness.name}',
          (tester) async {
            await pumpCalendar(
              tester,
              size: size,
              textScale: scale,
              brightness: brightness,
              insets: const EdgeInsets.only(top: 24, bottom: 24),
            );
            final list = find.byKey(const ValueKey('month-presentation-list'));
            await revealOnMonth(tester, list);
            await tester.tap(list);
            await tester.pumpAndSettle();

            // Today is on screen, not under the button.
            final today = find.byWidgetPredicate(
              (w) => w is MonthListDay && w.isToday,
            );
            expect(visible(tester, today).height, greaterThan(0));
            expectClear(tester, 'after choosing the list');

            final scroll = find.byType(Scrollable).first;
            await tester.drag(scroll, const Offset(0, -4000));
            await tester.pumpAndSettle();
            expectClear(tester, 'at the end');

            await tester.drag(scroll, const Offset(0, 4000));
            await tester.pumpAndSettle();
            expectClear(tester, 'at the start');
          },
        );
      }
    }
  }
}
