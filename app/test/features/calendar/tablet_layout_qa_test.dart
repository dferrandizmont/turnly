import 'dart:math' as math;

import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/features/calendar/presentation/month_summary_strip.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/real_font.dart';
import 'harness.dart';
import 'day_sheet_finders.dart';

/// Tablet findings of the iPad QA (`qa/1.1.0/report-ipad.md`, `qa/1.2.0` and
/// `qa/1.2.1`) that are common Dart layout, so they also hold on an Android
/// tablet: iPad 1024x1366 / 1366x1024, iPad mini 744x1133 / 1133x744 and a
/// Redmi Pad 800x1280 / 1280x800, on both platforms.
const _sizes = {
  'iPad portrait': Size(1024, 1366),
  'iPad landscape': Size(1366, 1024),
  'iPad mini portrait': Size(744, 1133),
  'iPad mini landscape': Size(1133, 744),
  'Android tablet portrait': Size(800, 1280),
  'Android tablet landscape': Size(1280, 800),
};

const _platforms = [TargetPlatform.android, TargetPlatform.iOS];

Finder _key(String value) => find.byKey(ValueKey(value));

/// The part of [object] that shows: its box cut by every scroller and clip
/// above it.
Rect? _visible(RenderObject object) {
  if (object is! RenderBox || !object.attached || !object.hasSize) return null;
  var rect = object.localToGlobal(Offset.zero) & object.size;
  RenderObject? parent = object.parent;
  while (parent != null) {
    if (parent is RenderAbstractViewport || parent is RenderClipRect) {
      final box = parent as RenderBox;
      rect = rect.intersect(box.localToGlobal(Offset.zero) & box.size);
      if (rect.isEmpty) return null;
    }
    parent = parent.parent;
  }
  return rect;
}

