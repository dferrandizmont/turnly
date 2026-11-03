import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/core/theme/app_colors.dart';
import 'package:cuadrante/features/calendar/application/off_outlook.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

/// The «next day off» lines of the «Hoy» card (C1). Demo data of the harness,
/// around Monday 19 October 2026: 19 and 20 night, 21 morning + afternoon,
/// 22 cleared by hand (nothing annotated, with work after it), 23 night,
/// 24 rest.
void main() {
  setUpAll(initializeLocale);

  final offLine = find.byKey(const ValueKey('today-off-line'));
  final extraLine = find.byKey(const ValueKey('today-off-extra'));

  String textOf(Finder finder, WidgetTester tester) =>
      tester.widget<Text>(finder).data!;

  group('the next day off on the card', () {
    testWidgets('says when you are off, with the weekday and the day', (
      tester,
    ) async {
      await pumpCalendar(tester, clock: () => DateTime(2026, 10, 19, 12));
      expect(textOf(offLine, tester), 'Libras el jueves 22');
    });

    testWidgets('tomorrow is «Mañana libras»', (tester) async {
      await pumpCalendar(tester, clock: () => DateTime(2026, 10, 21, 12));
      expect(textOf(offLine, tester), 'Mañana libras');
    });

    testWidgets('a day off says when you go back', (tester) async {
      await pumpCalendar(tester, clock: () => DateTime(2026, 10, 22, 10));
      expect(find.text('HOY LIBRE'), findsOneWidget);
      expect(textOf(offLine, tester), 'Hoy libras; vuelves el viernes 23');
    });

    testWidgets('the streak of work shows from three days, with the rest', (
      tester,
    ) async {
      // 19, 20 and 21 worked, 22 off: three days in a row, none left.
      await pumpCalendar(tester, clock: () => DateTime(2026, 10, 21, 12));
      expect(textOf(extraLine, tester), contains('Llevas 3 días seguidos'));
    });

    testWidgets('no streak line under three days', (tester) async {
      await pumpCalendar(tester, clock: () => DateTime(2026, 10, 20, 12));
      expect(textOf(offLine, tester), 'Libras el jueves 22');
      if (extraLine.evaluate().isNotEmpty) {
        expect(textOf(extraLine, tester), isNot(contains('Llevas')));
      }
    });

    testWidgets('the whole card is read aloud with the new lines', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpCalendar(tester, clock: () => DateTime(2026, 10, 19, 12));
      final label = tester
          .getSemantics(find.byKey(const ValueKey('today-off-line')))
          .label;
      expect(label, contains('Libras el jueves 22'));
      handle.dispose();
    });

    testWidgets('nothing is shown when no day off is known', (tester) async {
      await pumpCalendar(
        tester,
        clock: () => DateTime(2026, 10, 19, 12),
        overrides: [
          offOutlookProvider.overrideWithValue(
            const OffOutlook(
              today: CivilDate(2026, 10, 19),
              todayKind: DayKind.work,
            ),
          ),
        ],
      );
      expect(offLine, findsNothing);
      expect(extraLine, findsNothing);
      expect(find.text('ESTA NOCHE'), findsOneWidget);
    });

    testWidgets('the weekend line appears next to the streak', (tester) async {
      await pumpCalendar(
        tester,
        clock: () => DateTime(2026, 10, 19, 12),
        overrides: [
          offOutlookProvider.overrideWithValue(
            const OffOutlook(
              today: CivilDate(2026, 10, 19),
              todayKind: DayKind.work,
              nextOff: NextOff(
                date: CivilDate(2026, 10, 24),
                kind: DayKind.rest,
                daysAway: 5,
                inferred: false,
              ),
              freeWeekend: FreeWeekend(
                saturday: CivilDate(2026, 10, 24),
                sunday: CivilDate(2026, 10, 25),
              ),
              workedStreak: 4,
              workDaysLeft: 4,
            ),
          ),
        ],
      );
      expect(textOf(offLine, tester), 'Libras el sábado 24');
      expect(
        textOf(extraLine, tester),
        'Fin de semana libre: 24–25 oct  ·  Llevas 4 días seguidos; te quedan 4',
      );
    });

    for (final brightness in Brightness.values) {
      testWidgets('fits a narrow screen with large text, $brightness', (
        tester,
      ) async {
        await pumpCalendar(
          tester,
          textScale: 1.6,
          brightness: brightness,
          size: const Size(320, 640),
          clock: () => DateTime(2026, 10, 21, 12),
        );
        expect(tester.takeException(), isNull);
        expect(offLine, findsOneWidget);
      });
    }

    testWidgets('uses the quiet text colours of the design, light and dark', (
      tester,
    ) async {
      await pumpCalendar(tester, clock: () => DateTime(2026, 10, 21, 12));
      expect(
        tester.widget<Text>(offLine).style!.color,
        AppColors.light.textSecondary,
      );
      expect(
        tester.widget<Text>(extraLine).style!.color,
        AppColors.light.textMuted,
      );
      await pumpCalendar(
        tester,
        brightness: Brightness.dark,
        clock: () => DateTime(2026, 10, 21, 12),
      );
      expect(
        tester.widget<Text>(offLine).style!.color,
        AppColors.dark.textSecondary,
      );
    });
  });
}
