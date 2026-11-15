import 'dart:convert';
import 'dart:io';

import 'package:cuadrante/core/bootstrap/bootstrap.dart' show initializeLocale;
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/features/summary/domain/month_summary.dart';
import 'package:cuadrante/features/widget/domain/widget_snapshot.dart';
import 'package:cuadrante/features/widget/domain/widget_snapshot_builder.dart';
import 'package:cuadrante/features/widget/domain/widget_strings.dart';
import 'package:flutter_test/flutter_test.dart';

import '../schedule/domain/fixtures.dart';

void main() {
  setUpAll(initializeLocale);
  const first = CivilDate(2026, 10, 30);
  Schedule calendar({int breakMinutes = 30}) => Schedule(
    shiftTypes: allTypes,
    overtimeTypes: [
      ...defaultOvertimeTypes,
      const OvertimeType(
        id: 'training',
        name: 'Formación',
        colorValue: 0xff123456,
      ),
    ],
    entries: {
      first: DayEntry(
        date: first,
        shiftTypeIds: const ['night'],
        earlyLeaveMinutes: 60,
        overtimeBlocks: [
          OvertimeBlock(
            id: 'extra',
            date: first,
            typeId: overtimeTypeId,
            startMinute: 360,
            endMinute: 510,
            breakMinutes: breakMinutes,
          ),
        ],
      ),
      first.addDays(1): DayEntry(
        date: first.addDays(1),
        shiftTypeIds: const ['rest'],
        overtimeBlocks: [
          OvertimeBlock(
            id: 'other',
            date: first.addDays(1),
            typeId: otherWorkTypeId,
            startMinute: 600,
            endMinute: 720,
          ),
        ],
      ),
      first.addDays(6): DayEntry(
        date: first.addDays(6),
        overtimeMinutes: 30,
        overtimeBlocks: [
          OvertimeBlock(
            id: 'course',
            date: first.addDays(6),
            typeId: 'training',
            startMinute: 1000,
            endMinute: 1060,
          ),
        ],
      ),
      // Outside the first seven days.
      first.addDays(7): DayEntry(date: first.addDays(7), overtimeMinutes: 600),
    },
  );
  WidgetSnapshot build(Schedule schedule, {String locale = 'es'}) =>
      buildWidgetSnapshot(
        schedule: schedule,
        holidays: const {},
        today: first,
        timeZone: 'Europe/Madrid',
        strings: WidgetStrings(locale: locale),
        generatedAt: DateTime.utc(2026, 10, 30),
      );

  test(
    'v3 carries paid extra blocks, types and applied early leave separately',
    () {
      final snapshot = build(calendar());
      expect(snapshot.version, 3);
      expect(snapshot.dayExtras![first.toIso()], [
        '+2 h extra',
        'Salí 1 h antes',
      ]);
      expect(snapshot.dayExtras![first.addDays(1).toIso()], [
        '+2 h Otro trabajo',
      ]);
      expect(snapshot.dayExtras![first.addDays(6).toIso()], [
        '+30 min extra',
        '+1 h Formación',
      ]);
      expect(snapshot.days.first.small.detail, '22:00–06:00');
      expect(
        snapshot.descriptions!.days[first.toIso()],
        contains('+2 h extra. Salí 1 h antes'),
      );
      final decoded = WidgetSnapshot.decode(snapshot.encode());
      expect(decoded.dayExtras, snapshot.dayExtras);
      expect(decoded.computeContentHash(), snapshot.contentHash);
      expect(decoded.encode(), snapshot.encode());
      expect(
        build(calendar(breakMinutes: 0)).contentHash,
        isNot(snapshot.contentHash),
      );
    },
  );

  test('rolling totals use the summary, count seven start dates and exclude other jobs', () {
    final schedule = calendar();
    final snapshot = build(schedule);
    for (final day in snapshot.days) {
      final date = CivilDate.parse(day.date);
      final expected = summarizeRange(
        schedule,
        date,
        date.addDays(6),
      ).goalCountedMinutes;
      expect(snapshot.stripTotals![day.date]!.minutes, expected);
    }
    expect(snapshot.stripTotals![first.toIso()]!.minutes, 630);
    expect(snapshot.stripTotals![first.toIso()]!.label, '7 días: 10 h 30 min');
    expect(snapshot.stripTotals![first.addDays(1).toIso()]!.minutes, 690);
  });

  test(
    'five locales localize the labels and the accessibility descriptions',
    () {
      for (final (locale, overtime, early, total) in [
        ('es', '+2 h extra', 'Salí 1 h antes', '7 días:'),
        ('ca', '+2 h extra', 'He sortit 1 h abans', '7 dies:'),
        ('gl', '+2 h extra', 'Saín 1 h antes', '7 días:'),
        ('eu', 'Aparteko orduak: +2 h', '1 h lehenago atera naiz', '7 egun:'),
        ('en', '+2 h overtime', 'Left 1 h early', '7 days:'),
      ]) {
        final snapshot = build(calendar(), locale: locale);
        expect(snapshot.dayExtras![first.toIso()], [overtime, early]);
        expect(snapshot.stripTotals![first.toIso()]!.label, startsWith(total));
        expect(snapshot.descriptions!.days[first.toIso()], contains(early));
      }
    },
  );

  test('Basque type labels use a standalone name and duration', () {
    final snapshot = build(calendar(), locale: 'eu');
    expect(snapshot.dayExtras![first.addDays(1).toIso()], [
      'Beste lan bat: +2 h',
    ]);
    expect(snapshot.dayExtras![first.addDays(6).toIso()], [
      'Aparteko orduak: +30 min',
      'Formación: +1 h',
    ]);
    expect(
      snapshot.descriptions!.days[first.addDays(1).toIso()],
      contains('Beste lan bat: +2 h'),
    );
  });

  test('v1 and v2 preserve their original JSON and hash without v3 fields', () {
    for (final version in [1, 2]) {
      final json = File(
        'android/app/src/test/resources/widget_snapshot_v$version.json',
      ).readAsStringSync();
      final snapshot = WidgetSnapshot.decode(json);
      expect(snapshot.version, version);
      expect(snapshot.dayExtras, isNull);
      expect(snapshot.stripTotals, isNull);
      expect(snapshot.computeContentHash(), snapshot.contentHash);
      expect(snapshot.encode(), json);
    }
    final json = build(calendar()).toJson()..remove('dayExtras');
    expect(WidgetSnapshot.tryDecode(jsonEncode(json)), isNull);
  });

  test(
    '60 days with extra blocks and early leave stay within the contract size',
    () {
      final schedule = Schedule(
        shiftTypes: allTypes,
        entries: {
          for (var i = 0; i < 60; i++)
            first.addDays(i): DayEntry(
              date: first.addDays(i),
              shiftTypeIds: const ['night'],
              earlyLeaveMinutes: 60,
              overtimeBlocks: [
                OvertimeBlock(
                  id: 'extra-$i',
                  date: first.addDays(i),
                  typeId: overtimeTypeId,
                  startMinute: 360,
                  endMinute: 480,
                ),
              ],
            ),
        },
      );
      final snapshot = build(schedule);
      final size = utf8.encode(snapshot.encode()).length;
      expect(snapshot.dayExtras, hasLength(60));
      expect(size, lessThan(kWidgetSnapshotMaxBytes));
    },
  );
}
