import 'package:cuadrante/core/bootstrap/bootstrap.dart' show initializeLocale;
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/features/widget/domain/widget_snapshot.dart';
import 'package:cuadrante/features/widget/domain/widget_snapshot_builder.dart';
import 'package:cuadrante/features/widget/domain/widget_strings.dart';
import 'package:flutter_test/flutter_test.dart';

import '../schedule/domain/fixtures.dart';

const _partido = ShiftType(
  id: 'partido',
  code: 'P',
  name: 'Partido',
  colorValue: 0xFF336699,
  category: ShiftCategory.work,
  startMinute: 9 * 60,
  endMinute: 13 * 60,
  segment2StartMinute: 17 * 60,
  segment2DurationMinutes: 4 * 60,
);

const _today = CivilDate(2026, 10, 19);

WidgetSnapshot _build(
  Map<CivilDate, List<String>> days, {
  required bool hour12,
}) {
  final schedule = Schedule(
    shiftTypes: [...allTypes, _partido],
    entries: {
      for (final e in days.entries)
        e.key: DayEntry(date: e.key, shiftTypeIds: e.value),
    },
  );
  return buildWidgetSnapshot(
    schedule: schedule,
    holidays: const {},
    today: _today,
    timeZone: 'Europe/Madrid',
    strings: WidgetStrings(hour12: hour12),
    generatedAt: DateTime.utc(2026, 10, 19, 8, 30),
  );
}

/// The widget gets its times already written: on the 12 h clock they are the
/// compact form with the AM/PM letter (docs/widget-contrato.md).
Future<void> main() async {
  await initializeLocale();

  test('24 h: the times as always', () {
    final s = _build({
      _today: ['night'],
    }, hour12: false);
    final d = s.days.first;
    expect(d.shifts.single.timeLabel, '22:00–06:00');
    expect(d.shifts.single.compactTime, '22–06');
    expect(d.lock.inline, 'N · 22:00');
  });

  test('12 h: the compact form with a letter in every field', () {
    final s = _build({
      _today: ['night'],
      _today.addDays(1): ['morning'],
    }, hour12: true);
    final d = s.days.first;
    expect(d.shifts.single.timeLabel, '10p–6a');
    expect(d.shifts.single.compactTime, '10p–6a');
    expect(d.small.detail, '10p–6a');
    expect(d.lock.inline, 'N · 10p');
    expect(d.small.tomorrow, 'Mañana: M 6a–2p');
    expect(d.lock.rectangular.last, 'Mañana: M 6a–2p');
  });

  test('12 h: split shifts and several shifts', () {
    final s = _build({
      _today: ['partido'],
      _today.addDays(1): ['morning', 'partido'],
    }, hour12: true);
    final d = s.days.first;
    expect(d.shifts.single.timeLabel, '9a–1p · 5p–9p');
    expect(d.lock.inline, 'P · 9a');
    expect(s.days[1].small.detail, '6a–2p + 9a–1p · 5p–9p');
  });

  test('12 h: a shift without schedule has no time', () {
    final s = _build({
      _today: ['rest'],
    }, hour12: true);
    final shift = s.days.first.shifts.single;
    expect(shift.timeLabel, isNull);
    expect(shift.compactTime, isNull);
  });

  test('the spoken description uses the clock too', () {
    final text12 = const WidgetStrings(hour12: true).describe(
      _today,
      Schedule(
        shiftTypes: allTypes,
        entries: {
          _today: DayEntry(date: _today, shiftTypeIds: const ['night']),
        },
      ).resolve(_today),
      null,
    );
    expect(text12, contains('10:00'));
    expect(text12.toLowerCase(), contains('p'));
    expect(text12, isNot(contains('22:00')));
    final text24 = const WidgetStrings().describe(
      _today,
      Schedule(
        shiftTypes: allTypes,
        entries: {
          _today: DayEntry(date: _today, shiftTypeIds: const ['night']),
        },
      ).resolve(_today),
      null,
    );
    expect(text24, contains('22:00'));
  });
}
