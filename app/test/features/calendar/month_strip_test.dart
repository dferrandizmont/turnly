import 'package:cuadrante/features/calendar/application/month_presentation.dart';
import 'package:cuadrante/features/calendar/application/month_strip.dart';
import 'package:cuadrante/features/calendar/application/selection_controller.dart';
import 'package:cuadrante/features/calendar/application/visible_month.dart';
import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/core/widgets/app_card.dart';
import 'package:cuadrante/core/theme/spacing.dart';
import 'package:cuadrante/features/calendar/presentation/day_cell.dart';
import 'package:cuadrante/features/calendar/presentation/month_grid.dart';
import 'package:cuadrante/features/calendar/presentation/month_screen.dart';
import 'package:cuadrante/features/calendar/presentation/month_summary_strip.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/features/summary/application/summary_providers.dart';
import 'package:cuadrante/features/summary/data/hours_goal_store.dart';
import 'package:cuadrante/features/summary/domain/hours_goal.dart';
import 'package:cuadrante/features/summary/domain/month_summary.dart';
import 'package:cuadrante/features/summary/presentation/summary_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/real_font.dart';
import '../../support/text_lines.dart';
import '../schedule/domain/fixtures.dart';
import 'harness.dart';

// The strip under the month (`month_summary_strip.dart`): shifts, hours and
// the next day off of the month on screen; it opens the summary of that
// month. Demo data around Monday 19 Oct 2026 (a correturnos since July):
// October has 160 h (see summary_goal_test.dart), today and the 20th are
// nights, the 21st Mañana + Tarde and the 22nd is empty (the next day off).

Finder _key(String key) => find.byKey(ValueKey(key));

final _strip = _key('month-strip');

/// What the strip says, whatever the lines it takes.
String _said(WidgetTester tester) => _lines(tester).join(' · ');

/// The lines of the strip, as drawn.
List<String> _lines(WidgetTester tester) => [
  for (var i = 0; _key('month-strip-line-$i').evaluate().isNotEmpty; i++)
    tester.widget<Text>(_key('month-strip-line-$i')).data!,
];

/// Lines of text the strip takes on screen.
int _textLines(WidgetTester tester) => [
  for (final element
      in find
          .descendant(of: _strip, matching: find.byType(RichText))
          .evaluate())
    if ((element.widget as RichText).text.toPlainText().length > 1)
      paragraphLines(element.renderObject! as RenderParagraph).length,
].fold(0, (sum, lines) => sum + lines);

/// The lines of the strip that break inside a word or a number.
List<String> _brokenInStrip(WidgetTester tester) => [
  for (final element
      in find
          .descendant(of: _strip, matching: find.byType(RichText))
          .evaluate())
    if (!wrapsOnlyBetweenWords(element.renderObject! as RenderParagraph))
      paragraphLines(element.renderObject! as RenderParagraph).join(' | '),
];

