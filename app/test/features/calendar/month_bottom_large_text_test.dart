import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/core/theme/theme_context.dart';
import 'package:cuadrante/features/calendar/presentation/month_destinations.dart';
import 'package:cuadrante/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/real_font.dart';
import 'harness.dart';

/// QA 0.9.0 F4: on the month at 390 x 844 with the system text at 200 % and
/// the phone in Basque, «Hautatu egunak» ran under the floating «Margotu» and
/// the bar of destinations lost its names. The fixed row now gives the
/// floating button its room (the select control shrinks to its icon when the
/// label does not fit), and the bar keeps its names (drawn at most at ×1.3).
void main() {
  setUpAll(initializeLocale);

  Finder key(String value) => find.byKey(ValueKey(value));

  testWidgets('390 x 844, text x2.0, Basque: no overflow, controls apart, '
      'names under the destinations', (tester) async {
    expect(await tester.runAsync(loadRoboto), isTrue);
    addTearDown(() => AppTypography.debugFamily = null);
    final l10n = lookupAppLocalizations(const Locale('eu'));
    await pumpCalendar(
      tester,
      textScale: 2.0,
      locale: const Locale('eu'),
      openCard: false,
    );
    expect(tester.takeException(), isNull);

    // «Hautatu egunak» and «Margotu» are both on screen and hit-testable,
    // side by side: the first never sits under the second.
    final select = key('month-select-days');
    final fab = find.byType(FloatingActionButton);
    expect(select, findsOneWidget);
    expect(fab, findsOneWidget);
    final selectRect = tester.getRect(select);
    final fabRect = tester.getRect(fab);
    expect(selectRect.right, lessThanOrEqualTo(fabRect.left));
    expect(selectRect.width, greaterThanOrEqualTo(47.5));
    expect(selectRect.height, greaterThanOrEqualTo(47.5));
    for (final target in [select, fab]) {
      final hit = tester
          .hitTestOnBinding(tester.getCenter(target))
          .path
          .map((entry) => entry.target);
      expect(
        hit,
        contains(tester.renderObject(target)),
        reason: 'the center of $target receives the tap',
      );
    }
    // When the label is gone its name is still the tooltip.
    if (find
        .descendant(of: select, matching: find.text(l10n.monthSelectDays))
        .evaluate()
        .isEmpty) {
      expect(find.byTooltip(l10n.monthSelectDays), findsOneWidget);
    }

    // The bar of destinations still has its four names, on one line each and
    // inside the screen.
    final bar = key('month-nav-bar');
    expect(bar, findsOneWidget);
    for (final name in [
      l10n.monthNavMonth,
      l10n.monthNavRotation,
      l10n.monthNavAgenda,
      l10n.monthNavSummary,
    ]) {
      final label = find.descendant(of: bar, matching: find.text(name));
      expect(label, findsOneWidget, reason: name);
      final rect = tester.getRect(label);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(390.5));
      expect(rect.bottom, lessThanOrEqualTo(tester.getRect(bar).bottom));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('select days opens selection at 390 x 844, text x2.0, Basque', (
    tester,
  ) async {
    await pumpCalendar(
      tester,
      textScale: 2.0,
      locale: const Locale('eu'),
      openCard: false,
    );
    await tester.tap(key('month-select-days'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  /// QA 0.9.1 N1: on a tablet in landscape at text x2.0 the rail dropped its
  /// four names while the phone bar kept them. The rail follows the same rule
  /// (names at any text size, drawn at most at x1.3, on one line).
  testWidgets('1280 x 800, text x2.0, Basque: the rail keeps its four names', (
    tester,
  ) async {
    expect(await tester.runAsync(loadRoboto), isTrue);
    addTearDown(() => AppTypography.debugFamily = null);
    final l10n = lookupAppLocalizations(const Locale('eu'));
    await pumpCalendar(
      tester,
      textScale: 2.0,
      locale: const Locale('eu'),
      size: const Size(1280, 800),
      openCard: false,
    );
    expect(tester.takeException(), isNull);

    final rail = key('month-nav-rail');
    expect(rail, findsOneWidget);
    expect(key('month-nav-bar'), findsNothing);
    final railRect = tester.getRect(rail);
    for (final name in [
      l10n.monthNavMonth,
      l10n.monthNavRotation,
      l10n.monthNavAgenda,
      l10n.monthNavSummary,
    ]) {
      final label = find.descendant(of: rail, matching: find.text(name));
      expect(label, findsOneWidget, reason: name);
      final rect = tester.getRect(label);
      expect(rect.left, greaterThanOrEqualTo(railRect.left));
      expect(rect.right, lessThanOrEqualTo(railRect.right));
      // One line: the name is drawn at most at x1.3 of the caption.
      expect(rect.height, lessThan(30), reason: name);
    }
    // The rail grows only as much as the longest name needs.
    expect(railRect.width, lessThanOrEqualTo(MonthNavigationRail.maxWidth));
    expect(tester.takeException(), isNull);
  });

  testWidgets('1280 x 800, text x1.0: the rail keeps its normal width', (
    tester,
  ) async {
    await pumpCalendar(tester, size: const Size(1280, 800), openCard: false);
    expect(tester.getSize(key('month-nav-rail')).width, 80);
    final l10n = lookupAppLocalizations(const Locale('es'));
    expect(
      find.descendant(
        of: key('month-nav-rail'),
        matching: find.text(l10n.monthNavMonth),
      ),
      findsOneWidget,
    );
  });
}
