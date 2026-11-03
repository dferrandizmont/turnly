import 'package:cuadrante/features/reports/domain/report_model.dart';
import 'package:cuadrante/features/reports/domain/report_options.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/features/summary/domain/period_hours.dart';
import 'package:cuadrante/features/summary/domain/summary_range.dart';
import 'package:flutter_test/flutter_test.dart';

import 'report_fixtures.dart';

ReportDay _day(ReportModel model, int day) =>
    model.days.firstWhere((d) => d.date == CivilDate(2026, 10, day));

void main() {
  group('the period', () {
    test('one day per date of the range, in order', () {
      final model = octoberReport();
      expect(model.days, hasLength(31));
      expect(model.days.first.date, const CivilDate(2026, 10, 1));
      expect(model.days.last.date, const CivilDate(2026, 10, 31));
      expect(model.calendarName, 'Hospital');
    });

    test('a free range across two months', () {
      final model = octoberReport(
        range: const SummaryRange(
          CivilDate(2026, 10, 28),
          CivilDate(2026, 11, 3),
        ),
      );
      expect(model.days, hasLength(7));
      expect(model.days[4].date, const CivilDate(2026, 11, 1));
    });

    test('a single day', () {
      final model = octoberReport(
        range: const SummaryRange(
          CivilDate(2026, 10, 1),
          CivilDate(2026, 10, 1),
        ),
      );
      expect(model.days, hasLength(1));
      expect(model.summary.workedMinutes, 480);
    });

    test('the days add up to the total of the summary', () {
      final model = octoberReport();
      final sum = model.days.fold(0, (s, d) => s + d.workedMinutes);
      expect(sum, model.summary.workedMinutes);
      // 3 Mañana (8 h) + 2 Noche (8 h) + Partido (4 + 4 h) = 48 h... the
      // Mañana of the 13th is the third one: 8 x 3 + 8 x 2 + 8.
      expect(model.summary.workedMinutes, 48 * 60);
    });
  });

  group('days', () {
    test('shifts keep their code, name, colour and times', () {
      final model = octoberReport();
      final first = _day(model, 1).shifts.single;
      expect(first.code, 'M');
      expect(first.name, 'Mañana');
      expect(first.colorValue, 0xFFF5A524);
      expect(first.startMinute, 360);
      expect(first.endMinute, 840);
      expect(first.hasTimes, isTrue);
    });

    test('a split shift knows both segments and ends with the second', () {
      final shift = _day(octoberReport(), 3).shifts.single;
      expect(shift.hasSegment2, isTrue);
      expect(shift.firstStart, 540);
      expect(shift.lastEnd, 1260);
    });

    test('two shifts on one day', () {
      expect(_day(octoberReport(), 13).shifts.map((s) => s.code), ['M', 'N']);
    });

    test('the holiday is marked with its name', () {
      final model = octoberReport();
      expect(_day(model, 12).holidayName, 'Fiesta Nacional de España');
      expect(_day(model, 12).isHoliday, isTrue);
      expect(_day(model, 11).isHoliday, isFalse);
      expect(model.holidays.single.date, const CivilDate(2026, 10, 12));
    });

    test('a holiday outside the range is not listed', () {
      final model = octoberReport(
        range: const SummaryRange(
          CivilDate(2026, 10, 1),
          CivilDate(2026, 10, 11),
        ),
      );
      expect(model.holidays, isEmpty);
    });

    test('an empty day is empty', () {
      expect(_day(octoberReport(), 20).isEmpty, isTrue);
    });
  });

  group('notes', () {
    test('are off by default', () {
      expect(octoberReport().notedDays, isEmpty);
    });

    test('are kept on request, except those of absence days', () {
      final model = octoberReport(
        options: const ReportOptions(includeNotes: true),
      );
      expect(model.notedDays.map((d) => d.date.day), [12]);
      expect(_day(model, 12).note, contains('urgente'));
      // Vacation and sick-leave notes stay out (could be about health).
      expect(_day(model, 5).note, isNull);
      expect(_day(model, 6).note, isNull);
    });

    test('control characters are removed, a blank note is none', () {
      final schedule = Schedule(
        shiftTypes: const [morning],
        entries: {
          const CivilDate(2026, 10, 1): const DayEntry(
            date: CivilDate(2026, 10, 1),
            shiftTypeIds: ['m'],
            note: '  hola\u0000\u0007\tmundo  ',
          ),
          const CivilDate(2026, 10, 2): const DayEntry(
            date: CivilDate(2026, 10, 2),
            shiftTypeIds: ['m'],
            note: '   ',
          ),
        },
      );
      final model = buildReport(
        schedule: schedule,
        range: const SummaryRange(
          CivilDate(2026, 10, 1),
          CivilDate(2026, 10, 2),
        ),
        calendarName: '',
        holidays: const {},
        today: const CivilDate(2026, 10, 1),
        options: const ReportOptions(includeNotes: true),
      );
      expect(model.days[0].note, 'hola mundo');
      expect(model.days[1].note, isNull);
    });
  });

  group('absences', () {
    test('by default they are a neutral «Ausencia» with no real name', () {
      final model = octoberReport();
      for (final d in [5, 6]) {
        final shift = _day(model, d).shifts.single;
        expect(shift.genericAbsence, isTrue);
        expect(shift.name, isEmpty);
        expect(shift.code, isEmpty);
        expect(shift.colorValue, reportNeutralAbsenceColor);
      }
      final everything = model.days
          .expand((d) => d.shifts)
          .map((s) => '${s.name}|${s.code}')
          .join(' ');
      expect(everything, isNot(contains('XQZ')));
      expect(everything, isNot(contains('Vacaciones')));
    });

    test('the legend has one «Ausencia» with the days of all absences', () {
      final legend = octoberReport().legend;
      final generic = legend.where((e) => e.shift.genericAbsence).single;
      expect(generic.days, 2);
      expect(legend.map((e) => e.shift.name), isNot(contains('Vacaciones')));
      expect(
        legend.map((e) => e.shift.name),
        isNot(contains(secretLeaveName)),
      );
    });

    test('two absences on one day are one «Ausencia»', () {
      final schedule = Schedule(
        shiftTypes: const [vacation, sickLeave],
        entries: {
          const CivilDate(2026, 10, 1): const DayEntry(
            date: CivilDate(2026, 10, 1),
            shiftTypeIds: ['v', 'b'],
          ),
        },
      );
      final model = buildReport(
        schedule: schedule,
        range: const SummaryRange(
          CivilDate(2026, 10, 1),
          CivilDate(2026, 10, 1),
        ),
        calendarName: 'x',
        holidays: const {},
        today: const CivilDate(2026, 10, 1),
      );
      expect(model.days.single.shifts, hasLength(1));
    });

    test('hidden: the days look empty and nothing counts or lists them', () {
      final model = octoberReport(
        options: const ReportOptions(
          absences: ReportAbsenceMode.hidden,
          includeNotes: true,
        ),
      );
      expect(_day(model, 5).shifts, isEmpty);
      expect(_day(model, 6).shifts, isEmpty);
      expect(_day(model, 6).note, isNull);
      expect(
        model.legend.where((e) => e.shift.category == ShiftCategory.absence),
        isEmpty,
      );
      expect(model.showsAbsences, isFalse);
    });

    test('detailed: the real type and its note, only on request', () {
      final model = octoberReport(
        options: const ReportOptions(
          absences: ReportAbsenceMode.detailed,
          includeNotes: true,
        ),
      );
      expect(_day(model, 6).shifts.single.name, secretLeaveName);
      expect(_day(model, 6).note, secretLeaveNote);
      expect(model.legend.map((e) => e.shift.name), contains(secretLeaveName));
      expect(model.showsAbsences, isTrue);
    });

    test('the hours do not depend on how absences are shown', () {
      final totals = {
        for (final mode in ReportAbsenceMode.values)
          octoberReport(
            options: ReportOptions(absences: mode),
          ).summary.workedMinutes,
      };
      expect(totals, {48 * 60});
    });
  });

  group('totals', () {
    test('hours split into worked and planned at today', () {
      expect(
        octoberReport(today: const CivilDate(2026, 11, 15)).hours.tense,
        PeriodTense.past,
      );
      final current = octoberReport(today: const CivilDate(2026, 10, 10)).hours;
      expect(current.tense, PeriodTense.current);
      expect(current.totalMinutes, 48 * 60);
      // Up to the 9th: Mañana, Noche and Partido (8 h each).
      expect(current.doneMinutes, 24 * 60);
      expect(
        octoberReport(today: const CivilDate(2026, 9, 1)).hours.tense,
        PeriodTense.future,
      );
    });

    test('earnings only when asked, with the rates of the shift types', () {
      expect(octoberReport().earningsCents, isNull);
      final model = octoberReport(
        options: const ReportOptions(includeEarnings: true),
      );
      // Only Mañana has a rate: 3 shifts x 8 h x 10,00.
      expect(model.earningsCents, 24000);
    });

    test('a calendar without shifts has an empty report', () {
      final model = buildReport(
        schedule: Schedule(),
        range: october,
        calendarName: '',
        holidays: const {},
        today: const CivilDate(2026, 10, 1),
      );
      expect(model.days, hasLength(31));
      expect(model.legend, isEmpty);
      expect(model.summary.workedMinutes, 0);
      expect(model.calendarName, isEmpty);
    });
  });
}
