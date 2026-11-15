import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/features/summary/domain/hours_bag.dart';
import 'package:cuadrante/features/summary/domain/hours_goal.dart';
import 'package:cuadrante/features/summary/domain/month_summary.dart';
import 'package:cuadrante/features/summary/domain/period_hours.dart';
import 'package:flutter_test/flutter_test.dart';

/// The extra hours as blocks (schema v7): price by mode, midnight, break,
/// the goal, early leave and the clock cutoff.
const date = CivilDate(2026, 11, 12);

/// 06:00-14:00, 8 h at 15,00 €/h.
const morning = ShiftType(
  id: 'm',
  code: 'M',
  name: 'Mañana',
  colorValue: 0xFFF5A524,
  category: ShiftCategory.work,
  startMinute: 360,
  endMinute: 840,
  hourlyRateCents: 1500,
);

OvertimeBlock block({
  int start = 840,
  int end = 960,
  int rest = 0,
  String id = 'b',
  String type = 't',
}) => OvertimeBlock(
  id: id,
  date: date,
  typeId: type,
  startMinute: start,
  endMinute: end,
  breakMinutes: rest,
);

OvertimeType kind(
  OvertimeRateMode mode, {
  bool counts = true,
  int factor = 12500,
  int? rate,
  String id = 't',
}) => OvertimeType(
  id: id,
  name: 'Extra $id',
  colorValue: 0xFF4B4FD1,
  rateMode: mode,
  multiplierBasisPoints: factor,
  hourlyRateCents: rate,
  countsForGoal: counts,
);

Schedule schedule(
  List<OvertimeType> types, {
  List<OvertimeBlock>? blocks,
  bool work = true,
  int? base,
  int early = 0,
}) => Schedule(
  shiftTypes: const [morning],
  overtimeTypes: types,
  baseHourlyRateCents: base,
  entries: {
    date: DayEntry(
      date: date,
      shiftTypeIds: work ? const ['m'] : const [],
      overtimeBlocks: blocks ?? [block()],
      earlyLeaveMinutes: early == 0 ? null : early,
    ),
  },
);

