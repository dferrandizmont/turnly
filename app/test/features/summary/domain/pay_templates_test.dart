import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/features/summary/domain/month_summary.dart';
import 'package:cuadrante/features/summary/domain/pay_templates.dart';
import 'package:flutter_test/flutter_test.dart';

const _h = 60;

ShiftType _work(
  String id, {
  int? start,
  int? end,
  int? fixedPlus,
  int? nightPlus,
  int? holidayPlus,
}) => ShiftType(
  id: id,
  code: id,
  name: id,
  colorValue: 0xFF4B4FD1,
  category: ShiftCategory.work,
  startMinute: start,
  endMinute: end,
  fixedPlusCents: fixedPlus,
  nightPlusCentsPerHour: nightPlus,
  holidayPlusCentsPerHour: holidayPlus,
);

final _morning = _work('M', start: 8 * _h, end: 15 * _h);
final _night = _work('N', start: 22 * _h, end: 8 * _h);
final _guard = _work('G', start: 8 * _h, end: 8 * _h); // 24 h
final _guard17 = _work('G17', start: 15 * _h, end: 8 * _h); // 17 h
final _noTimes = _work('X');
const _rest = ShiftType(
  id: 'L',
  code: 'L',
  name: 'Libre',
  colorValue: 0xFF888888,
  category: ShiftCategory.rest,
);

