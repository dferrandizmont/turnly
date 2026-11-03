import 'package:cuadrante/features/calendar/application/off_outlook.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:flutter_test/flutter_test.dart';

const _work = ShiftType(
  id: 'work',
  code: 'M',
  name: 'Mañana',
  colorValue: 0xFFF5A524,
  category: ShiftCategory.work,
  startMinute: 6 * 60,
  endMinute: 14 * 60,
);
const _rest = ShiftType(
  id: 'rest',
  code: 'L',
  name: 'Libre',
  colorValue: 0xFFE4E4E7,
  category: ShiftCategory.rest,
);
const _vacation = ShiftType(
  id: 'vacation',
  code: 'V',
  name: 'Vacaciones',
  colorValue: 0xFF30A46C,
  category: ShiftCategory.absence,
);
const _types = [_work, _rest, _vacation];

// October 2026: Thursday the 1st, so Saturdays are 3, 10, 17, 24, 31.
CivilDate _oct(int day) => CivilDate(2026, 10, day);

/// `W` work, `L` rest, `V` vacation, `.` nothing annotated, one letter per day
/// from [from] (Monday 5 October by default).
Schedule _week(String days, {CivilDate? from}) {
  final start = from ?? _oct(5);
  const ids = {'W': 'work', 'L': 'rest', 'V': 'vacation'};
  return Schedule(
    shiftTypes: _types,
    entries: {
      for (var i = 0; i < days.length; i++)
        if (days[i] != '.')
          start.addDays(i): DayEntry(
            date: start.addDays(i),
            shiftTypeIds: [ids[days[i]]!],
          ),
    },
  );
}

