import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/features/calendar/application/schedule_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

/// The bottom bar of destinations stays on Rotación, Agenda and Resumen with
/// one column (decision of 21-nov-2026): the screen opened through it has the
/// bar with its own destination selected and no back button; from Ajustes or
/// the year it keeps the back button and has no bar.
void main() {
  setUpAll(initializeLocale);

  Finder key(String value) => find.byKey(ValueKey(value));

  int selected(WidgetTester tester) =>
      tester.widget<NavigationBar>(key('month-nav-bar')).selectedIndex;

  void expectNoBack() {
    expect(find.byType(BackButton), findsNothing);
    expect(find.byIcon(Icons.arrow_back), findsNothing);
  }

  Future<void> tapDestination(WidgetTester tester, String name) async {
    await tester.tap(key(name));
    await tester.pumpAndSettle();
  }

  Future<void> systemBack(WidgetTester tester) async {
    // The system back (Android button or gesture), not a Navigator call.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.bySemanticsIdentifier('month-screen'), findsOneWidget);
    expect(selected(tester), 0);
  }

  group('one column', () {
    for (final size in const [Size(390, 844), Size(800, 1280)]) {
      testWidgets('${size.width.toInt()}x${size.height.toInt()}: Agenda, '
          'Resumen and Rotación keep the bar, without a back button', (
        tester,
      ) async {
        await pumpCalendar(tester, size: size);
        expect(selected(tester), 0);

        await tapDestination(tester, 'open-agenda');
        expect(find.bySemanticsIdentifier('agenda-screen'), findsOneWidget);
        expect(key('month-nav-bar'), findsOneWidget);
        expect(selected(tester), 2);
        expectNoBack();

        await tapDestination(tester, 'open-summary');
        expect(find.bySemanticsIdentifier('agenda-screen'), findsNothing);
        expect(find.bySemanticsIdentifier('summary-screen'), findsOneWidget);
        expect(key('month-nav-bar'), findsOneWidget);
        expect(selected(tester), 3);
        expectNoBack();

        await tapDestination(tester, 'open-rotation');
        expect(find.bySemanticsIdentifier('rotation-screen'), findsOneWidget);
        expect(find.bySemanticsIdentifier('summary-screen'), findsNothing);
        expect(selected(tester), 1);
        expectNoBack();

        // The selected destination does nothing.
        await tapDestination(tester, 'open-rotation');
        expect(find.bySemanticsIdentifier('rotation-screen'), findsOneWidget);

        // The system back goes to the month: the screens replaced each other.
        await systemBack(tester);
        expect(find.bySemanticsIdentifier('month-screen'), findsOneWidget);
        expect(find.bySemanticsIdentifier('rotation-screen'), findsNothing);
        expect(selected(tester), 0);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Mes goes back to the month from any of the three', (
      tester,
    ) async {
      await pumpCalendar(tester);
      for (final destination in ['open-agenda', 'open-summary']) {
        await tapDestination(tester, destination);
        await tapDestination(tester, 'nav-month');
        expect(find.bySemanticsIdentifier('month-screen'), findsOneWidget);
        expect(selected(tester), 0);
        // One bar, not a stack of screens each with its own.
        expect(key('month-nav-bar'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('the screens replace each other without a slide', (
      tester,
    ) async {
      await pumpCalendar(tester);
      await tapDestination(tester, 'open-agenda');
      await tester.tap(key('open-summary'));
      // A single frame later the new screen is already in place.
      await tester.pump();
      expect(find.bySemanticsIdentifier('summary-screen'), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pumpAndSettle();
    });

    testWidgets('Ajustes › Mis rotaciones keeps its back button and has no '
        'bar', (tester) async {
      await pumpCalendar(tester);
      await tester.tap(find.byTooltip('Abrir ajustes'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(key('settings-runs'));
      await tester.pumpAndSettle();
      await tester.tap(key('settings-runs'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsIdentifier('rotation-screen'), findsOneWidget);
      expect(key('month-nav-bar'), findsNothing);
      expect(find.byType(BackButton), findsWidgets);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.bySemanticsIdentifier('rotation-screen'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Rotación with no rotations opens «Mis rotaciones» and its '
        'button opens the wizard on top, without the bar', (tester) async {
      await pumpCalendar(tester);
      containerOf(tester)
          .read(scheduleControllerProvider.notifier)
          .deleteRun('run-1');
      expect(scheduleOf(tester).runs, isEmpty);
      await tester.pumpAndSettle();

      await tapDestination(tester, 'open-rotation');
      expect(find.bySemanticsIdentifier('rotation-screen'), findsOneWidget);
      expect(find.text('Sin rotaciones'), findsOneWidget);
      expect(key('month-nav-bar'), findsOneWidget);
      expect(selected(tester), 1);

      await tester.tap(find.text('Aplicar patrón'));
      await tester.pumpAndSettle();
      // The wizard is a flow: no bar, and a way back.
      expect(key('month-nav-bar'), findsNothing);
      expect(find.byType(BackButton), findsWidgets);
      await tester.tap(find.byType(BackButton).first);
      await tester.pumpAndSettle();
      expect(find.text('Sin rotaciones'), findsOneWidget);
      expect(key('month-nav-bar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the bar keeps clear of the keyboard: it is not built '
        'while the keyboard is open', (tester) async {
      await pumpCalendar(tester);
      await tapDestination(tester, 'open-agenda');
      expect(key('month-nav-bar'), findsOneWidget);

      tester.view.viewInsets = const FakeViewPadding(bottom: 300 * 3);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(key('month-nav-bar'), findsNothing);
      expect(tester.takeException(), isNull);

      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(key('month-nav-bar'), findsOneWidget);
      expect(selected(tester), 2);
    });

    testWidgets('the bar takes the system bottom inset (0 and 34 dp), the '
        'destinations stay above it and the screen does not pad for it too', (
      tester,
    ) async {
      await pumpCalendar(tester, insets: const EdgeInsets.only(top: 24));
      final height = tester.view.physicalSize.height / 3;
      Future<void> setBottomInset(double inset) async {
        final padding = FakeViewPadding(top: 24 * 3, bottom: inset * 3);
        tester.view.padding = padding;
        tester.view.viewPadding = padding;
        await tester.pumpAndSettle();
      }

      for (final destination in ['open-agenda', 'open-summary']) {
        await setBottomInset(0);
        await tapDestination(tester, destination);
        final flat = tester.getRect(key('month-nav-bar')).height;
        for (final inset in [0.0, 34.0]) {
          await setBottomInset(inset);
          final bar = tester.getRect(key('month-nav-bar'));
          expect(bar.bottom, closeTo(height, 0.5), reason: '$inset');
          // The bar is the same row plus exactly the inset...
          expect(bar.height - flat, closeTo(inset, 0.5), reason: '$inset');
          // ...and the tappable destinations sit above the reserved room.
          final row = tester.getRect(key(destination));
          expect(row.bottom, lessThanOrEqualTo(bar.bottom - inset + 0.5));
          // The screen ends where the bar starts and adds no inset of its own.
          final screen = tester.getRect(find.byType(Scaffold).last);
          expect(screen.bottom, closeTo(bar.top, 0.5), reason: '$inset');
          final media = MediaQuery.of(
            tester.element(find.byType(Scaffold).last),
          );
          expect(media.padding.bottom, 0, reason: '$inset');
        }
      }
      expect(tester.takeException(), isNull);
    });

    for (final size in const [Size(390, 844), Size(320, 640)]) {
      testWidgets('${size.width.toInt()} dp, text x2: the three screens '
          'have the bar and no overflow', (tester) async {
        await pumpCalendar(tester, size: size, textScale: 2.0);
        for (final (destination, index) in [
          ('open-agenda', 2),
          ('open-summary', 3),
          ('open-rotation', 1),
        ]) {
          await tapDestination(tester, destination);
          expect(key('month-nav-bar'), findsOneWidget, reason: destination);
          expect(selected(tester), index);
          expect(tester.getRect(key('month-nav-bar')).bottom, lessThanOrEqualTo(
            size.height + 0.5,
          ));
          expect(tester.takeException(), isNull, reason: destination);
        }
      });
    }
  });

  testWidgets('two panes: unchanged, the rail on all four and no bar', (
    tester,
  ) async {
    await pumpCalendar(tester, size: const Size(1280, 800));
    await tapDestination(tester, 'open-agenda');
    expect(key('month-nav-rail'), findsOneWidget);
    expect(key('month-nav-bar'), findsNothing);
    expectNoBack();
    expect(tester.takeException(), isNull);
  });
}
