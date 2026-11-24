import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/features/onboarding/application/onboarding_controller.dart';
import 'package:cuadrante/features/calendars/domain/calendar.dart';
import 'package:cuadrante/features/schedule/data/schedule_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/real_font.dart';
import 'onboarding_support.dart';

void main() {
  setUpAll(() async {
    await initializeLocale();
    expect(await loadRoboto(), isTrue);
  });

  for (final (preset, workDays) in [('2x2', 2), ('3x1', 3)]) {
    testWidgets('$preset: date confirmation and chosen shift, 360 dp at x2', (
      tester,
    ) async {
      final app = await FirstLaunch.open(
        tester,
        size: const Size(360, 800),
        textScale: 2,
      );
      await app.chooseRotation();
      await app.tap(key('onboarding-pattern-$preset'));
      await app.tap(key('onboarding-next'));
      expect(
        find.text(
          'Tu rotación empieza el lunes 19 de octubre y se repite desde ese día.',
        ),
        findsOneWidget,
      );

      await app.tap(key('onboarding-start-date'));
      // One tap on the day chooses it and closes the sheet.
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('date-sheet')),
          matching: find.text('20'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Tu rotación empieza el martes 20 de octubre y se repite desde ese día.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('empieza el lunes 19'), findsNothing);

      await app.tap(key('rotation-work-night'));
      final state = app.container.read(onboardingControllerProvider);
      final preview = app.container.read(onboardingPreviewProvider)!;
      for (var i = 0; i < 8; i++) {
        expect(
          idsOn(preview.schedule, state.start.addDays(i)),
          i % 4 < workDays ? 'night' : 'rest',
        );
      }
      expect(tester.takeException(), isNull);
      await app.tap(key('onboarding-next'));
      await app.flushWrites();
      final saved = await app.real(
        () => ScheduleRepository(app.database).load(mainCalendarId),
      );
      for (var i = 0; i < 8; i++) {
        expect(
          idsOn(saved.schedule, state.start.addDays(i)),
          i % 4 < workDays ? 'night' : 'rest',
        );
      }
      expect(find.textContaining('(Noche)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
