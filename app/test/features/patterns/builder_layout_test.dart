import 'dart:math' as math;

import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/core/theme/spacing.dart';
import 'package:cuadrante/features/patterns/domain/pattern_catalog.dart';
import 'package:cuadrante/features/patterns/presentation/mini_month.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/real_font.dart';
import '../calendar/harness.dart';

// QA 0.11.0 (F6, F7, F8, F10, F12) and 0.11.3 (C1, C2): layout of the rotation
// wizard and of «Crear el mío» on a phone in either orientation, a tablet and
// large text. Nothing may sit under the bottom bar, a week of the cycle stays
// a row, and the list does not move under the finger.

Finder _key(String key) => find.byKey(ValueKey(key));

Future<void> _open(
  WidgetTester tester, {
  required Size size,
  required double scale,
}) async {
  await pumpCalendar(tester, size: size, textScale: scale);
  await enterPaintMode(tester);
  await tester.tap(_key('paint-pattern'));
  await tester.pumpAndSettle();
  expect(find.text('Aplicar patrón'), findsOneWidget);
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(_key(key));
  await tester.pumpAndSettle();
  await tester.tap(_key(key));
  await tester.pumpAndSettle();
}

/// The vertical scroll of the step that is showing.
ScrollableState _pageScroll(WidgetTester tester, String step) =>
    tester.state<ScrollableState>(
      find
          .descendant(
            of: _key('pattern-step-$step'),
            matching: find.byType(Scrollable),
          )
          .first,
    );

void _toEnd(WidgetTester tester, ScrollableState scroll) =>
    scroll.position.jumpTo(scroll.position.maxScrollExtent);

/// The room between the top bar and the buttons, in dp.
double _viewportHeight(WidgetTester tester, String step) =>
    tester.getRect(_key('pattern-step-$step')).height;

