import 'dart:convert';

import 'package:cuadrante/features/calendar_export/application/ics_export.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/features/share_link/domain/share_feed.dart';
import 'package:flutter_test/flutter_test.dart';

import '../calendar_export/ics_fixtures.dart';

void main() {
  final madrid = icsLocation('Europe/Madrid');
  const today = CivilDate(2026, 10, 31);

  String feed(
    Schedule s, {
    ShareFeedOptions options = const ShareFeedOptions(),
    DateTime? stamp,
    String name = 'Mi cuadrante',
  }) => buildShareFeed(
    schedule: s,
    calendarId: 'main',
    calendarName: name,
    today: today,
    location: madrid,
    options: options,
    absenceLabel: 'Ausencia',
    stamp: stamp ?? DateTime.utc(2026, 10, 31, 12),
  );

  test('the window runs from last month to twelve months ahead', () {
    expect(shareFeedWindow(today), (
      const CivilDate(2026, 9, 1),
      const CivilDate(2027, 10, 31),
    ));
    expect(shareFeedWindow(const CivilDate(2026, 1, 15)), (
      const CivilDate(2025, 12, 1),
      const CivilDate(2027, 1, 31),
    ));
    // Every day of a month gives the same window.
    expect(
      shareFeedWindow(const CivilDate(2026, 10, 1)),
      shareFeedWindow(today),
    );
  });

  group('health and privacy filter', () {
    final day = today.addDays(3);
    final s = scheduleOf({
      day: ['morning', 'sickLeave'],
      day.addDays(1): ['vacation'],
      day.addDays(2): ['rest'],
    }, note: 'Revisión en el hospital');

    test('by default only work shifts go out', () {
      final text = feed(s);
      expect(text, contains('SUMMARY:Mañana · M'));
      expect(text, isNot(contains('Baja')));
      expect(text, isNot(contains('Vacaciones')));
      expect(text, isNot(contains('Ausencia')));
      expect(text, isNot(contains('Libre')));
      expect(text, isNot(contains('hospital')));
      expect('BEGIN:VEVENT'.allMatches(text).length, 1);
    });

    test('with absences on, they are an anonymous «Ausencia»', () {
      final text = feed(
        s,
        options: const ShareFeedOptions(includeAbsences: true),
      );
      expect('SUMMARY:Ausencia\r\n'.allMatches(text).length, 2);
      expect(text, isNot(contains('Baja')));
      expect(text, isNot(contains('médica')));
      expect(text, isNot(contains('Vacaciones')));
      expect(text, isNot(contains('sick')));
      expect(text, isNot(contains('vacation')));
      expect(text, isNot(contains('hospital')));
    });

    test('rest days only when asked', () {
      final text = feed(s, options: const ShareFeedOptions(includeRest: true));
      expect(text, contains('SUMMARY:Libre · L'));
      expect(text, isNot(contains('Ausencia')));
    });

    test('days outside the window are left out', () {
      final far = scheduleOf({
        const CivilDate(2026, 8, 31): ['morning'],
        const CivilDate(2027, 11, 1): ['morning'],
      });
      expect(feed(far), isNot(contains('BEGIN:VEVENT')));
    });
  });

  test('carries the calendar name and the refresh hint', () {
    final text = feed(scheduleOf({}), name: 'Turnos de casa');
    expect(text, contains('X-WR-CALNAME:Turnos de casa'));
    expect(text, contains('REFRESH-INTERVAL;VALUE=DURATION:PT6H'));
  });

  test('the fingerprint ignores the moment it was built', () {
    final s = scheduleOf({
      today: ['night'],
    });
    final a = shareFeedFingerprint(feed(s, stamp: shareFingerprintStamp));
    final b = shareFeedFingerprint(feed(s, stamp: shareFingerprintStamp));
    expect(a, b);
    expect(feed(s, stamp: DateTime.utc(2026, 11, 1)), isNot(feed(s)));
    final changed = scheduleOf({
      today: ['morning'],
    });
    expect(
      shareFeedFingerprint(feed(changed, stamp: shareFingerprintStamp)),
      isNot(a),
    );
  });

  // «A dense year»: the measure behind maxShareFeedBytes and the worker's
  // MAX_BODY_BYTES (640 KiB, about twice this). Fourteen months of four
  // events a day (morning, a split shift in two, night) is about 300 KiB.
  test('a dense year is about 300 KiB, half the upload limit', () {
    const from = CivilDate(2026, 9, 1);
    final s = Schedule(
      shiftTypes: scheduleOf({}).shiftTypes,
      patterns: const [
        Pattern(
          id: 'p',
          name: 'p',
          steps: [
            ['morning', 'split', 'night'],
          ],
        ),
      ],
      runs: const [
        PatternRun(id: 'r', patternId: 'p', startDate: from, seq: 1),
      ],
    );
    final text = feed(s, options: const ShareFeedOptions(includeRest: true));
    final bytes = utf8.encode(text).length;
    expect(bytes, inInclusiveRange(290 * 1024, 310 * 1024));
    expect(bytes * 2, lessThanOrEqualTo(maxShareFeedBytes));
  });
}
