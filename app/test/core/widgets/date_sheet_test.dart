import 'dart:ui' show Tristate;

import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/core/format/region_defaults.dart';
import 'package:cuadrante/core/providers.dart';
import 'package:cuadrante/core/theme/app_theme.dart';
import 'package:cuadrante/core/widgets/date_sheet.dart';
import 'package:cuadrante/features/schedule/domain/civil_date.dart';
import 'package:cuadrante/features/settings/application/preferences_controller.dart';
import 'package:cuadrante/features/settings/domain/preferences.dart';
import 'package:cuadrante/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/real_font.dart';
import '../../support/text_lines.dart';

/// The sheet that asks for a day (`showDateSheet`): the month with an arrow on
/// each side, the week the calendar of the app uses, one tap to choose, and
/// the text sizes and the landscape that QA broke the Material picker with.
void main() {
  setUpAll(() async {
    await initializeLocale();
    expect(await loadRoboto(), isTrue, reason: 'Roboto from the Flutter SDK');
  });

  // 23 November 2026 is a Monday.
  final now = DateTime(2026, 11, 23, 9);

  /// The result of the last sheet closed with a choice; [_closed] says whether
  /// it was closed at all.
  CivilDate? result;
  var closed = false;

  Finder key(String k) => find.byKey(ValueKey(k));
  Finder day(CivilDate d) => key('date-sheet-day-${d.toIso()}');

  /// Opens the sheet from a button ("abrir"), the way a screen would.
  Future<void> open(
    WidgetTester tester, {
    CivilDate initial = const CivilDate(2026, 11, 23),
    CivilDate first = dateSheetFirst,
    CivilDate last = dateSheetLast,
    bool shortcuts = true,
    int weekStart = 1,
    Size size = const Size(390, 844),
    double textScale = 1,
    String language = 'es',
    bool disableAnimations = false,
  }) async {
    result = null;
    closed = false;
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    if (disableAnimations) {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
    }
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearAllTestValues();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clockProvider.overrideWithValue(() => now),
          initialPreferencesProvider.overrideWithValue(
            Preferences(weekStart: weekStart),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: Locale(language),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: FilledButton(
                  onPressed: () async {
                    final picked = await showDateSheet(
                      context,
                      initial: initial,
                      first: first,
                      last: last,
                      title: AppLocalizations.of(context).patternStartLabel,
                      hint: AppLocalizations.of(context).dateSheetStartHint,
                      shortcuts: shortcuts,
                    );
                    result = picked;
                    closed = true;
                  },
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  group('the sheet', () {
    testWidgets('has the title, the hint, the shortcuts and the full date', (
      tester,
    ) async {
      await open(tester);
      expect(find.text('Día de inicio'), findsOneWidget);
      expect(find.text('El día en que empezó tu ciclo actual'), findsOneWidget);
      expect(find.text('Hoy · 23 nov'), findsOneWidget);
      expect(find.text('Lunes pasado · 16 nov'), findsOneWidget);
      expect(find.text('Noviembre 2026'), findsOneWidget);
      expect(
        tester.widget<Text>(key('date-sheet-selected')).data,
        'Lunes, 23 de noviembre de 2026',
      );
      // An arrow on each side of the month, 48 dp, with the names of the
      // month screen.
      for (final k in ['date-sheet-previous', 'date-sheet-next']) {
        expect(tester.getSize(key(k)).width, greaterThanOrEqualTo(Sp.touch));
        expect(tester.getSize(key(k)).height, greaterThanOrEqualTo(Sp.touch));
      }
      expect(find.byTooltip('Mes anterior'), findsOneWidget);
      expect(find.byTooltip('Mes siguiente'), findsOneWidget);
      // The chosen day is bold and filled; today (the same here) has a ring.
      final text = tester.widget<Text>(
        find.descendant(
          of: day(const CivilDate(2026, 11, 23)),
          matching: find.text('23'),
        ),
      );
      expect(text.style!.fontWeight, FontWeight.w800);
    });

    testWidgets('from November to 11 October takes three taps', (tester) async {
      await open(tester);
      // The first tap was the one that opened the sheet ("abrir").
      await tester.tap(key('date-sheet-previous'));
      await tester.pumpAndSettle();
      expect(find.text('Octubre 2026'), findsOneWidget);
      await tester.tap(day(const CivilDate(2026, 10, 11)));
      await tester.pumpAndSettle();
      expect(closed, isTrue);
      expect(result, const CivilDate(2026, 10, 11));
      // The sheet is gone.
      expect(key('date-sheet'), findsNothing);
    });

    testWidgets('a swipe changes the month, to both sides', (tester) async {
      await open(tester);
      await tester.fling(
        day(const CivilDate(2026, 11, 15)),
        const Offset(-300, 0),
        1000,
      );
      await tester.pumpAndSettle();
      expect(find.text('Diciembre 2026'), findsOneWidget);
      await tester.fling(
        day(const CivilDate(2026, 12, 15)),
        const Offset(300, 0),
        1000,
      );
      await tester.pumpAndSettle();
      await tester.fling(
        day(const CivilDate(2026, 11, 15)),
        const Offset(300, 0),
        1000,
      );
      await tester.pumpAndSettle();
      expect(find.text('Octubre 2026'), findsOneWidget);
      expect(closed, isFalse);
    });

    testWidgets('the month change glides, and not with reduce motion', (
      tester,
    ) async {
      double opacity() => tester
          .widget<Opacity>(
            find
                .ancestor(
                  of: day(const CivilDate(2026, 10, 15)),
                  matching: find.byType(Opacity),
                )
                .first,
          )
          .opacity;

      await open(tester);
      await tester.tap(key('date-sheet-previous'));
      await tester.pump(const Duration(milliseconds: 40));
      expect(opacity(), lessThan(1));
      await tester.pumpAndSettle();
      expect(opacity(), 1);

      await tester.pumpWidget(const SizedBox());
      await open(tester, disableAnimations: true);
      await tester.tap(key('date-sheet-previous'));
      await tester.pump();
      expect(opacity(), 1);
    });

    testWidgets('page up and page down change the month', (tester) async {
      await open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
      await tester.pumpAndSettle();
      expect(find.text('Octubre 2026'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pumpAndSettle();
      expect(find.text('Diciembre 2026'), findsOneWidget);
    });

    testWidgets('the shortcuts choose today and last Monday', (tester) async {
      await open(tester);
      await tester.tap(find.text('Lunes pasado · 16 nov'));
      await tester.pumpAndSettle();
      expect(result, const CivilDate(2026, 11, 16));

      await tester.pumpWidget(const SizedBox());
      await open(tester, initial: const CivilDate(2026, 10, 11));
      await tester.tap(find.text('Hoy · 23 nov'));
      await tester.pumpAndSettle();
      expect(result, const CivilDate(2026, 11, 23));
    });

    testWidgets('without shortcuts there are none', (tester) async {
      await open(tester, shortcuts: false);
      expect(key('date-sheet-today'), findsNothing);
      expect(key('date-sheet-last-monday'), findsNothing);
    });

    testWidgets('going back closes it without a choice', (tester) async {
      await open(tester);
      await tester.tap(key('date-sheet-previous'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(195, 20)); // the scrim
      await tester.pumpAndSettle();
      expect(closed, isTrue);
      expect(result, isNull);
    });

    testWidgets('tapping the title shows the months, not the years', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(key('date-sheet-title'));
      await tester.pumpAndSettle();
      expect(find.text('2026'), findsOneWidget);
      for (final month in [
        'Ene',
        'Feb',
        'Mar',
        'Abr',
        'May',
        'Jun',
        'Jul',
        'Ago',
        'Sep',
        'Oct',
        'Nov',
        'Dic',
      ]) {
        expect(find.text(month), findsOneWidget, reason: month);
      }
      // The arrows now move a year.
      expect(find.byTooltip('Año anterior'), findsOneWidget);
      await tester.tap(key('date-sheet-previous'));
      await tester.pumpAndSettle();
      expect(find.text('2025'), findsOneWidget);
      await tester.tap(key('date-sheet-month-10'));
      await tester.pumpAndSettle();
      // Back to the days, in October 2025.
      expect(find.text('Octubre 2025'), findsOneWidget);
      expect(day(const CivilDate(2025, 10, 11)), findsOneWidget);
      expect(closed, isFalse);
    });

    testWidgets('the whole cell takes the tap, edges and corners included', (
      tester,
    ) async {
      for (final size in const [Size(390, 844), Size(320, 640)]) {
        await open(tester, size: size, initial: const CivilDate(2026, 10, 11));
        final cell = day(const CivilDate(2026, 10, 14));
        final rect = tester.getRect(cell);
        expect(rect.height, Sp.touch);
        // Near the top edge, the bottom edge and the sides of the cell, where
        // the 40 dp square drawn inside does not reach.
        for (final point in [
          rect.topCenter + const Offset(0, 2),
          rect.bottomCenter - const Offset(0, 2),
          rect.centerLeft + const Offset(2, 0),
          rect.centerRight - const Offset(2, 0),
        ]) {
          result = null;
          closed = false;
          await tester.tapAt(point);
          await tester.pumpAndSettle();
          expect(result, const CivilDate(2026, 10, 14), reason: '$size $point');
          await tester.tap(find.text('abrir'));
          await tester.pumpAndSettle();
        }
        // The month tiles too.
        await tester.tap(key('date-sheet-title'));
        await tester.pumpAndSettle();
        final tile = tester.getRect(key('date-sheet-month-3'));
        expect(tile.height, Sp.touch);
        await tester.tapAt(tile.topCenter + const Offset(0, 2));
        await tester.pumpAndSettle();
        expect(find.text('Marzo 2026'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('the focus starts on the chosen day', (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester, initial: const CivilDate(2026, 10, 11));
      // The labelled node of the day says it has the focus.
      final data = tester
          .getSemantics(day(const CivilDate(2026, 10, 11)))
          .getSemanticsData();
      expect(data.flagsCollection.isFocused, Tristate.isTrue);
      final other = tester
          .getSemantics(day(const CivilDate(2026, 10, 12)))
          .getSemanticsData();
      expect(other.flagsCollection.isFocused, isNot(Tristate.isTrue));
      handle.dispose();
      final focused = FocusManager.instance.primaryFocus!.context!;
      var inside = false;
      focused.visitAncestorElements((e) {
        if (e.widget.key == ValueKey('date-sheet-day-2026-10-11')) {
          inside = true;
          return false;
        }
        return true;
      });
      expect(inside, isTrue);
    });
  });

  group('the week', () {
    /// The weekdays of the header, left to right.
    List<int> header(WidgetTester tester) {
      final found = [
        for (var d = 1; d <= 7; d++)
          (tester.getCenter(key('date-sheet-weekday-$d')).dx, d),
      ]..sort((a, b) => a.$1.compareTo(b.$1));
      return [for (final e in found) e.$2];
    }

    testWidgets('starts on Monday in Spain', (tester) async {
      expect(weekStartForRegion('ES'), DateTime.monday);
      await open(tester, weekStart: weekStartForRegion('ES'));
      expect(header(tester), [1, 2, 3, 4, 5, 6, 7]);
      expect(find.text('L'), findsOneWidget);
      // 1 November 2026 is a Sunday: the last column of the first row.
      final first = tester.getCenter(day(const CivilDate(2026, 11, 1)));
      final monday = tester.getCenter(day(const CivilDate(2026, 11, 2)));
      expect(first.dx, greaterThan(monday.dx));
      expect(first.dy, lessThan(monday.dy));
    });

    testWidgets('starts on Sunday on a US place', (tester) async {
      expect(weekStartForRegion('US'), DateTime.sunday);
      await open(tester, weekStart: weekStartForRegion('US'));
      expect(header(tester), [7, 1, 2, 3, 4, 5, 6]);
      // Sunday 1 November leads the first row, over Sunday 8.
      final first = tester.getCenter(day(const CivilDate(2026, 11, 1)));
      final next = tester.getCenter(day(const CivilDate(2026, 11, 2)));
      expect(first.dy, next.dy);
      expect(first.dx, lessThan(next.dx));
      expect(tester.getCenter(day(const CivilDate(2026, 11, 8))).dx, first.dx);
    });

    testWidgets('the weekday names are said whole', (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester);
      expect(
        tester.getSemantics(key('date-sheet-weekday-3')).label,
        'miércoles',
      );
      handle.dispose();
    });
  });

  group('what is read aloud', () {
    testWidgets('every day has its whole date, today and chosen', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await open(tester, initial: const CivilDate(2026, 10, 11));
      expect(find.text('Octubre 2026'), findsOneWidget);
      expect(
        tester.getSemantics(day(const CivilDate(2026, 10, 11))).label,
        'domingo, 11 de octubre de 2026, elegido',
      );
      expect(
        tester.getSemantics(day(const CivilDate(2026, 10, 12))).label,
        'lunes, 12 de octubre de 2026',
      );
      await tester.tap(key('date-sheet-next'));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(day(const CivilDate(2026, 11, 23))).label,
        'lunes, 23 de noviembre de 2026, hoy',
      );
      handle.dispose();
    });

    testWidgets('the chosen day that is also today says both', (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester, initial: const CivilDate(2026, 11, 23));
      final node = tester.getSemantics(day(const CivilDate(2026, 11, 23)));
      expect(node.label, 'lunes, 23 de noviembre de 2026, hoy, elegido');
      handle.dispose();
    });

    testWidgets('a month change is announced', (tester) async {
      final announced = <String>[];
      tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<dynamic>(SystemChannels.accessibility, (
            message,
          ) async {
            if (message is Map) {
              final data = message['data'];
              if (data is Map && data['message'] is String) {
                announced.add(data['message'] as String);
              }
            }
            return null;
          });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler<dynamic>(
              SystemChannels.accessibility,
              null,
            ),
      );
      await open(tester);
      await tester.tap(key('date-sheet-previous'));
      await tester.pumpAndSettle();
      expect(announced, contains('Octubre 2026'));
    });
  });

  group('the limits', () {
    testWidgets('2000: no month before January 2000', (tester) async {
      await open(tester, initial: const CivilDate(2000, 1, 15));
      expect(find.text('Enero 2000'), findsOneWidget);
      final previous = tester.widget<IconButton>(key('date-sheet-previous'));
      expect(previous.onPressed, isNull);
      expect(
        tester.widget<IconButton>(key('date-sheet-next')).onPressed,
        isNotNull,
      );
      // A swipe to the previous month stays where it is.
      await tester.fling(
        day(const CivilDate(2000, 1, 15)),
        const Offset(300, 0),
        1000,
      );
      await tester.pumpAndSettle();
      expect(find.text('Enero 2000'), findsOneWidget);
      // The months of the year list has no year before either.
      await tester.tap(key('date-sheet-title'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<IconButton>(key('date-sheet-previous')).onPressed,
        isNull,
      );
    });

    testWidgets('2100: the last day is 1 January', (tester) async {
      await open(tester, initial: const CivilDate(2100, 1, 1));
      expect(find.text('Enero 2100'), findsOneWidget);
      expect(
        tester.widget<IconButton>(key('date-sheet-next')).onPressed,
        isNull,
      );
      // A day after the last one is there but cannot be chosen.
      await tester.tap(day(const CivilDate(2100, 1, 2)));
      await tester.pumpAndSettle();
      expect(closed, isFalse);
      await tester.tap(day(const CivilDate(2100, 1, 1)));
      await tester.pumpAndSettle();
      expect(result, const CivilDate(2100, 1, 1));
    });

    testWidgets('the days before [first] cannot be chosen', (tester) async {
      await open(
        tester,
        initial: const CivilDate(2026, 10, 20),
        first: const CivilDate(2026, 10, 15),
      );
      final handle = tester.ensureSemantics();
      await tester.tap(day(const CivilDate(2026, 10, 14)));
      await tester.pumpAndSettle();
      expect(closed, isFalse);
      // The month before has nothing to choose: the arrow is off.
      expect(
        tester.widget<IconButton>(key('date-sheet-previous')).onPressed,
        isNull,
      );
      // The shortcuts are outside the range (today is in November, fine) and
      // «Lunes pasado» (16 Nov) is allowed.
      await tester.tap(day(const CivilDate(2026, 10, 15)));
      await tester.pumpAndSettle();
      expect(result, const CivilDate(2026, 10, 15));
      handle.dispose();
    });

    testWidgets('a start outside the range opens on the nearest day', (
      tester,
    ) async {
      await open(
        tester,
        initial: const CivilDate(1999, 5, 5),
        first: const CivilDate(2000, 1, 1),
      );
      expect(find.text('Enero 2000'), findsOneWidget);
    });
  });

  group('large text and landscape', () {
    testWidgets('x2.0 at 320 dp: the numbers stop at x1.5 and nothing breaks', (
      tester,
    ) async {
      await open(tester, size: const Size(320, 640), textScale: 2);
      expect(tester.takeException(), isNull);
      // The numbers of the grid: x1.5. The title: x2.0.
      final number = tester.element(find.text('15').first);
      expect(MediaQuery.textScalerOf(number).scale(10), closeTo(15, 0.01));
      final title = tester.element(find.text('Noviembre 2026'));
      expect(MediaQuery.textScalerOf(title).scale(10), closeTo(20, 0.01));
      // Every day is inside the sheet and a whole cell wide.
      final sheet = tester.getRect(key('date-sheet'));
      for (final d in [1, 15, 30]) {
        final rect = tester.getRect(day(CivilDate(2026, 11, d)));
        expect(rect.left, greaterThanOrEqualTo(sheet.left - 0.5));
        expect(rect.right, lessThanOrEqualTo(sheet.right + 0.5));
      }
      // The two arrows keep their touch targets.
      expect(
        tester.getSize(key('date-sheet-next')).height,
        greaterThanOrEqualTo(Sp.touch),
      );
      // And a day can still be chosen.
      await tester.ensureVisible(day(const CivilDate(2026, 11, 9)));
      await tester.tap(day(const CivilDate(2026, 11, 9)));
      await tester.pumpAndSettle();
      expect(result, const CivilDate(2026, 11, 9));
    });

    testWidgets('Basque at x2.0: title, hint and header keep words whole', (
      tester,
    ) async {
      // The strings the app really shows in Basque.
      final eu = await AppLocalizations.delegate.load(const Locale('eu'));
      await open(
        tester,
        size: const Size(320, 640),
        textScale: 2,
        language: 'eu',
        initial: const CivilDate(2026, 9, 11),
      );
      expect(tester.takeException(), isNull);
      expect(find.text(eu.patternStartLabel), findsOneWidget);
      expect(find.text(eu.dateSheetStartHint), findsOneWidget);
      expect(find.textContaining(eu.dateSheetLastMonday), findsOneWidget);
      // Nothing in the sheet breaks inside a word.
      final broken = [
        for (final element
            in find
                .descendant(
                  of: key('date-sheet'),
                  matching: find.byType(RichText),
                )
                .evaluate())
          if (!wrapsOnlyBetweenWords(element.renderObject! as RenderParagraph))
            paragraphLines(element.renderObject! as RenderParagraph)
                .join(' | '),
      ];
      expect(broken, isEmpty);
      // The month title is whole (no ellipsis, no line limit) and inside its
      // button.
      final titleBox = tester.getRect(key('date-sheet-title'));
      final text = tester
          .widgetList<Text>(
            find.descendant(
              of: key('date-sheet-title'),
              matching: find.byType(Text),
            ),
          )
          .single;
      final textRect = tester.getRect(find.byWidget(text));
      expect(textRect.left, greaterThanOrEqualTo(titleBox.left - 0.5));
      expect(textRect.right, lessThanOrEqualTo(titleBox.right + 0.5));
      // The whole title is there (not cut with an ellipsis).
      expect(text.overflow, isNull);
      expect(text.maxLines, isNull);
    });

    testWidgets('landscape: the sheet scrolls and everything is reachable', (
      tester,
    ) async {
      await open(tester, size: const Size(844, 390), textScale: 2);
      expect(tester.takeException(), isNull);
      final scrollable = find
          .descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(Scrollable),
          )
          .first;
      final state = tester.state<ScrollableState>(scrollable);
      expect(state.position.maxScrollExtent, greaterThan(0));
      // The full date, last in the sheet, is reached by scrolling.
      await tester.ensureVisible(key('date-sheet-selected'));
      await tester.pumpAndSettle();
      final view = tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(
        tester.getRect(key('date-sheet-selected')).bottom,
        lessThanOrEqualTo(view.height + 0.5),
      );
      // And a day, after scrolling back up, is chosen as always.
      await tester.ensureVisible(key('date-sheet-previous'));
      await tester.tap(key('date-sheet-previous'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(day(const CivilDate(2026, 10, 11)));
      await tester.tap(day(const CivilDate(2026, 10, 11)));
      await tester.pumpAndSettle();
      expect(result, const CivilDate(2026, 10, 11));
    });

    testWidgets('landscape at x1.0 also fits without errors', (tester) async {
      await open(tester, size: const Size(844, 390));
      expect(tester.takeException(), isNull);
    });
  });
}