void main() {
  group('price by rate mode', () {
    test('2 h after a priced shift, in each of the four modes', () {
      for (final (mode, rate, expected) in [
        (OvertimeRateMode.shift, null, 3000),
        (OvertimeRateMode.multiplier, null, 3750),
        (OvertimeRateMode.fixed, 2200, 4400),
        (OvertimeRateMode.none, null, 0),
      ]) {
        final s = schedule([kind(mode, rate: rate)]);
        final result = summarizeRange(s, date, date);
        expect(result.workedMinutes, 600, reason: '$mode');
        expect(result.overtimeMinutes, 120, reason: '$mode');
        expect(result.overtimeCents, expected, reason: '$mode');
        expect(result.earningsCents, 12000 + expected, reason: '$mode');
        expect(
          result.overtimeTypes.single,
          OvertimeTypeTotal(
            type: s.overtimeTypes.single,
            minutes: 120,
            amountCents: mode == OvertimeRateMode.none ? null : expected,
          ),
        );
      }
    });

    test('a fixed rate pays on a free day too', () {
      final s = schedule([
        kind(OvertimeRateMode.fixed, rate: 2200),
      ], work: false);
      expect(summarizeRange(s, date, date).earningsCents, 4400);
    });

    test('«as the shift» on a free day takes the base rate, or nothing', () {
      for (final mode in [
        OvertimeRateMode.shift,
        OvertimeRateMode.multiplier,
      ]) {
        final unpriced = summarizeRange(
          schedule([kind(mode)], work: false),
          date,
          date,
        );
        expect(unpriced.workedMinutes, 120);
        expect(unpriced.earningsCents, isNull);
        expect(unpriced.extrasWithoutRateMinutes, 120);
        final priced = summarizeRange(
          schedule([kind(mode)], work: false, base: 1500),
          date,
          date,
        );
        expect(
          priced.overtimeCents,
          mode == OvertimeRateMode.shift ? 3000 : 3750,
        );
        expect(priced.extrasWithoutRateMinutes, 0);
      }
    });

    test('a type «sin precio» is not a missing price', () {
      final result = summarizeRange(
        schedule([kind(OvertimeRateMode.none)], work: false),
        date,
        date,
      );
      expect(result.earningsCents, isNull);
      expect(result.extrasWithoutRateMinutes, 0);
    });

    test('a fractional multiplier rounds once per type', () {
      final s = schedule(
        [kind(OvertimeRateMode.multiplier, factor: 13333)],
        work: false,
        base: 1,
        blocks: [
          for (var i = 0; i < 30; i++) block(start: i, end: i + 1, id: '$i'),
        ],
      );
      // 30 min x 0,01 x 1,3333 = 0,0067 -> 0,01, not 30 x 0.
      expect(summarizeRange(s, date, date).overtimeCents, 1);
    });

    test('a rate of 0 is a price: the summary shows money', () {
      final s = schedule([kind(OvertimeRateMode.fixed, rate: 0)], work: false);
      expect(summarizeRange(s, date, date).earningsCents, 0);
    });

    test('the amount of one block', () {
      final s = schedule([kind(OvertimeRateMode.multiplier)]);
      final day = s.resolve(date);
      expect(
        overtimeAmountCents(block(), s.overtimeTypes.single, day, null),
        3750,
      );
      expect(overtimeRateUnits(kind(OvertimeRateMode.none), day, 1000), isNull);
    });
  });

  group('the clock', () {
    test('a block past midnight belongs to the day it starts on', () {
      final b = block(start: 1380, end: 120, rest: 30);
      expect(b.crossesMidnight, isTrue);
      expect(b.durationMinutes, 180);
      expect(b.paidMinutes, 150);
      final s = schedule(
        [kind(OvertimeRateMode.fixed, rate: 1800)],
        blocks: [b],
        work: false,
      );
      final result = summarizeRange(s, date, date, holidays: {date.addDays(1)});
      expect(result.workedMinutes, 150);
      expect(result.nightMinutes, 150);
      // 2 of the 3 clock hours are on the holiday, prorated by the break.
      expect(result.holidayMinutes, 100);
      // A block is not a shift worked on a holiday.
      expect(result.holidayShifts, 0);
      expect(result.earningsCents, 4500);
      expect(s.resolve(date.addDays(1)).overtimeBlocks, isEmpty);
      expect(
        summarizeRange(s, date.addDays(1), date.addDays(1)).workedMinutes,
        0,
      );
    });

    test('equal start and end is 24 h; the break must be shorter', () {
      expect(block(start: 0, end: 0).durationMinutes, 1440);
      expect(block(start: 600, end: 601).durationMinutes, 1);
      expect(block(rest: 120).problem, 'break');
      expect(block(rest: 119).problem, isNull);
      expect(block(start: 1440).problem, 'start');
    });

    test('with a cutoff only the minutes already worked count', () {
      final s = schedule(
        [kind(OvertimeRateMode.fixed, rate: 1800)],
        work: false,
        blocks: [block(start: 600, end: 720)],
      );
      final before = summarizeRange(
        s,
        date,
        date,
        cutoff: const ClockCutoff(date, 599),
      );
      final during = summarizeRange(
        s,
        date,
        date,
        cutoff: const ClockCutoff(date, 660),
      );
      expect(before.workedMinutes, 0);
      expect(during.workedMinutes, 60);
      expect(during.earningsCents, 1800);
    });

    test('the early leave cuts the shift, never a block', () {
      final s = schedule([
        kind(OvertimeRateMode.fixed, rate: 3000, counts: false),
      ], early: 60);
      final result = summarizeRange(s, date, date);
      // 8 h - 1 h + 2 h.
      expect(result.workedMinutes, 540);
      expect(result.earlyLeaveMinutes, 60);
      expect(result.earlyLeaveCents, 1500);
      expect(result.overtimeCents, 6000);
      expect(result.earningsCents, 12000 - 1500 + 6000);
      expect(result.goalCountedMinutes, 420);
    });
  });

  group('the hours goal', () {
    test('only the types that count, in the goal, the bag and the cap', () {
      for (final counts in [false, true]) {
        final s = schedule([kind(OvertimeRateMode.none, counts: counts)]);
        final summary = summarizeRange(s, date, date);
        expect(summary.workedMinutes, 600);
        expect(summary.goalCountedMinutes, counts ? 600 : 480);
        expect(summary.cappedOvertimeMinutes, counts ? 120 : 0);
        final worked = splitPeriodHours(s, date, date, date.addDays(1));
        final goal = splitPeriodHours(
          s,
          date,
          date,
          date.addDays(1),
          forGoal: true,
        );
        expect(worked.doneMinutes, 600);
        expect(goal.doneMinutes, counts ? 600 : 480);
        final bag = hoursBalance(
          s,
          const HoursGoal(HoursGoalPeriod.month, 100),
          fromMonth: date,
          toMonth: date,
        );
        expect(bag.workedMinutes, goal.doneMinutes);
      }
    });

    test('two types: totals by type, in the order of the types', () {
      final extra = kind(OvertimeRateMode.multiplier);
      final other = kind(OvertimeRateMode.none, counts: false, id: 'o');
      final s = schedule(
        [extra, other],
        blocks: [
          block(),
          block(id: 'c', type: 'o', start: 1080, end: 1260),
        ],
      );
      final result = summarizeRange(s, date, date);
      expect(result.overtimeMinutes, 300);
      expect(result.goalExcludedMinutes, 180);
      expect(result.overtimeTypes, [
        OvertimeTypeTotal(type: extra, minutes: 120, amountCents: 3750),
        OvertimeTypeTotal(type: other, minutes: 180),
      ]);
    });
  });

  group('the old overtime minutes', () {
    test('a day with them still counts as before', () {
      final s = Schedule(
        shiftTypes: const [morning],
        entries: {
          date: const DayEntry(
            date: date,
            shiftTypeIds: ['m'],
            overtimeMinutes: 60,
          ),
        },
      );
      final result = summarizeRange(s, date, date);
      expect(result.workedMinutes, 540);
      expect(result.overtimeCents, 1500);
      expect(s.resolve(date).overtimeMinutes, 60);
    });

    test('become a block from the end of the last shift, or 08:00', () {
      final free = legacyOvertimeBlock(
        Schedule(shiftTypes: const [morning]).resolve(date),
        90,
      );
      expect((free.startMinute, free.endMinute), (480, 570));
      final worked = Schedule(
        shiftTypes: const [morning],
        entries: {
          date: const DayEntry(date: date, shiftTypeIds: ['m']),
        },
      ).resolve(date);
      final b = legacyOvertimeBlock(worked, 1440);
      expect((b.startMinute, b.endMinute), (840, 840));
      expect(b.durationMinutes, 1440);
      expect(b.typeId, overtimeTypeId);
      expect(b.id, 'legacy-2026-11-12');
      expect(() => legacyOvertimeBlock(worked, 0), throwsArgumentError);
    });

    test('a night shift ending the next morning starts the block then', () {
      const night = ShiftType(
        id: 'n',
        code: 'N',
        name: 'Noche',
        colorValue: 0xFF4B4FD1,
        category: ShiftCategory.work,
        startMinute: 1320,
        endMinute: 360,
      );
      final day = Schedule(
        shiftTypes: const [night],
        entries: {
          date: const DayEntry(date: date, shiftTypeIds: ['n']),
        },
      ).resolve(date);
      expect(lastWorkEndMinute(day), 1800);
      final b = legacyOvertimeBlock(day, 60);
      expect((b.date, b.startMinute, b.endMinute), (date, 360, 420));
      // It is the morning after: it counts at D+1 06:00.
      expect(overtimeStartAbs(b, day), 1800);
      expect(overtimeOnNextDay(b, day), isTrue);
      // Between that end (06:00) and the start (22:00), the block is D+1 only
      // when it is closer to the end: 06:00-08:00 is the morning after,
      // 18:00-21:00 is before the shift, on D.
      final morning = b.copyWith(startMinute: 360, endMinute: 480);
      expect(overtimeStartAbs(morning, day), 1800);
      expect(overtimeOnNextDay(morning, day), isTrue);
      final evening = b.copyWith(startMinute: 1080, endMinute: 1260);
      expect(overtimeStartAbs(evening, day), 1080);
      expect(overtimeOnNextDay(evening, day), isFalse);
      // Right in the middle (13:00-15:00: 7 h after the end, 7 h before the
      // start) it is the morning after.
      final middle = b.copyWith(startMinute: 780, endMinute: 900);
      expect(overtimeStartAbs(middle, day), 780 + 1440);
      // One minute later it is closer to the start: on D.
      final pastMiddle = b.copyWith(startMinute: 781, endMinute: 901);
      expect(overtimeStartAbs(pastMiddle, day), 781);
      // One that runs into the start of the shift stays on D.
      final intoShift = b.copyWith(startMinute: 1260, endMinute: 1380);
      expect(overtimeStartAbs(intoShift, day), 1260);
      // One from the start of the shift on, or before its end, is on the day.
      final during = b.copyWith(startMinute: 1380, endMinute: 60);
      expect(overtimeStartAbs(during, day), 1380);
      expect(overtimeOnNextDay(during, day), isFalse);
      final early = b.copyWith(startMinute: 300, endMinute: 330);
      expect(overtimeStartAbs(early, day), 300);
    });

    test('after a night shift, the summary counts the block the morning '
        'after, like the old minutes', () {
      const night = ShiftType(
        id: 'n',
        code: 'N',
        name: 'Noche',
        colorValue: 0xFF4B4FD1,
        category: ShiftCategory.work,
        startMinute: 1320,
        endMinute: 360,
        hourlyRateCents: 1200,
        nightPlusCentsPerHour: 300,
        holidayPlusCentsPerHour: 600,
      );
      final old = Schedule(
        shiftTypes: const [night],
        entries: {
          date: const DayEntry(
            date: date,
            shiftTypeIds: ['n'],
            overtimeMinutes: 120,
          ),
        },
      );
      final block = legacyOvertimeBlock(old.resolve(date), 120);
      final converted = old.copyWith(
        entries: {
          date: DayEntry(
            date: date,
            shiftTypeIds: const ['n'],
            overtimeBlocks: [block],
          ),
        },
      );
      for (final holidays in [
        <CivilDate>{},
        {date.addDays(1)},
      ]) {
        final a = summarizeRange(old, date, date, holidays: holidays);
        final b = summarizeRange(converted, date, date, holidays: holidays);
        expect(
          (
            b.workedMinutes,
            b.nightMinutes,
            b.holidayMinutes,
            b.holidayShifts,
            b.nightPlusCents,
            b.holidayPlusCents,
            b.overtimeCents,
            b.earningsCents,
          ),
          (
            a.workedMinutes,
            a.nightMinutes,
            a.holidayMinutes,
            a.holidayShifts,
            a.nightPlusCents,
            a.holidayPlusCents,
            a.overtimeCents,
            a.earningsCents,
          ),
          reason: '$holidays',
        );
      }
    });
  });

  test('with «Salí antes» the old minutes and the block give the same hours '
      'and money; the early leave now cuts the shift, not the extra', () {
    final old = Schedule(
      shiftTypes: const [morning],
      entries: {
        date: const DayEntry(
          date: date,
          shiftTypeIds: ['m'],
          overtimeMinutes: 120,
          earlyLeaveMinutes: 30,
        ),
      },
    );
    final converted = old.copyWith(
      entries: {
        date: DayEntry(
          date: date,
          shiftTypeIds: const ['m'],
          earlyLeaveMinutes: 30,
          overtimeBlocks: [legacyOvertimeBlock(old.resolve(date), 120)],
        ),
      },
    );
    final a = summarizeRange(old, date, date);
    final b = summarizeRange(converted, date, date);
    expect(b.workedMinutes, a.workedMinutes);
    expect(b.earningsCents, a.earningsCents);
    expect(b.overtimeCents, a.overtimeCents);
    expect(b.earlyLeaveCents, a.earlyLeaveCents);
  });

  test('the engine gives the blocks of the day and their minutes', () {
    final s = schedule(
      [kind(OvertimeRateMode.none)],
      blocks: [
        block(id: 'late', start: 1200, end: 1260),
        block(id: 'early', start: 840, end: 900, rest: 15),
      ],
    );
    final day = s.resolve(date);
    expect(day.overtimeMinutes, 105);
    expect(day.hasExtras, isTrue);
    expect(day.overtimeBlocks, hasLength(2));
    expect(s.resolvePattern(date).overtimeBlocks, hasLength(2));
  });
}
