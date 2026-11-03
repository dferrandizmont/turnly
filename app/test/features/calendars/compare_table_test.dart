import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/core/theme/app_theme.dart';
import 'package:cuadrante/features/calendars/domain/calendar.dart';
import 'package:cuadrante/features/calendars/domain/calendar_comparison.dart';
import 'package:cuadrante/features/calendars/presentation/compare_table.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Finder _key(String key) => find.byKey(ValueKey(key));

const _work = ShiftType(
  id: 'work',
  code: 'M',
  name: 'Mañana',
  colorValue: 0xFFF5A524,
  category: ShiftCategory.work,
  startMinute: 6 * 60,
  endMinute: 14 * 60,
);
const _night = ShiftType(
  id: 'night',
  code: 'N',
  name: 'Noche',
  colorValue: 0xFF4B4FD1,
  category: ShiftCategory.work,
  startMinute: 22 * 60,
  endMinute: 6 * 60,
);
const _rest = ShiftType(
  id: 'rest',
  code: 'L',
  name: 'Libre',
  colorValue: 0xFFE4E4E7,
  category: ShiftCategory.rest,
);
const _types = [_work, _night, _rest];

const _c1 = Calendar(id: 'c1', name: 'Mi cuadrante', colorValue: 1, sortOrder: 0);
const _c2 = Calendar(id: 'c2', name: 'Pareja', colorValue: 2, sortOrder: 1);
const _c3 = Calendar(id: 'c3', name: 'Hijo', colorValue: 3, sortOrder: 2);

/// A schedule made of single-day entries, every other day empty.
Schedule _days(Map<CivilDate, List<String>> days) => Schedule(
  shiftTypes: _types,
  entries: {
    for (final e in days.entries)
      e.key: DayEntry(date: e.key, shiftTypeIds: e.value),
  },
);

/// October 2026: the 3rd and the 4th are a Saturday and a Sunday, and the
/// 24th and the 25th too.
CivilDate _oct(int day) => CivilDate(2026, 10, day);

/// "Mi cuadrante" works the 19th and rests the 3rd, the 4th and the 24th.
/// "Pareja" rests the 3rd, the 4th, the 19th and the 24th. "Hijo" rests the
/// 3rd and the 4th and has nothing on the 24th.
final _a = _days({
  _oct(19): ['work'],
  _oct(3): ['rest'],
  _oct(4): ['rest'],
  _oct(24): ['rest'],
});
final _b = _days({
  _oct(3): ['rest'],
  _oct(4): ['rest'],
  _oct(19): ['rest'],
  _oct(24): ['rest'],
});
final _c = _days({_oct(3): ['rest'], _oct(4): ['rest']});

MultiComparison _comparison() => compareCalendarMonth(
  [
    (calendar: _c1, schedule: _a),
    (calendar: _c2, schedule: _b),
    (calendar: _c3, schedule: _c),
  ],
  _oct(1),
);

void main() {
  setUpAll(initializeLocale);

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    Brightness brightness = Brightness.light,
    double scale = 1,
  }) async {
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearAllTestValues();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: brightness == Brightness.dark
            ? AppTheme.dark()
            : AppTheme.light(),
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CompareTable(
            comparison: _comparison(),
            today: _oct(19),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('one row per calendar and one column per day', (tester) async {
    await pump(tester);
    // The three rows, with their names.
    expect(_key('compare-name-c1'), findsOneWidget);
    expect(_key('compare-name-c2'), findsOneWidget);
    expect(_key('compare-name-c3'), findsOneWidget);
    // Every day of the month has its column.
    for (final day in [1, 15, 19, 24, 31]) {
      expect(_key('compare-day-2026-10-${day.toString().padLeft(2, '0')}'),
          findsOneWidget);
    }
    expect(find.byKey(const ValueKey('compare-day-2026-10-31')), findsOneWidget);
  });

  testWidgets('the cell of a day carries the codes of that calendar', (
    tester,
  ) async {
    await pump(tester);
    expect(
      find.descendant(
        of: _key('compare-cell-c1-2026-10-19'),
        matching: find.text('M'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _key('compare-cell-c2-2026-10-19'),
        matching: find.text('L'),
      ),
      findsOneWidget,
    );
    // A day with nothing annotated: a dash, not an empty cell.
    expect(
      find.descendant(
        of: _key('compare-cell-c3-2026-10-24'),
        matching: find.text('–'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the days free in all of them carry the check', (tester) async {
    await pump(tester);
    // The 3rd and the 4th: the three are free.
    expect(_key('compare-free-2026-10-03'), findsOneWidget);
    expect(_key('compare-free-2026-10-04'), findsOneWidget);
    // The 24th: "Hijo" has nothing annotated, so it is not free.
    expect(_key('compare-free-2026-10-24'), findsNothing);
    expect(_key('compare-unrecorded-2026-10-24'), findsOneWidget);
    // The 19th: the first one works.
    expect(_key('compare-free-2026-10-19'), findsNothing);
    expect(_key('compare-unrecorded-2026-10-19'), findsNothing);
  });

  testWidgets('the column of the names does not scroll with the days', (
    tester,
  ) async {
    await pump(tester);
    final namesBefore = tester.getCenter(_key('compare-name-c1'));
    // The days do not fit: the grid scrolls sideways.
    await tester.drag(_key('compare-days-scroll'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    final namesAfter = tester.getCenter(_key('compare-name-c1'));
    expect(namesAfter.dx, namesBefore.dx);
    expect(namesAfter.dy, namesBefore.dy);
    // And the days moved: the 1st went out of sight and the 19th came in.
    expect(
      tester.getTopLeft(_key('compare-day-2026-10-19')).dx,
      greaterThan(tester.getTopLeft(_key('compare-day-2026-10-01')).dx),
    );
  });

  testWidgets('the reader hears the day and the calendar of every cell', (
    tester,
  ) async {
    await pump(tester);
    final handle = tester.ensureSemantics();
    // The head of the day: the date, and whether they are all off.
    expect(
      tester.getSemantics(_key('compare-day-2026-10-03')).label,
      allOf(contains('sábado 3 de octubre'), contains('libres en común')),
    );
    // The cell: the calendar and its shifts.
    expect(
      tester.getSemantics(_key('compare-cell-c1-2026-10-19')).label,
      'Mi cuadrante: Mañana',
    );
    expect(
      tester.getSemantics(_key('compare-cell-c3-2026-10-24')).label,
      'Hijo: Sin turno',
    );
    handle.dispose();
  });

  testWidgets('today has its ring', (tester) async {
    await pump(tester);
    final today = tester.widget<Container>(_key('compare-day-2026-10-19'));
    final decoration = today.decoration as BoxDecoration;
    expect(decoration.border, isNotNull);
    // The other days have no ring.
    final other = tester.widget<Container>(_key('compare-day-2026-10-20'));
    expect((other.decoration as BoxDecoration).border, isNull);
  });

  for (final (size, scale, brightness) in [
    (const Size(320, 568), 1.0, Brightness.light),
    (const Size(320, 568), 2.0, Brightness.light),
    (const Size(390, 844), 1.0, Brightness.dark),
    (const Size(768, 1024), 1.0, Brightness.light),
  ]) {
    testWidgets('fits ${size.width.toInt()}x${size.height.toInt()} '
        'x$scale in $brightness without overflow', (tester) async {
      await pump(tester, size: size, scale: scale, brightness: brightness);
      expect(tester.takeException(), isNull);
    });
  }
}
