import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/features/calendar_export/application/device_calendar_providers.dart';
import 'package:cuadrante/features/device_events/application/device_events.dart';
import 'package:cuadrante/features/device_events/application/device_events_providers.dart';
import 'package:cuadrante/features/device_events/domain/device_events_settings.dart';
import 'package:cuadrante/features/schedule/data/schedule_repository.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_device_calendar.dart';
import 'harness.dart';

/// H-T02-3: the plus of overtime / early leave used to be drawn at the bottom
/// left, over the time of the shift ("⊕15–22"). It now sits in the top row of
/// the cell, which the code and the time never enter.
///
/// P6: the same top row carries the dot of the appointments of the phone, so
/// it is checked here too, in the whole matrix of sizes, text scales and
/// themes: it never touches the code, the time or the edge of the cell.
void main() {
  setUpAll(initializeLocale);

  // 12 October is a national holiday (dot), the 13th has no mark but extras.
  const holiday = CivilDate(2026, 10, 12);
  const plain = CivilDate(2026, 10, 13);
  const widths = [320.0, 360.0, 412.0];
  const scales = [1.0, 1.3, 2.0];

  // The phone of the test: one calendar chosen, two appointments on the 12th
  // and one on the 13th (so the label says «2 citas» and «1 cita»).
  final phone = FakeDeviceCalendar();
  phone.addCalendar('Trabajo');
  phone.addSimpleEvent(
    'cal-1',
    'Dentista',
    DateTime(2026, 10, 12, 9),
    DateTime(2026, 10, 12, 10),
  );
  phone.addSimpleEvent(
    'cal-1',
    'Comida',
    DateTime(2026, 10, 12, 13),
    DateTime(2026, 10, 12, 14),
  );
  phone.addSimpleEvent(
    'cal-1',
    'Cita',
    DateTime(2026, 10, 13, 16),
    DateTime(2026, 10, 13, 17),
  );
  final deviceEvents = DeviceEvents(
    api: phone,
    loadSettings: () async =>
        const DeviceEventsSettings(calendarIds: ['cal-1']),
  );
  final deviceOverrides = [
    deviceCalendarApiProvider.overrideWithValue(phone),
    deviceEventsProvider.overrideWithValue(deviceEvents),
  ];

  Future<void> prepare(ScheduleRepository repository) => repository.apply(
    'main',
    ScheduleChange(
      patch: EntriesPatch({
        holiday: EntryChange(
          null,
          const DayEntry(
            date: holiday,
            shiftTypeIds: ['morning'],
            note: 'Nota',
            overtimeMinutes: 45,
          ),
        ),
        plain: EntryChange(
          null,
          const DayEntry(
            date: plain,
            shiftTypeIds: ['afternoon'],
            earlyLeaveMinutes: 15,
          ),
        ),
      }),
    ),
  );

  for (final brightness in Brightness.values) {
    for (final width in widths) {
      for (final scale in scales) {
        testWidgets(
          'at $width dp, text $scale, ${brightness.name}: the plus and the '
          'dot of the appointments never touch the code or the time',
          (tester) async {
            await pumpCalendar(
              tester,
              size: Size(width, 1000),
              textScale: scale,
              brightness: brightness,
              prepare: prepare,
              overrides: deviceOverrides,
            );
            await tester.scrollUntilVisible(
              cell(plain),
              200,
              scrollable: find.byType(Scrollable).first,
            );
            var timesSeen = 0;
            for (final (date, code, time) in [
              (holiday, 'M', '06–14'),
              (plain, 'T', '14–22'),
            ]) {
              final box = tester.getRect(cell(date));
              final codeFinder = find.descendant(
                of: cell(date),
                matching: find.text(code),
              );
              expect(codeFinder, findsOneWidget);
              final codeRect = tester.getRect(codeFinder);
              final timeFinder = find.descendant(
                of: cell(date),
                matching: find.text(time),
              );
              final timeVisible = timeFinder.evaluate().isNotEmpty;
              if (timeVisible) timesSeen++;

              // The plus of overtime / early leave.
              final mark = tester.getRect(
                find.byKey(ValueKey('extras-mark-${date.toIso()}')),
              );
              expect(
                mark.overlaps(codeRect),
                isFalse,
                reason: 'the plus of $date covers the code',
              );
              if (timeVisible) {
                expect(
                  mark.overlaps(tester.getRect(timeFinder)),
                  isFalse,
                  reason: 'the plus of $date covers the time',
                );
              }
              // And it stays inside its own cell.
              expect(mark.left, greaterThanOrEqualTo(box.left));
              expect(mark.right, lessThanOrEqualTo(box.right));
              expect(mark.top, greaterThanOrEqualTo(box.top));

              // The dot of the appointments of the phone (P6), in the same
              // top row: never on the code, the time or the edge of the cell.
              final deviceFinder = find.byKey(
                ValueKey('device-event-mark-${date.toIso()}'),
              );
              expect(deviceFinder, findsOneWidget);
              final device = tester.getRect(deviceFinder);
              expect(
                device.overlaps(codeRect),
                isFalse,
                reason: 'the dot of the appointments of $date covers the code',
              );
              if (timeVisible) {
                expect(
                  device.overlaps(tester.getRect(timeFinder)),
                  isFalse,
                  reason: 'the dot of the appointments of $date covers the time',
                );
              }
              expect(device.left, greaterThanOrEqualTo(box.left));
              expect(device.right, lessThanOrEqualTo(box.right));
              expect(device.top, greaterThanOrEqualTo(box.top));
            }
            // Large text drops the time, as designed; the rest keep it, so
            // the check above really compares against it.
            if (scale == 1.0 && width == 412) expect(timesSeen, 2);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets('the plus lives in the top half of the cell, by the note and '
      'the holiday dot', (tester) async {
    await pumpCalendar(tester, prepare: prepare, overrides: deviceOverrides);
    final box = tester.getRect(cell(holiday));
    final mark = tester.getRect(
      find.byKey(ValueKey('extras-mark-${holiday.toIso()}')),
    );
    final dot = tester.getRect(
      find.byKey(ValueKey('holiday-dot-${holiday.toIso()}')),
    );
    expect(mark.center.dy, lessThan(box.center.dy));
    expect(mark.right, lessThanOrEqualTo(dot.left));
    expect(mark.overlaps(dot), isFalse);
  });

  testWidgets('the day cell says out loud how many appointments it has', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpCalendar(tester, prepare: prepare, overrides: deviceOverrides);
    // The mark is only a dot, so the count is said out loud (never colour
    // alone, rule 5): «2 citas» on the 12th, «1 cita» on the 13th.
    expect(find.bySemanticsLabel(RegExp('2 citas')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('1 cita')), findsOneWidget);
    handle.dispose();
  });
}