void main() {
  test('Monday 5 is a Monday (the fixtures below rely on it)', () {
    expect(_oct(5).weekday, DateTime.monday);
  });

  group('next day off', () {
    test('today is a rest day: it is today, and says when work resumes', () {
      final outlook = computeOffOutlook(_week('LLWWWWWL'), _oct(5));
      expect(outlook.todayKind, DayKind.rest);
      expect(outlook.nextOff!.date, _oct(5));
      expect(outlook.nextOff!.daysAway, 0);
      expect(outlook.nextOff!.kind, DayKind.rest);
      expect(outlook.nextOff!.inferred, isFalse);
      expect(outlook.returnDate, _oct(7));
      expect(outlook.workedStreak, 0);
      expect(outlook.workDaysLeft, isNull);
    });

    test('tomorrow is off', () {
      final outlook = computeOffOutlook(_week('WLWW'), _oct(5));
      expect(outlook.nextOff!.date, _oct(6));
      expect(outlook.nextOff!.daysAway, 1);
      expect(outlook.returnDate, isNull, reason: 'today is not off');
      expect(outlook.workDaysLeft, 0);
    });

    test('after a streak of work', () {
      // Mon-Fri work, Sat-Sun rest; today is Wednesday 7.
      final outlook = computeOffOutlook(_week('WWWWWLL'), _oct(7));
      expect(outlook.nextOff!.date, _oct(10));
      expect(outlook.nextOff!.daysAway, 3);
      expect(outlook.workedStreak, 3);
      expect(outlook.workDaysLeft, 2);
    });

    test('a vacation or other absence is off', () {
      final outlook = computeOffOutlook(_week('WWVVW'), _oct(5));
      expect(outlook.nextOff!.date, _oct(7));
      expect(outlook.nextOff!.kind, DayKind.absence);
      final onVacation = computeOffOutlook(_week('WWVVW'), _oct(7));
      expect(onVacation.todayKind, DayKind.absence);
      expect(onVacation.returnDate, _oct(9));
    });

    test('a gap between annotated days is taken as off, flagged inferred', () {
      final outlook = computeOffOutlook(_week('WW.W'), _oct(5));
      expect(outlook.nextOff!.date, _oct(7));
      expect(outlook.nextOff!.kind, DayKind.unrecorded);
      expect(outlook.nextOff!.inferred, isTrue);
    });

    test('the first day off in time order wins, annotated or inferred', () {
      final outlook = computeOffOutlook(_week('W.WL'), _oct(5));
      expect(outlook.nextOff!.date, _oct(6));
      expect(outlook.nextOff!.inferred, isTrue);
    });

    test('today unannotated but with work after it: off today, inferred', () {
      final outlook = computeOffOutlook(_week('.W'), _oct(5));
      expect(outlook.nextOff!.daysAway, 0);
      expect(outlook.nextOff!.inferred, isTrue);
      expect(outlook.returnDate, _oct(6));
    });

    test('nothing annotated after the last annotated day does not count', () {
      // Work Mon-Tue and nothing more: the calendar knows nothing beyond.
      final outlook = computeOffOutlook(_week('WW'), _oct(5));
      expect(outlook.nextOff, isNull);
      expect(outlook.freeWeekend, isNull);
      expect(outlook.isEmpty, isTrue);
    });

    test('an empty calendar says nothing at all', () {
      final outlook = computeOffOutlook(_week(''), _oct(5));
      expect(outlook.todayKind, DayKind.unrecorded);
      expect(outlook.nextOff, isNull);
      expect(outlook.returnDate, isNull);
      expect(outlook.freeWeekend, isNull);
      expect(outlook.workedStreak, 0);
      expect(outlook.workDaysLeft, isNull);
      expect(outlook.isEmpty, isTrue);
    });

    test('only empty days annotated by hand (note, extra) say nothing', () {
      final schedule = Schedule(
        shiftTypes: _types,
        entries: {
          _oct(6): DayEntry(date: _oct(6), note: 'Cena'),
          _oct(7): DayEntry(date: _oct(7), overtimeMinutes: 60),
        },
      );
      expect(computeOffOutlook(schedule, _oct(5)).nextOff, isNull);
    });

    test('a rotation that never rests has no next day off', () {
      final schedule = Schedule(
        shiftTypes: _types,
        patterns: const [
          Pattern(
            id: 'all-work',
            name: 'Siempre',
            steps: [
              ['work'],
            ],
          ),
        ],
        runs: [
          PatternRun(
            id: 'r',
            patternId: 'all-work',
            startDate: _oct(1),
            seq: 1,
          ),
        ],
      );
      final outlook = computeOffOutlook(schedule, _oct(20));
      expect(outlook.nextOff, isNull);
      expect(outlook.freeWeekend, isNull);
      expect(outlook.workedStreak, 20, reason: '1 to 20 October');
      expect(outlook.workDaysLeft, isNull);
    });

    test('a rotation that ends: the days after it are not off', () {
      final schedule = Schedule(
        shiftTypes: _types,
        patterns: const [
          Pattern(
            id: 'p',
            name: 'p',
            steps: [
              ['work'],
              ['work'],
              ['rest'],
            ],
          ),
        ],
        runs: [
          PatternRun(
            id: 'r',
            patternId: 'p',
            startDate: _oct(5),
            endDate: _oct(11),
            seq: 1,
          ),
        ],
      );
      // From the 12th on nothing is annotated.
      final late = computeOffOutlook(schedule, _oct(12));
      expect(late.nextOff, isNull);
      // Inside the rotation the rest days are found.
      final inside = computeOffOutlook(schedule, _oct(5));
      expect(inside.nextOff!.date, _oct(7));
      expect(inside.workDaysLeft, 1);
    });

    test('the search stops at the look-ahead', () {
      final schedule = Schedule(
        shiftTypes: _types,
        entries: {
          for (var d = 0; d <= 130; d++)
            _oct(1).addDays(d): DayEntry(
              date: _oct(1).addDays(d),
              shiftTypeIds: [d == 130 ? 'rest' : 'work'],
            ),
        },
      );
      expect(computeOffOutlook(schedule, _oct(1)).nextOff, isNull);
      expect(
        computeOffOutlook(schedule, _oct(1), lookAhead: 130).nextOff!.daysAway,
        130,
      );
      expect(kOffLookAheadDays, 120);
    });
  });

  group('free weekend', () {
    test('Saturday and Sunday both off', () {
      final outlook = computeOffOutlook(_week('WWWWWLL'), _oct(5));
      expect(
        outlook.freeWeekend,
        FreeWeekend(saturday: _oct(10), sunday: _oct(11)),
      );
    });

    test('both must be off: Saturday rest and Sunday work skips it', () {
      final outlook = computeOffOutlook(_week('WWWWWLWWWWWWLL'), _oct(5));
      expect(outlook.freeWeekend!.saturday, _oct(17));
    });

    test('an absence counts as off, and a gap between annotated days too', () {
      final vacation = computeOffOutlook(_week('WWWWWVV'), _oct(5));
      expect(vacation.freeWeekend!.saturday, _oct(10));
      final gap = computeOffOutlook(_week('WWWWW..W'), _oct(5));
      expect(gap.freeWeekend!.saturday, _oct(10));
    });

    test('a Sunday that is past the last annotated day is not enough', () {
      // Saturday annotated rest, Sunday nothing and nothing after.
      final outlook = computeOffOutlook(_week('WWWWWL'), _oct(5));
      expect(outlook.freeWeekend, isNull);
    });

    test('today on the free Saturday counts; on the Sunday it does not', () {
      final schedule = _week('WWWWWLLWWWWWLL');
      expect(
        computeOffOutlook(schedule, _oct(10)).freeWeekend!.saturday,
        _oct(10),
      );
      expect(
        computeOffOutlook(schedule, _oct(11)).freeWeekend!.saturday,
        _oct(17),
      );
    });

    test('across two months', () {
      final outlook = computeOffOutlook(
        _week('WWWWWLL', from: _oct(26)),
        _oct(26),
      );
      expect(outlook.freeWeekend!.saturday, _oct(31));
      expect(outlook.freeWeekend!.sunday, const CivilDate(2026, 11, 1));
    });
  });

  group('streak of work', () {
    test('counts today and the work days before it', () {
      final outlook = computeOffOutlook(_week('LWWWWL'), _oct(8));
      expect(outlook.workedStreak, 3);
      expect(outlook.workDaysLeft, 1);
      final fifth = computeOffOutlook(_week('LWWWWL'), _oct(9));
      expect(fifth.workedStreak, 4);
      expect(fifth.workDaysLeft, 0);
    });

    test('is 0 on a day off and on an empty day', () {
      expect(computeOffOutlook(_week('WWL'), _oct(7)).workedStreak, 0);
      expect(computeOffOutlook(_week('WW.'), _oct(7)).workedStreak, 0);
    });

    test('an unannotated day breaks it', () {
      expect(computeOffOutlook(_week('WW.WW'), _oct(9)).workedStreak, 2);
    });

    test('a vacation day breaks it', () {
      expect(computeOffOutlook(_week('WVWW'), _oct(8)).workedStreak, 2);
    });

    test('the days left are the work days before the next day off', () {
      final outlook = computeOffOutlook(_week('WWWWWL'), _oct(5));
      expect(outlook.workedStreak, 1);
      expect(outlook.workDaysLeft, 4);
    });

    test('without a known day off the days left are unknown', () {
      final outlook = computeOffOutlook(_week('WWW'), _oct(5));
      expect(outlook.workedStreak, 1);
      expect(outlook.workDaysLeft, isNull);
    });
  });

  group('computeOffOutlookWith', () {
    test('asks for each day only through the given function', () {
      final seen = <CivilDate>{};
      final outlook = computeOffOutlookWith(
        (date) {
          seen.add(date);
          return date == _oct(7) ? DayKind.rest : DayKind.work;
        },
        _oct(5),
        lookAhead: 5,
        lookBack: 2,
      );
      expect(outlook.nextOff!.date, _oct(7));
      expect(outlook.workedStreak, 3, reason: 'today and two days back');
      expect(seen.every((d) => d.differenceInDays(_oct(5)).abs() <= 5), isTrue);
    });
  });
}
