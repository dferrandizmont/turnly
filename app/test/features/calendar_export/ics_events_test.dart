import 'package:cuadrante/features/calendar_export/application/ics_export.dart';
import 'package:cuadrante/features/calendar_export/domain/ics_events.dart';
import 'package:cuadrante/features/calendar_export/domain/ics_writer.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ics_fixtures.dart';

void main() {
  final madrid = icsLocation('Europe/Madrid');

  List<IcsEvent> build(
    Schedule s,
    CivilDate from, [
    CivilDate? to,
    IcsAbsences absences = IcsAbsences.hidden,
    bool includeRest = false,
    String calendarId = 'main',
  ]) => buildIcsEvents(
    s,
    calendarId: calendarId,
    from: from,
    to: to ?? from,
    location: madrid,
    absences: absences,
    includeRest: includeRest,
  );

  test('a morning shift in summer is two hours ahead of UTC', () {
    const d = CivilDate(2026, 7, 1);
    final e = build(
      scheduleOf({
        d: ['morning'],
      }),
      d,
    ).single;
    expect(e.start, DateTime.utc(2026, 7, 1, 4));
    expect(e.end, DateTime.utc(2026, 7, 1, 12));
    expect(e.summary, 'Mañana · M');
    expect(e.allDay, isFalse);
  });

  test('a night shift crosses midnight and ends the next day', () {
    const d = CivilDate(2026, 1, 15);
    final e = build(
      scheduleOf({
        d: ['night'],
      }),
      d,
    ).single;
    expect(e.start, DateTime.utc(2026, 1, 15, 21));
    expect(e.end, DateTime.utc(2026, 1, 16, 5));
  });

  test('DST in October: the night of the 24th lasts nine hours', () {
    const d = CivilDate(2026, 10, 24);
    final e = build(
      scheduleOf({
        d: ['night'],
      }),
      d,
    ).single;
    expect(e.start, DateTime.utc(2026, 10, 24, 20)); // 22:00 CEST
    expect(e.end, DateTime.utc(2026, 10, 25, 5)); // 06:00 CET
    expect(e.end!.difference(e.start!), const Duration(hours: 9));
  });

  test('DST in March: the night of the 28th lasts seven hours', () {
    const d = CivilDate(2026, 3, 28);
    final e = build(
      scheduleOf({
        d: ['night'],
      }),
      d,
    ).single;
    expect(e.start, DateTime.utc(2026, 3, 28, 21)); // 22:00 CET
    expect(e.end, DateTime.utc(2026, 3, 29, 4)); // 06:00 CEST
    expect(e.end!.difference(e.start!), const Duration(hours: 7));
  });

  test('a start in the hour skipped in March moves forward', () {
    const d = CivilDate(2026, 3, 29);
    final e = build(
      scheduleOf({
        d: ['early'],
      }),
      d,
    ).single;
    // 02:30 does not exist: it is read as 03:30 CEST (01:30 UTC).
    expect(e.start, DateTime.utc(2026, 3, 29, 1, 30));
    expect(e.end, DateTime.utc(2026, 3, 29, 2)); // 04:00 CEST
    expect(e.end!.isBefore(e.start!), isFalse);
  });

  test('a start in the hour repeated in October takes the first one', () {
    const d = CivilDate(2026, 10, 25);
    final e = build(
      scheduleOf({
        d: ['early'],
      }),
      d,
    ).single;
    expect(e.start, DateTime.utc(2026, 10, 25, 0, 30)); // 02:30 CEST
    expect(e.end, DateTime.utc(2026, 10, 25, 3)); // 04:00 CET
  });

  test('the morning of the DST days keeps its wall-clock hours', () {
    const march = CivilDate(2026, 3, 29);
    const october = CivilDate(2026, 10, 25);
    final s = scheduleOf({
      march: ['morning'],
      october: ['morning'],
    });
    expect(build(s, march).single.start, DateTime.utc(2026, 3, 29, 4));
    expect(build(s, october).single.start, DateTime.utc(2026, 10, 25, 5));
  });

  test('another zone (Canarias) is read in that zone', () {
    const d = CivilDate(2026, 1, 15);
    final e = buildIcsEvents(
      scheduleOf({
        d: ['morning'],
      }),
      calendarId: 'main',
      from: d,
      to: d,
      location: icsLocation('Atlantic/Canary'),
    ).single;
    expect(e.start, DateTime.utc(2026, 1, 15, 6));
  });

  test('a split shift gives one event per segment with their own UIDs', () {
    const d = CivilDate(2026, 11, 3);
    final events = build(
      scheduleOf({
        d: ['split'],
      }),
      d,
    );
    expect(events, hasLength(2));
    expect(events[0].start, DateTime.utc(2026, 11, 3, 8));
    expect(events[0].end, DateTime.utc(2026, 11, 3, 12));
    expect(events[1].start, DateTime.utc(2026, 11, 3, 16));
    expect(events[1].end, DateTime.utc(2026, 11, 3, 20));
    expect(events[0].uid, isNot(events[1].uid));
  });

  test('a shift without hours is an all-day event', () {
    const d = CivilDate(2026, 11, 3);
    final e = build(
      scheduleOf({
        d: ['course'],
      }),
      d,
    ).single;
    expect(e.allDay, isTrue);
    expect(e.startDate, d);
    expect(e.endDate, const CivilDate(2026, 11, 4));
  });

  test('rest days only when asked', () {
    const d = CivilDate(2026, 11, 3);
    final s = scheduleOf({
      d: ['rest'],
    });
    expect(build(s, d), isEmpty);
    final e = build(s, d, d, IcsAbsences.hidden, true).single;
    expect(e.summary, 'Libre · L');
    expect(e.transparent, isTrue);
  });

  group('absences', () {
    const d = CivilDate(2026, 11, 3);
    final s = scheduleOf({
      d: ['sickLeave', 'vacation'],
    });

    test('hidden by default', () {
      expect(build(s, d), isEmpty);
    });

    test('anonymous: one «Ausencia» a day, nothing of the type', () {
      final e = build(s, d, d, IcsAbsences.anonymous).single;
      expect(e.summary, 'Ausencia');
      expect(e.allDay, isTrue);
      expect(e.uid, isNot(contains('sick')));
      expect(e.uid, isNot(contains('vacation')));
      expect(e.description, isNull);
      expect(e.categories, isEmpty);
    });

    test('full: with their names (only for the person\'s own file)', () {
      final events = build(s, d, d, IcsAbsences.full);
      expect(events.map((e) => e.summary), [
        'Baja médica · B',
        'Vacaciones · V',
      ]);
    });
  });

  test('notes never go out', () {
    const d = CivilDate(2026, 11, 3);
    final s = scheduleOf({
      d: ['morning'],
    }, note: 'Médico a las 9');
    final text = const IcsWriter().write(
      events: build(s, d),
      stamp: DateTime.utc(2026),
    );
    expect(text, isNot(contains('Médico')));
    expect(text, isNot(contains('DESCRIPTION')));
  });

  test('a hidden shift leaves no gap in the UIDs of the day', () {
    const d = CivilDate(2026, 11, 3);
    final alone = build(
      scheduleOf({
        d: ['morning'],
      }),
      d,
    ).single.uid;
    final afterSick = build(
      scheduleOf({
        d: ['sickLeave', 'morning'],
      }),
      d,
    ).single.uid;
    final afterRest = build(
      scheduleOf({
        d: ['rest', 'morning'],
      }),
      d,
    ).single.uid;
    expect(afterSick, alone);
    expect(afterRest, alone);
    expect(alone, startsWith('20261103-0-0-'));
    // With the anonymous absence written, the shift keeps its UID too.
    final anonymous = build(
      scheduleOf({
        d: ['sickLeave', 'morning'],
      }),
      d,
      d,
      IcsAbsences.anonymous,
    );
    expect(anonymous.map((e) => e.uid), contains(alone));
  });

  test('UIDs are stable and differ between calendars', () {
    const d = CivilDate(2026, 11, 3);
    final s = scheduleOf({
      d: ['morning', 'night'],
    });
    final a = build(s, d).map((e) => e.uid).toList();
    final b = build(s, d).map((e) => e.uid).toList();
    final other = build(
      s,
      d,
      d,
      IcsAbsences.hidden,
      false,
      'second',
    ).map((e) => e.uid).toList();
    expect(a, b);
    expect(a.toSet(), hasLength(2));
    expect(a.toSet().intersection(other.toSet()), isEmpty);
    expect(
      a.every((u) => u.startsWith('20261103-') && u.endsWith('@turnly')),
      isTrue,
    );
    expect(a.any((u) => u.contains('main')), isFalse);
  });

  test('the range is cut to maxIcsDays and an inverted one is empty', () {
    const from = CivilDate(2026, 1, 1);
    final s = Schedule(
      shiftTypes: const [morning],
      patterns: const [
        Pattern(
          id: 'p',
          name: 'p',
          steps: [
            ['morning'],
          ],
        ),
      ],
      runs: const [
        PatternRun(id: 'r', patternId: 'p', startDate: from, seq: 1),
      ],
    );
    final events = build(s, from, from.addDays(1000));
    expect(events, hasLength(maxIcsDays));
    expect(build(s, from.addDays(1), from), isEmpty);
  });
}
