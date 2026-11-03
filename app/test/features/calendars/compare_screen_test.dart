import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/core/database/app_database.dart';
import 'package:cuadrante/core/router.dart';
import 'package:cuadrante/features/calendars/data/calendars_repository.dart';
import 'package:cuadrante/features/calendars/presentation/compare_screen.dart';
import 'package:cuadrante/features/calendars/presentation/compare_table.dart';
import 'package:cuadrante/features/schedule/data/schedule_repository.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';

Finder _key(String key) => find.byKey(ValueKey(key));

/// October 2026 in the demo data: "Mi cuadrante" works on 19 days (20
/// shifts), has a day off or an absence on some and nothing annotated on
/// others (the 22nd was cleared by hand). "Pareja" (see [addSecondCalendar])
/// only has a vacation day on the 19th, unless the test fills the month with
/// [fillPartner] (rest on every day of October but the 19th). A day on which
/// nobody works is free in all of them only when every calendar annotated it
/// as off (A6): an empty day is "sin anotar".
const _oct19 = CivilDate(2026, 10, 19); // Noche | Vacaciones
const _oct21 = CivilDate(2026, 10, 21); // Mañana + Tarde | nothing
const _oct22 = CivilDate(2026, 10, 22); // cleared by hand | nothing
const _oct24 = CivilDate(2026, 10, 24); // Libre | nothing
const _oct27 = CivilDate(2026, 10, 27); // Vacaciones | nothing
const _oct31 = CivilDate(2026, 10, 31); // Saturday, free in the two

/// "Pareja" annotated as rest on every day of October 2026 but the 19th.
Future<void> fillPartner(AppDatabase db) async {
  final id = (await CalendarsRepository(db).list()).last.id;
  await ScheduleRepository(db, now: () => DateTime(2026, 10, 19, 12)).apply(
    id,
    ScheduleChange(
      patch: EntriesPatch({
        for (var d = 1; d <= 31; d++)
          if (d != 19)
            CivilDate(2026, 10, d): EntryChange(
              null,
              DayEntry(
                date: CivilDate(2026, 10, d),
                shiftTypeIds: const ['rest'],
              ),
            ),
      }),
    ),
  );
}