void main() {
  group('the templates', () {
    test('bring no amount and say which pluses each sector has', () {
      for (final template in payTemplates) {
        final types = [_morning, _night, _guard];
        expect(startingAmounts(template, types).values.toSet(), {
          0,
        }, reason: '${template.kind}');
      }
      final health = payTemplateOf(PayTemplateKind.publicHealth);
      expect(
        health.concepts.map((c) => c.slot).toSet(),
        PlusSlot.values.toSet(),
      );
      expect(health.annualHours, isNull);
      expect(payTemplateOf(PayTemplateKind.firefighters).annualHours, isNull);
      // The only figure: the annual hours of the national agreement.
      expect(payTemplateOf(PayTemplateKind.privateSecurity).annualHours, 1782);
    });

    test('the plus per guard only goes on shifts of 17 h or more', () {
      final concept = payTemplateOf(PayTemplateKind.firefighters).concepts
          .firstWhere((c) => c.slot == PlusSlot.fixedPerShift);
      expect(concept.target, PlusTarget.guards);
      expect(concept.appliesTo(_guard), isTrue);
      expect(concept.appliesTo(_guard17), isTrue);
      expect(concept.appliesTo(_night), isFalse);
      expect(concept.appliesTo(_noTimes), isFalse);
      expect(concept.appliesTo(_rest), isFalse);
    });

    test('the pluses per hour need the hours of the shift', () {
      const night = PlusConcept(PlusSlot.nightPerHour, PlusTarget.allWork);
      expect(night.appliesTo(_night), isTrue);
      expect(night.appliesTo(_noTimes), isFalse);
      expect(night.appliesTo(_rest), isFalse);
      const holiday = PlusConcept(PlusSlot.holidayPerHour, PlusTarget.allWork);
      expect(holiday.appliesTo(_morning), isTrue);
      expect(holiday.appliesTo(_noTimes), isFalse);
      const fixed = PlusConcept(PlusSlot.fixedPerShift, PlusTarget.allWork);
      expect(fixed.appliesTo(_noTimes), isTrue);
    });

    test('the night plus only goes on types with night hours (F3)', () {
      const night = PlusConcept(PlusSlot.nightPerHour, PlusTarget.allWork);
      // 08:00-15:00 and 15:00-22:00 never touch 22:00-06:00.
      expect(night.appliesTo(_morning), isFalse);
      expect(
        night.appliesTo(_work('A', start: 15 * _h, end: 22 * _h)),
        isFalse,
      );
      // One minute inside the window is enough.
      expect(
        night.appliesTo(_work('B', start: 15 * _h, end: 22 * _h + 1)),
        isTrue,
      );
      expect(night.appliesTo(_work('C', start: 5 * _h, end: 13 * _h)), isTrue);
      expect(night.appliesTo(_night), isTrue);
      expect(night.appliesTo(_guard), isTrue);
      // The night override of the type wins, like in the summary.
      final forcedNight = _work(
        'D',
        start: 8 * _h,
        end: 15 * _h,
      ).copyWith(nightOverride: true);
      final forcedDay = _work(
        'E',
        start: 22 * _h,
        end: 6 * _h,
      ).copyWith(nightOverride: false);
      expect(night.appliesTo(forcedNight), isTrue);
      expect(night.appliesTo(forcedDay), isFalse);
      // A split shift counts when any of its segments does.
      final split = _work(
        'S',
        start: 8 * _h,
        end: 12 * _h,
      ).copyWith(segment2StartMinute: 20 * _h, segment2DurationMinutes: 4 * _h);
      expect(night.appliesTo(split), isTrue);
    });
  });

  group('applying a template', () {
    final health = payTemplateOf(PayTemplateKind.publicHealth);

    test('writes the amounts into the chosen types only', () {
      final changed = applyPayTemplate(
        health,
        [_morning, _night, _guard, _rest],
        amounts: const {
          PlusSlot.nightPerHour: 150,
          PlusSlot.holidayPerHour: 300,
          PlusSlot.fixedPerShift: 5000,
        },
        selected: {'M', 'G', 'L'},
      );
      expect(changed.map((t) => t.id), ['M', 'G']);
      final morning = changed.first;
      // A Morning has no night hours: no night plus (F3).
      expect(morning.nightPlusCentsPerHour, isNull);
      expect(morning.holidayPlusCentsPerHour, 300);
      // Not a guard: the plus per guard does not touch it.
      expect(morning.fixedPlusCents, isNull);
      final guard = changed.last;
      expect(guard.fixedPlusCents, 5000);
      expect(guard.nightPlusCentsPerHour, 150);
    });

    test('a missing amount is 0, so the concept is created', () {
      final changed = applyPayTemplate(
        health,
        [_night],
        amounts: const {},
        selected: {'N'},
      );
      expect(changed.single.nightPlusCentsPerHour, 0);
      expect(changed.single.holidayPlusCentsPerHour, 0);
    });

    test('with only day types checked, no night plus is written (F3)', () {
      final changed = applyPayTemplate(
        health,
        [_morning, _work('A', start: 15 * _h, end: 22 * _h)],
        amounts: const {
          PlusSlot.nightPerHour: 150,
          PlusSlot.holidayPerHour: 300,
        },
        selected: {'M', 'A'},
      );
      expect(changed, hasLength(2));
      for (final type in changed) {
        expect(type.nightPlusCentsPerHour, isNull, reason: type.id);
        expect(type.holidayPlusCentsPerHour, 300, reason: type.id);
      }
      // A template that is only a night plus has nothing to write.
      expect(
        applyPayTemplate(
          const PayTemplate(
            kind: PayTemplateKind.publicHealth,
            concepts: [PlusConcept(PlusSlot.nightPerHour, PlusTarget.allWork)],
          ),
          [_morning],
          amounts: const {PlusSlot.nightPerHour: 150},
          selected: {'M'},
        ),
        isEmpty,
      );
    });

    test('a plus the template does not have is left as it was', () {
      final security = payTemplateOf(PayTemplateKind.privateSecurity);
      final type = _work('N', start: 22 * _h, end: 6 * _h, fixedPlus: 700);
      final changed = applyPayTemplate(
        security,
        [type],
        amounts: const {PlusSlot.nightPerHour: 100},
        selected: {'N'},
      );
      expect(changed.single.fixedPlusCents, 700);
      expect(changed.single.nightPlusCentsPerHour, 100);
    });

    test('a type that would end the same is not returned', () {
      final type = _work(
        'M',
        start: 8 * _h,
        end: 15 * _h,
        nightPlus: 100,
        holidayPlus: 200,
      );
      final changed = applyPayTemplate(
        payTemplateOf(PayTemplateKind.privateSecurity),
        [type],
        amounts: const {
          PlusSlot.nightPerHour: 100,
          PlusSlot.holidayPerHour: 200,
        },
        selected: {'M'},
      );
      expect(changed, isEmpty);
    });

    test('opening it again shows the amount the types share', () {
      final a = _work('A', start: 22 * _h, end: 6 * _h, nightPlus: 120);
      final b = _work('B', start: 20 * _h, end: 4 * _h, nightPlus: 120);
      final c = _work('C', start: 23 * _h, end: 7 * _h, nightPlus: 90);
      final security = payTemplateOf(PayTemplateKind.privateSecurity);
      expect(startingAmounts(security, [a, b])[PlusSlot.nightPerHour], 120);
      // Different amounts: start again from 0.
      expect(startingAmounts(security, [a, c])[PlusSlot.nightPerHour], 0);
    });
  });

  group('a 24 h guard that crosses into a holiday', () {
    // 24 December (not a holiday) and 25 December (holiday), 2026.
    const eve = CivilDate(2026, 12, 24);
    const christmas = CivilDate(2026, 12, 25);
    final holidays = {christmas};

    MonthSummary summarize(CivilDate day, ShiftType guard) => summarizeRange(
      Schedule(
        shiftTypes: [guard],
        entries: {
          day: DayEntry(date: day, shiftTypeIds: const ['G']),
        },
      ),
      day,
      day,
      holidays: holidays,
    );

    final guard = _work(
      'G',
      start: 8 * _h,
      end: 8 * _h,
      fixedPlus: 6000,
      nightPlus: 100,
      holidayPlus: 400,
    );

    test('from the eve, only its 8 h after midnight are on the holiday', () {
      final summary = summarize(eve, guard);
      expect(summary.workedMinutes, 24 * _h);
      expect(summary.holidayMinutes, 8 * _h);
      expect(summary.holidayShifts, 1);
      // 22:00-06:00: 8 h of night.
      expect(summary.nightMinutes, 8 * _h);
      expect(summary.holidayPlusCents, 8 * 400);
      expect(summary.nightPlusCents, 8 * 100);
      expect(summary.fixedPlusCents, 6000);
      expect(summary.earningsCents, 6000 + 8 * 400 + 8 * 100);
    });

    test('on the holiday, 16 h on it and 8 h on the day after', () {
      final summary = summarize(christmas, guard);
      expect(summary.holidayMinutes, 16 * _h);
      expect(summary.holidayPlusCents, 16 * 400);
      expect(summary.earningsCents, 6000 + 16 * 400 + 8 * 100);
    });

    test('a template applied to it is counted the same way', () {
      final applied = applyPayTemplate(
        payTemplateOf(PayTemplateKind.firefighters),
        [_guard],
        amounts: const {
          PlusSlot.fixedPerShift: 6000,
          PlusSlot.nightPerHour: 100,
          PlusSlot.holidayPerHour: 400,
        },
        selected: {'G'},
      ).single;
      expect(
        summarize(christmas, applied).earningsCents,
        summarize(christmas, guard).earningsCents,
      );
    });
  });
}