const _phones = [Size(412, 915), Size(915, 412), Size(844, 390)];
const _tablets = [Size(1280, 800), Size(800, 1280)];

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeLocale();
    expect(await loadRoboto(), isTrue, reason: 'Roboto from the Flutter SDK');
  });

  group('F6: the strip of the cycle at large text', () {
    for (final (size, scale) in [
      (const Size(412, 915), 1.5),
      (const Size(412, 915), 2.0),
      (const Size(320, 640), 2.0),
      (const Size(844, 390), 2.0),
    ]) {
      testWidgets('$size x$scale: a week stays a row and no cell is cut', (
        tester,
      ) async {
        await _open(tester, size: size, scale: scale);
        await _tap(tester, 'pattern-card-correturnos');
        await _tap(tester, 'pattern-next');

        // The seven days of the first week share one row: the strip scrolls
        // sideways instead of wrapping to four columns.
        await tester.ensureVisible(_key('offset-0'));
        await tester.pumpAndSettle();
        final tops = {
          for (var i = 0; i < 7; i++) tester.getRect(_key('offset-$i')).top,
        };
        expect(tops, hasLength(1), reason: 'one row per week');
        expect(
          tester.getRect(_key('offset-0')).width,
          greaterThanOrEqualTo(48),
          reason: 'a target stays touch-sized',
        );

        // Both ends can be brought completely inside the strip's window.
        final window = find.ancestor(
          of: _key('offset-0'),
          matching: find.byWidgetPredicate(
            (w) =>
                w is SingleChildScrollView &&
                w.scrollDirection == Axis.horizontal,
          ),
        );
        for (final i in [6, 0]) {
          await tester.ensureVisible(_key('offset-$i'));
          await tester.pumpAndSettle();
          final cell = tester.getRect(_key('offset-$i'));
          final view = tester.getRect(window);
          expect(cell.left, greaterThanOrEqualTo(view.left - 0.5));
          expect(cell.right, lessThanOrEqualTo(view.right + 0.5));
        }
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('F7: step 2 leaves the strip room on a short screen', () {
    for (final (size, scale) in [
      (const Size(844, 390), 1.0),
      (const Size(915, 412), 1.0),
      (const Size(844, 390), 1.5),
      (const Size(844, 390), 2.0),
      (const Size(915, 412), 2.0),
    ]) {
      testWidgets('$size x$scale: most of the height scrolls', (tester) async {
        await _open(tester, size: size, scale: scale);
        await _tap(tester, 'pattern-card-correturnos');
        await _tap(tester, 'pattern-next');
        expect(_key('pattern-step-title'), findsOneWidget);
        expect(
          _viewportHeight(tester, 'start'),
          greaterThanOrEqualTo(size.height * 0.55),
          reason: 'the header joins the page when the height is short',
        );
        // The strip is reachable and answers a tap.
        await _tap(tester, 'offset-3');
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a tall phone keeps the header pinned', (tester) async {
      await _open(tester, size: const Size(412, 915), scale: 1.0);
      await _tap(tester, 'pattern-card-correturnos');
      await _tap(tester, 'pattern-next');
      final before = tester.getRect(_key('pattern-step-title'));
      _toEnd(tester, _pageScroll(tester, 'start'));
      await tester.pump();
      expect(tester.getRect(_key('pattern-step-title')), before);
    });
  });

  group('F10: nothing sits under the bottom bar on step 3', () {
    for (final size in _phones) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('$size x$scale', (tester) async {
          await _open(tester, size: size, scale: scale);
          await _tap(tester, 'pattern-card-correturnos');
          await _tap(tester, 'pattern-next');
          await _tap(tester, 'pattern-next');
          expect(_key('pattern-apply'), findsOneWidget);

          // «Hasta una fecha», as soon as the step opens and before any
          // scroll: whole in the window on a short screen at normal text.
          final viewport = tester.getRect(_key('pattern-step-end'));
          if (scale == 1.0) {
            final until = tester.getRect(_key('pattern-end-until'));
            expect(until.top, greaterThanOrEqualTo(viewport.top - 0.5));
            expect(until.bottom, lessThanOrEqualTo(viewport.bottom + 0.5));
          }
          // It opens a date card, whole once it is in view.
          await _tap(tester, 'pattern-end-until');
          await tester.ensureVisible(_key('pattern-until-date'));
          await tester.pumpAndSettle();
          final date = tester.getRect(_key('pattern-until-date'));
          expect(date.top, greaterThanOrEqualTo(viewport.top - 0.5));
          expect(date.bottom, lessThanOrEqualTo(viewport.bottom + 0.5));

          // At the end, the last row of the last month of «Así quedará» is
          // whole inside the window, with air under it, above the bar.
          _toEnd(tester, _pageScroll(tester, 'end'));
          await tester.pumpAndSettle();
          final lastRow = tester.getRect(
            find
                .descendant(
                  of: find.byType(MiniMonth).last,
                  matching: find.byWidgetPredicate(
                    (w) => w is Row && w.children.length == 7,
                  ),
                )
                .last,
          );
          final bar = tester.getRect(_key('pattern-apply'));
          expect(lastRow.top, greaterThanOrEqualTo(viewport.top - 0.5));
          expect(lastRow.bottom, lessThanOrEqualTo(viewport.bottom - 8));
          expect(viewport.bottom, lessThanOrEqualTo(bar.top));
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('F12: «Semanas por turno»', () {
    for (final (size, scale) in [
      (const Size(412, 915), 1.0),
      (const Size(412, 915), 2.0),
      (const Size(915, 412), 1.0),
    ]) {
      testWidgets('$size x$scale: the cards stay put and the form opens at '
          'its top', (tester) async {
        await _open(tester, size: size, scale: scale);
        final list = _pageScroll(tester, 'choose');
        await _tap(tester, 'pattern-card-$weeksPerShiftTemplateId');
        // It opens at its top, not where the list was.
        expect(_key('weeks-shift-morning'), findsOneWidget);
        expect(_pageScroll(tester, 'choose').position.pixels, 0);
        expect(list.mounted, isTrue);

        const ids = ['morning', 'afternoon', 'night'];
        Map<String, Rect> cards() => {
          for (final id in ids)
            if (find.byKey(ValueKey('weeks-shift-$id')).evaluate().isNotEmpty)
              id: tester.getRect(_key('weeks-shift-$id')),
        };

        // Each card is brought into view first, so the tap lands on it; the
        // cards must not move when it grows its «Orden» line.
        for (final id in ['morning', 'afternoon']) {
          await tester.ensureVisible(_key('weeks-shift-$id'));
          await tester.pumpAndSettle();
          final before = cards();
          expect(before, isNotEmpty);
          await tester.tap(_key('weeks-shift-$id'));
          await tester.pumpAndSettle();
          expect(
            cards(),
            before,
            reason: 'choosing «$id» moves no card (list does not shift)',
          );
          expect(find.byKey(ValueKey('weeks-order-$id')), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('going back to the list gives it its place back', (
      tester,
    ) async {
      await _open(tester, size: const Size(412, 915), scale: 1.0);
      await tester.ensureVisible(_key('pattern-card-$weeksPerShiftTemplateId'));
      await tester.pumpAndSettle();
      final offset = _pageScroll(tester, 'choose').position.pixels;
      expect(offset, greaterThan(0));
      await tester.tap(_key('pattern-card-$weeksPerShiftTemplateId'));
      await tester.pumpAndSettle();
      await tester.tap(_key('weeks-back'));
      await tester.pumpAndSettle();
      expect(_pageScroll(tester, 'choose').position.pixels, offset);
    });
  });

  group('C1: nothing under the bar in «Crear el mío»', () {
    for (final (size, scale) in [
      (const Size(915, 412), 2.0),
      (const Size(844, 390), 2.0),
      (const Size(915, 412), 1.0),
      (const Size(412, 915), 2.0),
    ]) {
      testWidgets('$size x$scale: the last shift row ends above «Siguiente»', (
        tester,
      ) async {
        await _open(tester, size: size, scale: scale);
        await _tap(tester, 'pattern-create-own');
        await _tap(tester, 'builder-add-morning');
        final viewport = tester.getRect(_key('pattern-step-choose'));
        final bar = tester.getRect(_key('pattern-next'));
        expect(viewport.bottom, lessThanOrEqualTo(bar.top));
        final scroll = tester.state<ScrollableState>(
          find
              .descendant(
                of: _key('pattern-step-choose'),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        _toEnd(tester, scroll);
        await tester.pumpAndSettle();
        final pucks = find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith('builder-add-'),
        );
        final inPage = find
            .descendant(
              of: _key('pattern-step-choose'),
              matching: _key('builder-palette'),
            )
            .evaluate()
            .isNotEmpty;
        final rects = [
          for (final element in pucks.evaluate())
            (tester.getRect(find.byWidget(element.widget)), element.widget),
        ];
        final lowest = rects.map((r) => r.$1.bottom).reduce(math.max);
        // The last row of shifts: both edges inside what is visible above
        // «Siguiente» (the page's window, or the strip under it when the
        // palette is pinned), and it takes the tap.
        final top = inPage ? viewport.top : viewport.bottom;
        final bottom = inPage ? viewport.bottom : bar.top;
        for (final (rect, widget) in rects) {
          if (rect.bottom < lowest - 0.5) continue;
          expect(rect.top, greaterThanOrEqualTo(top - 0.5), reason: '$rect');
          expect(rect.bottom, lessThanOrEqualTo(bottom + 0.5));
          expect(rect.bottom, lessThanOrEqualTo(bar.top + 0.5));
          expect(find.byWidget(widget).hitTestable(), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('C2: the palette is never one row with an inner scroll', () {
    for (final (size, scale) in [
      (const Size(960, 600), 2.0),
      (const Size(1067, 640), 2.0),
      (const Size(1280, 800), 2.0),
      (const Size(1280, 800), 1.5),
      (const Size(1280, 800), 1.0),
      (const Size(800, 1280), 2.0),
      (const Size(915, 412), 1.0),
    ]) {
      testWidgets('$size x$scale', (tester) async {
        await _open(tester, size: size, scale: scale);
        await _tap(tester, 'pattern-create-own');
        for (final id in ['morning', 'night', 'morning']) {
          await _tap(tester, 'builder-add-$id');
        }
        final inPage = find
            .descendant(
              of: _key('pattern-step-choose'),
              matching: _key('builder-palette'),
            )
            .evaluate()
            .isNotEmpty;
        if (!inPage) {
          // Pinned: at least two rows show.
          final palette = tester.getRect(_key('builder-palette'));
          final tile = tester.getRect(_key('builder-add-morning'));
          expect(
            palette.height,
            greaterThanOrEqualTo(tile.height * 2 - 0.5),
            reason: 'pinned palette shows two rows',
          );
        }
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('F8: no dead space above the palette without blocks', () {
    for (final size in _tablets) {
      for (final scale in [1.0, 1.3]) {
        testWidgets('$size x$scale', (tester) async {
          await _open(tester, size: size, scale: scale);
          await _tap(tester, 'pattern-create-own');
          final viewport = tester.getRect(_key('pattern-step-choose'));
          final palette = tester.getRect(_key('builder-palette'));
          // Only the heading and a little air: no empty page between the
          // content and «Añadir un bloque».
          expect(
            palette.top - viewport.bottom,
            lessThan(Sp.touch),
            reason: 'the palette sits right under the content',
          );
          expect(viewport.height, lessThan(size.height * 0.6));
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('with a long sequence the palette stays at the bottom', (
      tester,
    ) async {
      await _open(tester, size: const Size(800, 1280), scale: 1.0);
      await _tap(tester, 'pattern-create-own');
      final list = tester.state<ScrollableState>(
        find
            .descendant(
              of: _key('pattern-step-choose'),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      // Two shifts in turn: each tap is a block of its own.
      for (var i = 0; i < 60 && list.position.maxScrollExtent <= 0; i++) {
        await _tap(tester, 'builder-add-${i.isEven ? 'morning' : 'night'}');
      }
      expect(list.position.maxScrollExtent, greaterThan(0));
      final palette = tester.getRect(_key('builder-palette'));
      final bar = tester.getRect(_key('pattern-next'));
      expect(bar.top - palette.bottom, lessThan(24));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a phone keeps the palette where it is: two taps at the same '
        'spot make a two-day block', (tester) async {
      await _open(tester, size: const Size(412, 915), scale: 1.0);
      await _tap(tester, 'pattern-create-own');
      final before = tester.getRect(_key('builder-add-morning'));
      await tester.tapAt(before.center);
      await tester.pumpAndSettle();
      expect(tester.getRect(_key('builder-add-morning')), before);
      await tester.tapAt(before.center);
      await tester.pumpAndSettle();
      expect(tester.getRect(_key('builder-add-morning')), before);
      expect(
        tester.widget<Text>(_key('builder-length')).data,
        contains('2'),
        reason: 'one block of two days, not two blocks of one',
      );
      expect(_key('builder-block-0'), findsOneWidget);
      expect(_key('builder-block-1'), findsNothing);
    });
  });

  group('the steps keep the route scroll controller', () {
    for (final step in ['choose', 'start', 'end']) {
      testWidgets('Page Down on «Siguiente» scrolls the $step step', (
        tester,
      ) async {
        await _open(tester, size: const Size(412, 915), scale: 2.0);
        if (step != 'choose') {
          await _tap(tester, 'pattern-card-correturnos');
          await _tap(tester, 'pattern-next');
          if (step == 'end') await _tap(tester, 'pattern-next');
        }
        final scroll = _pageScroll(tester, step);
        expect(scroll.position.maxScrollExtent, greaterThan(0));
        expect(scroll.position.pixels, 0);
        final node = Focus.of(
          tester.element(
            find
                .descendant(
                  of: _key(step == 'end' ? 'pattern-apply' : 'pattern-next'),
                  matching: find.byType(Text),
                )
                .first,
          ),
        );
        node.requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
        await tester.pumpAndSettle();
        expect(scroll.position.pixels, greaterThan(0));
      });
    }
  });
}