void main() {
  setUpAll(initializeLocale);

  Future<AppUnderTest> open(
    WidgetTester tester, {
    Future<void> Function(AppDatabase db)? prepare,
    Size size = const Size(390, 844),
    String location = AppRoutes.compare,
  }) async {
    final app = await AppUnderTest.pump(
      tester,
      size: size,
      prepare: (db) async {
        await addSecondCalendar(db);
        if (prepare != null) await prepare(db);
      },
    );
    app.container.read(routerProvider).go(location);
    await tester.pumpAndSettle();
    return app;
  }

  /// The id of the second calendar ("Pareja").
  Future<String> partnerId(AppUnderTest app) async =>
      (await app.real(() => CalendarsRepository(app.database).list())).last.id;

  String text(WidgetTester tester, String key) =>
      tester.widget<Text>(_key(key)).data!;

  /// The code inside the cell of [calendarId] on [date].
  Finder inCell(String calendarId, CivilDate date, String code) =>
      find.descendant(
        of: _key('compare-cell-$calendarId-${date.toIso()}'),
        matching: find.text(code),
      );

  group('the screen', () {
    testWidgets('opens on the calendar on screen and the next one', (
      tester,
    ) async {
      final app = await open(tester);
      expect(find.byType(CompareScreen), findsOneWidget);
      expect(find.text('Comparar calendarios'), findsWidgets);
      expect(
        find.descendant(
          of: _key('compare-calendar-main'),
          matching: find.text('Mi cuadrante'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _key('compare-calendar-${await partnerId(app)}'),
          matching: find.text('Pareja'),
        ),
        findsOneWidget,
      );
      expect(text(tester, 'compare-month'), 'Octubre 2026');
    });

    testWidgets('shows one row per calendar and one column per day', (
      tester,
    ) async {
      final app = await open(tester);
      final partner = await partnerId(app);
      // Every day of the month has its column, and every calendar its row.
      for (final date in [
        _oct19,
        _oct21,
        _oct24,
        CivilDate(2026, 10, 31),
      ]) {
        expect(_key('compare-day-${date.toIso()}'), findsOneWidget);
        expect(_key('compare-cell-main-${date.toIso()}'), findsOneWidget);
        expect(_key('compare-cell-$partner-${date.toIso()}'), findsOneWidget);
      }
      expect(_key('compare-name-main'), findsOneWidget);
      expect(_key('compare-name-$partner'), findsOneWidget);
      // The shifts of every calendar in its own cell.
      expect(inCell('main', _oct19, 'N'), findsOneWidget);
      expect(inCell(partner, _oct19, 'V'), findsOneWidget);
      expect(inCell('main', _oct21, 'M+T'), findsOneWidget);
      expect(inCell(partner, _oct21, '–'), findsOneWidget);
      expect(inCell('main', _oct24, 'L'), findsOneWidget);
    });

    testWidgets('marks the days free in all of them and counts them', (
      tester,
    ) async {
      await open(tester, prepare: fillPartner);
      // The 11 days "Mi cuadrante" does not work (the 22nd is empty, so it is
      // not a day off).
      expect(text(tester, 'compare-count'), '11 días libres en común este mes');
      // Free in all of them: a rest day and a vacation day, annotated by
      // both.
      for (final date in [_oct24, _oct27]) {
        expect(_key('compare-free-${date.toIso()}'), findsOneWidget);
      }
      // Busy in the first (a Noche, a double day) or vacation in the second
      // does not help: the first works.
      for (final date in [_oct19, _oct21]) {
        expect(_key('compare-free-${date.toIso()}'), findsNothing);
      }
      // The mark is a check, not just a colour.
      expect(
        find.descendant(
          of: _key('compare-free-${_oct24.toIso()}'),
          matching: find.byType(Icon),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a day with nothing annotated is "sin anotar", not free', (
      tester,
    ) async {
      await open(tester, prepare: fillPartner);
      // The 22nd: nobody works but "Mi cuadrante" has nothing annotated.
      expect(_key('compare-unrecorded-${_oct22.toIso()}'), findsOneWidget);
      expect(_key('compare-free-${_oct22.toIso()}'), findsNothing);
      // A mark with an icon, not just a colour.
      expect(
        find.descendant(
          of: _key('compare-unrecorded-${_oct22.toIso()}'),
          matching: find.byType(Icon),
        ),
        findsOneWidget,
      );
      // Busy days and free days carry no such mark.
      for (final date in [_oct19, _oct21, _oct24, _oct27]) {
        expect(_key('compare-unrecorded-${date.toIso()}'), findsNothing);
      }
      // The summary says how many, in plain words.
      expect(
        text(tester, 'compare-unrecorded-count'),
        '1 día sin anotar en alguno',
      );
      // And the spoken label of the day tells it.
      final handle = tester.ensureSemantics();
      expect(
        tester.getSemantics(_key('compare-day-${_oct22.toIso()}')).label,
        contains('sin anotar en alguno'),
      );
      expect(
        tester.getSemantics(_key('compare-day-${_oct24.toIso()}')).label,
        allOf(contains('libres en común'), isNot(contains('sin anotar'))),
      );
      handle.dispose();
    });

    testWidgets('the default partner is mostly empty: nothing is free', (
      tester,
    ) async {
      await open(tester);
      // "Pareja" annotated nothing but the 19th, so no day can be called
      // free in all of them, and the 11 days "Mi cuadrante" does not work
      // are not annotated in the other calendar.
      expect(
        text(tester, 'compare-count'),
        'Ningún día libre en común este mes',
      );
      expect(_key('compare-free-list'), findsNothing);
      expect(
        text(tester, 'compare-unrecorded-count'),
        '12 días sin anotar en alguno',
      );
    });

    testWidgets('lists the dates of the free days', (tester) async {
      await open(tester, prepare: fillPartner);
      final pills = find.descendant(
        of: _key('compare-free-list'),
        matching: find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith(
                'compare-free-date-',
              ),
        ),
      );
      expect(pills, findsNWidgets(11));
      expect(_key('compare-free-date-2026-10-24'), findsOneWidget);
      expect(_key('compare-free-date-2026-10-22'), findsNothing);
      expect(_key('compare-free-date-2026-10-19'), findsNothing);
      expect(find.text('sáb 24 oct'), findsOneWidget);
      expect(find.text('vie 23 oct'), findsNothing, reason: 'a Noche');
    });

    testWidgets('counts the free weekends and lists them', (tester) async {
      await open(tester, prepare: fillPartner);
      // The 3rd and the 4th, the 10th and the 11th, the 17th and the 18th and
      // the 24th and the 25th: four whole free weekends.
      expect(text(tester, 'compare-weekend-count'), '4 fines de semana libres en común este mes');
      expect(_key('compare-weekend-2026-10-03'), findsOneWidget);
      expect(_key('compare-weekend-2026-10-24'), findsOneWidget);
      expect(_key('compare-weekend-2026-10-10'), findsOneWidget);
      expect(_key('compare-weekend-2026-10-17'), findsOneWidget);
      // The 31st is a Saturday whose Sunday is in the next month: a free
      // weekend day, not a whole weekend.
      expect(_key('compare-weekend-${_oct31.toIso()}'), findsNothing);
      expect(
        text(tester, 'compare-weekend-days-count'),
        '1 día de fin de semana libre en común',
      );
      expect(_key('compare-weekend-day-${_oct31.toIso()}'), findsOneWidget);
    });

    testWidgets('without free weekends there is no weekend block', (
      tester,
    ) async {
      await open(tester);
      expect(_key('compare-weekend-count'), findsNothing);
      expect(_key('compare-weekend-list'), findsNothing);
      expect(_key('compare-weekend-days-count'), findsNothing);
    });
  });

  group('month navigation', () {
    testWidgets('the arrows change the month and the figures', (tester) async {
      await open(tester, prepare: fillPartner);
      expect(text(tester, 'compare-count'), '11 días libres en común este mes');
      await tester.tap(_key('compare-next'));
      await tester.pumpAndSettle();
      expect(text(tester, 'compare-month'), 'Noviembre 2026');
      // "Pareja" annotated nothing in November.
      expect(
        text(tester, 'compare-count'),
        'Ningún día libre en común este mes',
      );
      await tester.tap(_key('compare-previous'));
      await tester.pumpAndSettle();
      await tester.tap(_key('compare-previous'));
      await tester.pumpAndSettle();
      expect(text(tester, 'compare-month'), 'Septiembre 2026');
    });

    testWidgets('the link chooses the month and the calendars', (tester) async {
      final app = await open(tester);
      final second = await partnerId(app);
      app.container
          .read(routerProvider)
          .go('${AppRoutes.compare}?mes=2026-11&a=$second&b=main');
      await tester.pumpAndSettle();
      expect(text(tester, 'compare-month'), 'Noviembre 2026');
      expect(
        find.descendant(
          of: _key('compare-calendar-$second'),
          matching: find.text('Pareja'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _key('compare-calendar-main'),
          matching: find.text('Mi cuadrante'),
        ),
        findsOneWidget,
      );
      // A bad month falls back to the current one.
      app.container.read(routerProvider).go('${AppRoutes.compare}?mes=nope');
      await tester.pumpAndSettle();
      expect(text(tester, 'compare-month'), 'Octubre 2026');
    });
  });

  group('choosing the calendars', () {
    testWidgets('the sheet adds a third calendar to the comparison', (
      tester,
    ) async {
      late String third;
      final app = await open(
        tester,
        prepare: (db) async {
          third = (await CalendarsRepository(
            db,
          ).create(name: 'Hijo', colorValue: 0xFF1C7ED6)).id;
        },
      );
      expect(third, isNotEmpty);
      await tester.tap(_key('compare-change'));
      await tester.pumpAndSettle();
      expect(_key('compare-sheet-row-$third'), findsOneWidget);
      await tester.tap(_key('compare-sheet-row-$third'));
      await tester.pumpAndSettle();
      await tester.tap(_key('compare-sheet-done'));
      await tester.pumpAndSettle();

      // Three rows in the grid now, and the new one among them.
      expect(_key('compare-name-$third'), findsOneWidget);
      expect(_key('compare-cell-$third-2026-10-19'), findsOneWidget);
      // "Hijo" is empty: nothing is annotated in it, so no day is free in all
      // of them and the 11 days the first calendar does not work are "sin
      // anotar".
      expect(
        text(tester, 'compare-count'),
        'Ningún día libre en común este mes',
      );
      expect(
        text(tester, 'compare-unrecorded-count'),
        '12 días sin anotar en alguno',
      );
      // Nothing was switched.
      expect(app.schedule.calendarId, 'main');
    });

    testWidgets('the sheet refuses to go below two calendars', (tester) async {
      final app = await open(tester);
      final partner = await partnerId(app);
      await tester.tap(_key('compare-change'));
      await tester.pumpAndSettle();
      await tester.tap(_key('compare-sheet-row-$partner'));
      await tester.pumpAndSettle();
      expect(_key('compare-sheet-warning'), findsOneWidget);
      expect(
        find.text('Hacen falta al menos 2 calendarios para comparar.'),
        findsOneWidget,
      );
      // The comparison is still the same.
      await tester.tap(_key('compare-sheet-done'));
      await tester.pumpAndSettle();
      expect(_key('compare-name-$partner'), findsOneWidget);
      expect(_key('compare-name-main'), findsOneWidget);
    });

    testWidgets('the sheet refuses to go beyond six calendars', (tester) async {
      late List<String> extra;
      await open(
        tester,
        prepare: (db) async {
          extra = [
            for (var i = 0; i < 5; i++)
              (await CalendarsRepository(
                db,
              ).create(name: 'Extra $i', colorValue: 0xFF30A46C)).id,
          ];
        },
      );
      await tester.tap(_key('compare-change'));
      await tester.pumpAndSettle();
      for (final id in extra) {
        await tester.tap(_key('compare-sheet-row-$id'));
        await tester.pumpAndSettle();
      }
      // Six calendars: the two of the start plus the four first ones. The
      // fifth one does not fit.
      expect(
        find.text('Ya comparas 6 calendarios, el máximo.'),
        findsOneWidget,
      );
      await tester.tap(_key('compare-sheet-done'));
      await tester.pumpAndSettle();
      // Six rows in the grid.
      expect(find.byType(CompareTable), findsOneWidget);
      expect(
        find.descendant(
          of: _key('compare-table'),
          matching: find.byKey(
            const ValueKey('compare-name-main'),
            skipOffstage: false,
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the two calendars can be swapped', (tester) async {
      final app = await open(tester);
      final partner = await partnerId(app);
      expect(
        tester.getCenter(_key('compare-name-main')).dy,
        lessThan(tester.getCenter(_key('compare-name-$partner')).dy),
      );
      await tester.tap(_key('compare-swap'));
      await tester.pumpAndSettle();
      expect(
        tester.getCenter(_key('compare-name-main')).dy,
        greaterThan(tester.getCenter(_key('compare-name-$partner')).dy),
      );
      // Nothing was switched.
      expect(app.schedule.calendarId, 'main');
    });
  });

  group('with fewer than two calendars', () {
    testWidgets('says what is needed and goes to create one', (tester) async {
      final app = await AppUnderTest.pump(tester);
      app.container.read(routerProvider).go(AppRoutes.compare);
      await tester.pumpAndSettle();
      expect(_key('compare-need-two'), findsOneWidget);
      expect(find.text('Necesitas dos calendarios'), findsOneWidget);
      await tester.tap(find.text('Nuevo calendario'));
      await tester.pumpAndSettle();
      expect(_key('calendars-add'), findsOneWidget);
    });
  });

  group('the way in', () {
    testWidgets('Ajustes › Calendarios has the button only with two or more', (
      tester,
    ) async {
      final one = await AppUnderTest.pump(tester);
      await one.openCalendars();
      expect(_key('calendars-compare'), findsNothing);
    });

    testWidgets('Ajustes › Calendarios › Comparar calendarios', (tester) async {
      final app = await AppUnderTest.pump(
        tester,
        prepare: (db) async => addSecondCalendar(db),
      );
      await app.openCalendars();
      await tester.ensureVisible(_key('calendars-compare'));
      await tester.tap(_key('calendars-compare'));
      await tester.pumpAndSettle();
      expect(find.byType(CompareScreen), findsOneWidget);
    });

    testWidgets('the calendar switcher of the month has the same entry', (
      tester,
    ) async {
      await AppUnderTest.pump(
        tester,
        prepare: (db) async => addSecondCalendar(db),
      );
      await tester.tap(_key('calendar-switcher'));
      await tester.pumpAndSettle();
      expect(_key('calendar-switcher-compare'), findsOneWidget);
      await tester.tap(_key('calendar-switcher-compare'));
      await tester.pumpAndSettle();
      expect(find.byType(CompareScreen), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
    });
  });

  group('it is read-only', () {
    testWidgets('nothing is written and the calendar on screen stays', (
      tester,
    ) async {
      final app = await open(tester);
      final before = await app.real(
        () => app.database.customSelect('SELECT * FROM day_entries').get(),
      );
      await tester.tap(_key('compare-next'));
      await tester.pumpAndSettle();
      await tester.tap(_key('compare-change'));
      await tester.pumpAndSettle();
      await tester.tap(_key('compare-sheet-done'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      final after = await app.real(
        () => app.database.customSelect('SELECT * FROM day_entries').get(),
      );
      expect(after.length, before.length);
      expect(app.schedule.calendarId, 'main');
      expect(app.schedule.canUndo, isFalse);
    });
  });

  for (final (size, scale) in [
    (const Size(320, 568), 1.0),
    (const Size(320, 568), 2.0),
    (const Size(390, 844), 1.0),
    (const Size(390, 844), 2.0),
    (const Size(768, 1024), 1.0),
    (const Size(844, 390), 1.0),
  ]) {
    testWidgets('fits ${size.width.toInt()}x${size.height.toInt()} '
        'x$scale without overflow', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      await open(tester, size: size, prepare: fillPartner);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        _key('compare-summary'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
      expect(_key('compare-free-list'), findsOneWidget);
      expect(_key('compare-unrecorded'), findsOneWidget);
      expect(_key('compare-weekend-count'), findsOneWidget);
    });
  }
}