/// Scrolls the month until the strip is on screen (it is the last thing of
/// the month, under the grid or at the end of the list).
Future<void> _reveal(WidgetTester tester) async {
  for (var i = 0; i < 40 && _strip.evaluate().isEmpty; i++) {
    await tester.drag(_key('month-scroll'), const Offset(0, -300));
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(_strip);
  await tester.pumpAndSettle();
}

/// Whether the strip is the card (and not the bare line of a tight month).
bool _isCard(WidgetTester tester) => tester.widget(_strip) is AppCard;

/// How far the month screen scrolls.
double _scrollExtent(WidgetTester tester) => tester
    .state<ScrollableState>(
      find
          .descendant(
            of: _key('month-scroll'),
            matching: find.byType(Scrollable),
          )
          .first,
    )
    .position
    .maxScrollExtent;

/// Shifts worked in [month], as the summary counts them.
int _shifts(WidgetTester tester, CivilDate month) =>
    summarizeMonth(scheduleOf(tester), month).shiftsWorked;

/// The calendar on a tall phone with the card of today folded: the days have
/// room to spare under them, so the strip is the card with all it can say.
Future<void> _pumpRoomy(
  WidgetTester tester, {
  double textScale = 1.0,
  HoursGoal? goal,
}) async {
  await pumpCalendar(
    tester,
    size: const Size(412, 915),
    textScale: textScale,
    openCard: false,
    overrides: [
      if (goal != null)
        hoursGoalStoreProvider.overrideWithValue(_MemoryGoalStore(goal)),
    ],
  );
  containerOf(tester).read(todayCardCollapsedProvider.notifier).set(true);
  await tester.pumpAndSettle();
}

Future<void> _goTo(WidgetTester tester, CivilDate month) async {
  containerOf(tester).read(visibleMonthProvider.notifier).goTo(month);
  await tester.pumpAndSettle();
}

/// Keeps the hours goal in memory.
class _MemoryGoalStore implements HoursGoalStore {
  _MemoryGoalStore(this.goal);

  HoursGoal? goal;

  @override
  Future<HoursGoal?> load() async => goal;

  @override
  Future<CivilDate?> loadSince() async => null;

  @override
  Future<void> save(HoursGoal value) async => goal = value;

  @override
  Future<void> saveSince(CivilDate date) async {}

  @override
  Future<void> clear() async => goal = null;
}

void main() {
  // The real font: the widths decide how many facts fit in a line.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeLocale();
    expect(await loadRoboto(), isTrue, reason: 'Roboto from the Flutter SDK');
  });

  group('monthStripOff', () {
    // 6x4 from Monday 5 Jan 2026: six Mañanas and four Libres.
    final schedule = presetSchedule('6x4', const CivilDate(2026, 1, 5));
    const jan = CivilDate(2026, 1, 1);

    test('the current month: the next day off from today, with the days '
        'left', () {
      expect(
        monthStripOff(schedule, jan, const CivilDate(2026, 1, 7)),
        const MonthStripOff(date: CivilDate(2026, 1, 11), daysAway: 4),
      );
      // Today is off.
      expect(
        monthStripOff(schedule, jan, const CivilDate(2026, 1, 12)),
        const MonthStripOff(date: CivilDate(2026, 1, 12), daysAway: 0),
      );
      // Any day of the month names it.
      expect(
        monthStripOff(
          schedule,
          const CivilDate(2026, 1, 20),
          const CivilDate(2026, 1, 7),
        ),
        const MonthStripOff(date: CivilDate(2026, 1, 11), daysAway: 4),
      );
    });

    test('the next day off of the current month may fall in the next '
        'one', () {
      // A rotation from 27 Jan: Mañana until 1 Feb, Libre from the 2nd.
      final crossing = presetSchedule('6x4', const CivilDate(2026, 1, 27));
      expect(
        monthStripOff(crossing, jan, const CivilDate(2026, 1, 28)),
        const MonthStripOff(date: CivilDate(2026, 2, 2), daysAway: 5),
      );
    });

    test('a month to come: its first day off, without a count', () {
      // February starts on the 28th day of the rotation: 1 Feb is a Libre.
      expect(
        monthStripOff(
          schedule,
          const CivilDate(2026, 2, 1),
          const CivilDate(2026, 1, 7),
        ),
        const MonthStripOff(date: CivilDate(2026, 2, 1)),
      );
      expect(
        monthStripOff(
          schedule,
          const CivilDate(2026, 3, 1),
          const CivilDate(2026, 1, 7),
        ),
        const MonthStripOff(date: CivilDate(2026, 3, 2)),
      );
    });

    test('a month gone by, or one without days off, has none', () {
      expect(
        monthStripOff(
          schedule,
          const CivilDate(2025, 12, 1),
          const CivilDate(2026, 1, 7),
        ),
        isNull,
      );
      // The rotation ended in January: February knows nothing.
      final ended = presetSchedule(
        '6x4',
        const CivilDate(2026, 1, 5),
        end: const CivilDate(2026, 1, 20),
      );
      expect(
        monthStripOff(
          ended,
          const CivilDate(2026, 2, 1),
          const CivilDate(2026, 1, 7),
        ),
        isNull,
      );
      expect(
        monthStripOff(
          Schedule(shiftTypes: allTypes),
          jan,
          const CivilDate(2026, 1, 7),
        ),
        isNull,
      );
    });
  });

  group('what it says', () {
    testWidgets('shifts, hours and the next day off of the current month', (
      tester,
    ) async {
      await _pumpRoomy(tester);
      final shifts = _shifts(tester, const CivilDate(2026, 10, 1));
      expect(shifts, greaterThan(0));
      expect(
        _said(tester),
        '$shifts turnos · 160 h · Sin turno anotado: jue 22',
      );
      expect(_textLines(tester), lessThanOrEqualTo(2));
      expect(
        tester.getSemantics(_strip).label,
        'Resumen del mes: $shifts turnos, 160 h, '
        'Sin turno anotado: jue 22',
      );
    });

    testWidgets('a month to come names its first day off; a month gone by '
        'has only shifts and hours', (tester) async {
      await _pumpRoomy(tester);
      await _goTo(tester, const CivilDate(2026, 11, 1));
      final november = _shifts(tester, const CivilDate(2026, 11, 1));
      expect(_said(tester), '$november turnos · 168 h · Primer libre: dom 1');

      await _goTo(tester, const CivilDate(2026, 9, 1));
      final september = _shifts(tester, const CivilDate(2026, 9, 1));
      expect(_lines(tester), ['$september turnos · 176 h']);
      expect(_isCard(tester), isTrue);
      expect(tester.getSize(_strip).height, greaterThanOrEqualTo(Sp.touch));
      expect(
        tester.getSemantics(_strip).rect.height,
        greaterThanOrEqualTo(Sp.touch),
      );
      final rect = tester.getRect(_strip);
      await tester.tapAt(Offset(rect.center.dx, rect.bottom - 1));
      await tester.pumpAndSettle();
      expect(find.byType(SummaryScreen), findsOneWidget);
    });

    testWidgets('with an hours goal: the hours against it and what is '
        'missing', (tester) async {
      await _pumpRoomy(
        tester,
        goal: const HoursGoal(HoursGoalPeriod.month, 170),
      );
      final shifts = _shifts(tester, const CivilDate(2026, 10, 1));
      expect(
        _said(tester),
        '$shifts turnos · 160 / 170 h · Por completar: 10 h · '
        'Sin turno anotado: jue 22',
      );
      expect(_textLines(tester), lessThanOrEqualTo(2));
    });

    testWidgets('with an hours goal: what is left over, or nothing when it '
        'is met exactly; it follows the goal set in the summary', (
      tester,
    ) async {
      await _pumpRoomy(
        tester,
        goal: const HoursGoal(HoursGoalPeriod.month, 150),
      );
      expect(_said(tester), contains('turnos · 160 / 150 h · 10 h de más'));

      // The summary keeps its goal alive while it changes it.
      final container = containerOf(tester);
      final alive = container.listen(hoursGoalProvider, (_, _) {});
      addTearDown(alive.close);
      await container
          .read(hoursGoalProvider.notifier)
          .set(const HoursGoal(HoursGoalPeriod.month, 160));
      await tester.pumpAndSettle();
      expect(
        _said(tester),
        contains('turnos · 160 / 160 h · Sin turno anotado'),
      );

      await container.read(hoursGoalProvider.notifier).clear();
      await tester.pumpAndSettle();
      expect(_said(tester), contains('turnos · 160 h · Sin turno anotado'));
    });

    testWidgets('a month with nothing in it has no strip', (tester) async {
      await _pumpRoomy(tester);
      await _goTo(tester, const CivilDate(2026, 5, 1));
      expect(_strip, findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('where it is', () {
    testWidgets('under the grid, and tapping it opens the summary of the '
        'month on screen', (tester) async {
      await _pumpRoomy(tester);
      await _goTo(tester, const CivilDate(2026, 11, 1));
      expect(
        tester.getRect(_strip).top,
        greaterThanOrEqualTo(tester.getRect(find.byType(MonthGrid)).bottom),
      );
      await tester.tap(_strip);
      await tester.pumpAndSettle();
      expect(find.byType(SummaryScreen), findsOneWidget);
      expect(
        tester.widget<SummaryScreen>(find.byType(SummaryScreen)).month,
        const CivilDate(2026, 11, 1),
      );
    });

    testWidgets('not while painting or selecting days', (tester) async {
      await _pumpRoomy(tester);
      expect(find.byType(MonthSummaryStrip), findsOneWidget);
      await enterPaintMode(tester);
      expect(find.byType(MonthSummaryStrip), findsNothing);
      paintOf(tester).exit();
      await tester.pumpAndSettle();
      expect(find.byType(MonthSummaryStrip), findsOneWidget);

      containerOf(tester).read(selectionControllerProvider.notifier).enter();
      await tester.pumpAndSettle();
      expect(find.byType(MonthSummaryStrip), findsNothing);
    });

    testWidgets('at the end of the list too', (tester) async {
      await _pumpRoomy(tester);
      containerOf(tester)
          .read(monthPresentationProvider.notifier)
          .choose(MonthPresentation.list);
      await tester.pumpAndSettle();
      await _reveal(tester);
      expect(_strip, findsOneWidget);
      expect(_isCard(tester), isTrue);
      expect(_lines(tester).first, contains('160 h'));
      expect(tester.takeException(), isNull);
    });
  });

  group('it never pushes the days away', () {
    testWidgets('exact room boundaries reserve a full touch target or hide '
        'the strip', (tester) async {
      await _pumpRoomy(tester);
      final context = tester.element(find.byType(MonthScreen));
      const data = MonthStripData(shifts: 1, workedMinutes: 60);
      MonthStripLayout? layout(double room) => MonthSummaryStrip.layoutFor(
        context,
        fixedToday.firstDayOfMonth,
        data,
        390,
        room: room,
      );
      expect(layout(Sp.touch + Sp.xs - 0.01), isNull);
      final bare = layout(Sp.touch + Sp.xs)!;
      expect(bare.bare, isTrue);
      expect(bare.height, Sp.touch + Sp.xs);
      final card = layout(Sp.touch + Sp.s)!;
      expect(card.bare, isFalse);
      expect(card.height, Sp.touch + Sp.s);
    });

    testWidgets('it takes only the room the days have to spare: none (then '
        'it is the card after the days), one bare line, the card; a month '
        'that fits never scrolls because of it', (tester) async {
      // 390 x 844 with the card of today folded: the six rows fit with a
      // few dp to spare (month_fit_test.dart). Every 2 dp more of screen is
      // 2 dp more of room under the days, catching the narrow bare-line range.
      await pumpCalendar(tester, size: const Size(390, 844), openCard: false);
      containerOf(tester).read(todayCardCollapsedProvider.notifier).set(true);
      await tester.pumpAndSettle();

      final seen = <String>[];
      for (var height = 844.0; height <= 940; height += 2) {
        tester.view.physicalSize = Size(390, height) * 3;
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final String form;
        if (_scrollExtent(tester) > 0.5) {
          // Not even the bare line fits under the days (QA 0.12.1, N6): the
          // strip is still there, as the card after them, and the month
          // scrolls to it.
          await _reveal(tester);
          expect(_strip, findsOneWidget, reason: 'the strip at $height dp');
          expect(_isCard(tester), isTrue);
          expect(
            tester.getRect(_strip).top,
            greaterThanOrEqualTo(
              tester.getRect(find.byType(MonthGrid)).bottom - 0.01,
            ),
          );
          form = 'scrolls';
          tester
              .state<ScrollableState>(
                find
                    .descendant(
                      of: _key('month-scroll'),
                      matching: find.byType(Scrollable),
                    )
                    .first,
              )
              .position
              .jumpTo(0);
          await tester.pumpAndSettle();
        } else {
          // The month fits and never scrolls because of the strip.
          expect(_strip, findsOneWidget, reason: 'the strip at $height dp');
          // Whole and under the days, above the fixed row.
          final viewport = tester.getRect(_key('month-scroll'));
          final strip = tester.getRect(_strip);
          expect(strip.height, greaterThanOrEqualTo(Sp.touch));
          expect(
            tester.getSemantics(_strip).rect.height,
            greaterThanOrEqualTo(Sp.touch),
          );
          expect(strip.bottom, lessThanOrEqualTo(viewport.bottom + 0.01));
          expect(
            strip.top,
            greaterThanOrEqualTo(
              tester.getRect(find.byType(MonthGrid)).bottom - 0.01,
            ),
          );
          form = _isCard(tester) ? 'card ${_textLines(tester)}' : 'bare';
          if (form == 'bare') expect(_textLines(tester), 1);
        }
        if (seen.isEmpty || seen.last != form) seen.add(form);
        // The rows keep their height whatever the strip does.
        final context = tester.element(find.byType(MonthScreen));
        expect(
          tester.getSize(cell(const CivilDate(2026, 10, 15))).height,
          greaterThanOrEqualTo(dayCellHeightWithTime(context) - 0.01),
        );
      }
      // More room, never a smaller strip; the bare line comes before the
      // card, and where there is no room for it the card is after the days.
      const order = ['scrolls', 'bare', 'card 1', 'card 2'];
      final ranks = [for (final form in seen) order.indexOf(form)];
      expect(ranks, [...ranks]..sort(), reason: '$seen');
      expect(seen, containsAllInOrder(['scrolls', 'bare', 'card 1']));
    });

    testWidgets('the bare line still opens the summary and reads the same', (
      tester,
    ) async {
      await pumpCalendar(tester, size: const Size(390, 844), openCard: false);
      containerOf(tester).read(todayCardCollapsedProvider.notifier).set(true);
      await tester.pumpAndSettle();
      var height = 844.0;
      while (height < 940 && (_strip.evaluate().isEmpty || _isCard(tester))) {
        height += 2;
        tester.view.physicalSize = Size(390, height) * 3;
        await tester.pumpAndSettle();
      }
      expect(_strip, findsOneWidget);
      expect(_isCard(tester), isFalse);
      expect(tester.getSize(_strip).height, greaterThanOrEqualTo(Sp.touch));
      expect(
        tester.getSemantics(_strip).rect.height,
        greaterThanOrEqualTo(Sp.touch),
      );
      expect(
        tester.getSemantics(_strip).label,
        startsWith('Resumen del mes: '),
      );
      // The extra height is interactive too, at the bottom edge.
      final rect = tester.getRect(_strip);
      await tester.tapAt(Offset(rect.center.dx, rect.bottom - 1));
      await tester.pumpAndSettle();
      expect(find.byType(SummaryScreen), findsOneWidget);
    });
  });

  group('layout', () {
    for (final size in const [Size(360, 740), Size(412, 915)]) {
      for (final scale in const [1.0, 1.3, 2.0]) {
        for (final brightness in Brightness.values) {
          final name =
              '${size.width.toInt()} dp, text x$scale, ${brightness.name}';

          testWidgets('at most two lines, no overflow, no broken word and '
              'the grid keeps its rows: $name', (tester) async {
            await pumpCalendar(
              tester,
              size: size,
              textScale: scale,
              brightness: brightness,
              openCard: false,
              overrides: [
                hoursGoalStoreProvider.overrideWithValue(
                  _MemoryGoalStore(const HoursGoal(HoursGoalPeriod.month, 170)),
                ),
              ],
            );
            containerOf(tester)
                .read(todayCardCollapsedProvider.notifier)
                .set(true);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);

            // The grid is not squeezed to make room: every row keeps the
            // height its code and hours need at this text size.
            final context = tester.element(find.byType(MonthScreen));
            final minCell = dayCellHeightWithTime(context);
            for (final day in const [
              CivilDate(2026, 10, 1),
              CivilDate(2026, 10, 15),
              CivilDate(2026, 10, 31),
            ]) {
              await revealCell(tester, day);
              expect(
                tester.getSize(cell(day)).height,
                greaterThanOrEqualTo(minCell - 0.01),
                reason: 'row of $day',
              );
            }

            // With the days at their minimum and still not fitting, the
            // month scrolls and the strip comes after them. Only a month
            // that fits with nothing to spare does without the strip.
            if (_scrollExtent(tester) > 0.5) await _reveal(tester);
            if (_strip.evaluate().isEmpty) {
              expect(_scrollExtent(tester), lessThan(0.5));
              return;
            }
            expect(tester.takeException(), isNull);
            expect(_textLines(tester), inInclusiveRange(1, 2));
            expect(_lines(tester).join(' '), contains('160'));
            expect(_brokenInStrip(tester), isEmpty);
            // Under the last row of the grid, inside the screen.
            final strip = tester.getRect(_strip);
            expect(strip.height, greaterThanOrEqualTo(Sp.touch));
            expect(
              tester.getSemantics(_strip).rect.height,
              greaterThanOrEqualTo(Sp.touch),
            );
            expect(
              strip.top,
              greaterThanOrEqualTo(
                tester.getRect(find.byType(MonthGrid)).bottom - 0.01,
              ),
            );
            expect(strip.left, greaterThanOrEqualTo(0));
            expect(strip.right, lessThanOrEqualTo(size.width));
            // Every line is whole: none is cut with an ellipsis.
            for (final element
                in find
                    .descendant(of: _strip, matching: find.byType(RichText))
                    .evaluate()) {
              expect(
                (element.renderObject! as RenderParagraph).didExceedMaxLines,
                isFalse,
              );
            }
            // It only adds to the scroll of a month that already scrolled.
            final extent = _scrollExtent(tester);
            expect(extent < 0.5 || extent > strip.height, isTrue);
          });
        }
      }
    }

    testWidgets('on a narrow phone with large text it keeps to two facts', (
      tester,
    ) async {
      await pumpCalendar(
        tester,
        size: const Size(360, 740),
        textScale: 2.0,
        openCard: false,
      );
      await _reveal(tester);
      expect(_lines(tester).join(' '), isNot(contains('Sin turno anotado')));
      expect(_lines(tester).join(' '), contains('turnos'));
      expect(_lines(tester).join(' '), contains('160 h'));
      // The reader still gets the three of them.
      expect(tester.getSemantics(_strip).label, contains('Sin turno anotado'));
    });
  });
}