/// The texts on screen that the floating button sits over.
List<String> _fabOverText(WidgetTester tester) {
  final fabFinder = find.byType(FloatingActionButton);
  if (fabFinder.evaluate().isEmpty) return const [];
  final fab = tester.getRect(fabFinder);
  return [
    for (final element in find.byType(RichText).evaluate())
      if (find
          .descendant(of: fabFinder, matching: find.byWidget(element.widget))
          .evaluate()
          .isEmpty)
        if (_visible(element.renderObject!)?.intersect(fab) case final over?
            when over.width > 1 && over.height > 1)
          (element.widget as RichText).text.toPlainText(),
  ];
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeLocale();
    expect(await loadRoboto(), isTrue, reason: 'Roboto from the Flutter SDK');
  });

  for (final platform in _platforms) {
    group('${platform.name}:', () {
      // iPad 1.1.0 F5, still there in 1.2.1: a destination of the rail is not
      // a screen you came to from another one, so no back chevron.
      for (final entry in _sizes.entries) {
        final size = entry.value;
        final split = size.width >= 840 || size.width > size.height;
        for (final (key, tab) in [
          ('open-rotation', 'Mis rotaciones'),
          ('open-agenda', 'Agenda'),
          ('open-summary', 'Resumen'),
        ]) {
          testWidgets(
            'F5: ${entry.key}, $tab ${split ? 'has no back button' : 'keeps it'}',
            (tester) async {
              await pumpCalendar(tester, size: size);
              // Rotación needs a rotation: the demo data has one.
              await tester.tap(_key(key));
              await tester.pumpAndSettle();
              if (split) {
                expect(_key('month-nav-rail'), findsOneWidget);
                expect(find.byType(BackButton), findsNothing);
                expect(find.byIcon(Icons.arrow_back), findsNothing);
              } else {
                expect(find.byType(BackButton), findsWidgets);
              }
              expect(tester.takeException(), isNull);
            },
            variant: TargetPlatformVariant.only(platform),
          );
        }
      }

      // iPad 1.2.0 F4 (portrait): the empty space under the month grid. The
      // rows keep the limit of `docs/diseno.md` (1.5 times the width of a
      // cell); the strip of the month follows the last row and the spare
      // height stays below the strip.
      for (final entry in _sizes.entries) {
        for (final scale in [1.0, 2.0]) {
          testWidgets(
            'F4: ${entry.key}, text $scale: rows within 1.5 and the strip '
            'right under the last one',
            (tester) async {
              await pumpCalendar(tester, size: entry.value, textScale: scale);
              final first = tester.getRect(cell(const CivilDate(2026, 9, 28)));
              // At most 1.5 times the width, unless the code and time need more
              // at the reader's text size (112 dp at 2.0).
              expect(
                first.height,
                lessThanOrEqualTo(math.max(first.width * 1.5, 112) + 0.5),
              );
              final last = tester.getRect(cell(const CivilDate(2026, 11, 8)));
              final strip = tester.getRect(find.byType(MonthSummaryStrip));
              expect(
                strip.top - last.bottom,
                inInclusiveRange(-0.5, 12),
                reason: 'the strip is not under the last row: $last / $strip',
              );
              expect(tester.takeException(), isNull);
            },
            variant: TargetPlatformVariant.only(platform),
          );
        }
      }

      // iPad 1.1.0 F4 (landscape): the floating «Pintar» sat over the end of
      // the text of the pane. Nothing that shows may be under it, at rest or
      // with a day open and its pane scrolled to the end.
      for (final entry in _sizes.entries) {
        final size = entry.value;
        if (!(size.width >= 840 || size.width > size.height)) continue;
        for (final scale in [1.0, 2.0]) {
          testWidgets(
            'F4: ${entry.key}, text $scale: «Pintar» covers no text',
            (tester) async {
              await pumpCalendar(tester, size: size, textScale: scale);
              expect(find.byType(FloatingActionButton), findsOneWidget);
              expect(_fabOverText(tester), isEmpty, reason: 'at rest');
              await tester.tap(cell(const CivilDate(2026, 10, 21)));
              await tester.pumpAndSettle();
              await tester.drag(
                _key('day-pane-scroll'),
                const Offset(0, -3000),
              );
              await tester.pumpAndSettle();
              expect(_fabOverText(tester), isEmpty, reason: 'day open');
              await openDayMore(tester);
              await tester.drag(
                _key('day-pane-scroll'),
                const Offset(0, -3000),
              );
              await tester.pumpAndSettle();
              expect(_fabOverText(tester), isEmpty, reason: 'more options');
              expect(tester.takeException(), isNull);
            },
            variant: TargetPlatformVariant.only(platform),
          );
        }
      }

      // iPad 1.1.0 F1: at a very large text the date column of «Próximos
      // días» was too narrow and «14» stacked as «1» over «4».
      for (final entry in _sizes.entries) {
        final size = entry.value;
        if (!(size.width >= 840 || size.width > size.height)) continue;
        for (final scale in [1.0, 2.0, 3.0]) {
          testWidgets(
            'F1: ${entry.key}, text $scale: «Próximos días» keeps its digits',
            (tester) async {
              await pumpCalendar(tester, size: size, textScale: scale);
              final rows = find.byWidgetPredicate(
                (w) =>
                    w.key is ValueKey<String> &&
                    (w.key! as ValueKey<String>).value.startsWith('upcoming-2'),
              );
              expect(rows, findsWidgets);
              final digits = find.descendant(
                of: rows,
                matching: find.byWidgetPredicate(
                  (w) =>
                      w is RichText &&
                      RegExp(r'^\d{1,2}$').hasMatch(w.text.toPlainText()),
                ),
              );
              expect(digits, findsWidgets);
              for (final element in digits.evaluate()) {
                final paragraph = element.renderObject! as RenderParagraph;
                expect(
                  paragraph.size.height,
                  lessThanOrEqualTo(
                    paragraph.getMaxIntrinsicHeight(double.infinity) + 0.5,
                  ),
                  reason:
                      '«${(element.widget as RichText).text.toPlainText()}»'
                      ' is split over lines',
                );
              }
              expect(tester.takeException(), isNull);
            },
            variant: TargetPlatformVariant.only(platform),
          );
        }
      }

      // At a narrow two-pane window (a 680x500 landscape phone or small
      // tablet) the app bar takes its one-column form and AppBar added its
      // own back button to the pushed route.
      testWidgets(
        'F5: 680x500, a rail destination has its title and no back button',
        (tester) async {
          final semantics = tester.ensureSemantics();
          await pumpCalendar(tester, size: const Size(680, 500));
          expect(_key('month-nav-rail'), findsOneWidget);
          for (final (key, title) in [
            ('open-agenda', 'Agenda'),
            ('open-summary', 'Resumen'),
            ('open-rotation', 'Mis rotaciones'),
          ]) {
            await tester.tap(_key(key));
            await tester.pumpAndSettle();
            expect(find.text(title).hitTestable(), findsWidgets, reason: title);
            expect(find.byType(BackButton), findsNothing, reason: title);
            expect(find.byIcon(Icons.arrow_back), findsNothing);
            expect(find.bySemanticsLabel('Atrás'), findsNothing);
            expect(find.byTooltip('Atrás'), findsNothing);
          }
          semantics.dispose();
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(platform),
      );

      // Mis rotaciones opened from Ajustes, and Resumen from the year, are not
      // rail navigation: they keep their way back to where they came from.
      testWidgets(
        'F5: opened from Ajustes or the year they keep the back button',
        (tester) async {
          await pumpCalendar(tester, size: const Size(1280, 800));

          await tester.tap(find.byTooltip('Abrir ajustes'));
          await tester.pumpAndSettle();
          final runs = _key('settings-runs');
          await tester.scrollUntilVisible(
            runs,
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.tap(runs);
          await tester.pumpAndSettle();
          expect(_key('month-nav-rail'), findsOneWidget);
          expect(find.byType(BackButton), findsOneWidget);
          // Through the rail from there it is still that stack.
          await tester.tap(_key('open-agenda'));
          await tester.pumpAndSettle();
          expect(find.byType(BackButton), findsOneWidget);
          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();
          expect(runs, findsOneWidget, reason: 'back on Ajustes');
          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();
          expect(_key('month-nav-rail'), findsOneWidget);
          expect(find.byTooltip('Abrir ajustes'), findsOneWidget);

          await tester.tap(_key('month-title'));
          await tester.pumpAndSettle();
          expect(find.text('Vista anual'), findsOneWidget);
          final open = _key('year-open-summary');
          await tester.scrollUntilVisible(
            open,
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.tap(open);
          await tester.pumpAndSettle();
          expect(_key('month-nav-rail'), findsOneWidget);
          expect(find.byType(BackButton), findsOneWidget);
          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();
          expect(find.text('Vista anual'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(platform),
      );
    });
  }
}
