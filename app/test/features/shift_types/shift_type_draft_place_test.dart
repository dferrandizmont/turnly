import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/features/shift_types/domain/shift_type_draft.dart';
import 'package:flutter_test/flutter_test.dart';

// The place and the pluses per hour of a shift type (P9, filas 16 and 25):
// the draft is what the form edits.

const _type = ShiftType(
  id: 'N',
  code: 'N',
  name: 'Noche',
  colorValue: 0xFF4B4FD1,
  category: ShiftCategory.work,
  startMinute: 1320,
  endMinute: 360,
);

void main() {
  group('the draft', () {
    test('carries the place and the pluses of the type it opens', () {
      final draft = ShiftTypeDraft.fromShiftType(
        _type.copyWith(
          location: 'UCI, planta 3',
          nightPlusCentsPerHour: 150,
          holidayPlusCentsPerHour: 200,
        ),
      );
      expect(draft.location, 'UCI, planta 3');
      expect(draft.place, 'UCI, planta 3');
      expect(draft.nightPlusCentsPerHour, 150);
      expect(draft.holidayPlusCentsPerHour, 200);
    });

    test('the form can set and clear them', () {
      final draft = ShiftTypeDraft.fromShiftType(_type);
      final edited = draft.copyWith(
        location: '  UCI  ',
        nightPlusCentsPerHour: 150,
        holidayPlusCentsPerHour: 200,
      );
      expect(edited.location, '  UCI  ');
      expect(edited.place, 'UCI');
      expect(edited.nightPlusCentsPerHour, 150);
      expect(edited.copyWith(clearLocation: true).location, isNull);
      expect(
        edited.copyWith(clearNightPlus: true).nightPlusCentsPerHour,
        isNull,
      );
      expect(
        edited.copyWith(clearHolidayPlus: true).holidayPlusCentsPerHour,
        isNull,
      );
    });

    test('a blank place is no place', () {
      final draft = ShiftTypeDraft.fromShiftType(_type)
          .copyWith(location: '  ');
      expect(draft.place, isNull);
      expect(draft.validate(), isEmpty);
      expect(draft.toShiftType('N').location, isNull);
    });

    test('the type it stands for has the place and the pluses', () {
      final type = ShiftTypeDraft.fromShiftType(_type)
          .copyWith(
            location: ' UCI, planta 3 ',
            nightPlusCentsPerHour: 150,
            holidayPlusCentsPerHour: 200,
          )
          .toShiftType('N');
      expect(type.location, 'UCI, planta 3');
      expect(type.nightPlusCentsPerHour, 150);
      expect(type.holidayPlusCentsPerHour, 200);
    });

    test('a place too long is a problem', () {
      final draft = ShiftTypeDraft.fromShiftType(_type)
          .copyWith(location: 'x' * (maxShiftLocationLength + 1));
      final problems = draft.validate();
      expect(
        problems[ShiftTypeField.location]?.issue,
        ShiftTypeIssue.locationTooLong,
      );
    });

    test('a plus out of range is a problem', () {
      final draft = ShiftTypeDraft.fromShiftType(_type)
          .copyWith(nightPlusCentsPerHour: maxStoredMoneyCents + 1);
      expect(
        draft.validate()[ShiftTypeField.nightPlus]?.issue,
        ShiftTypeIssue.nightPlusInvalid,
      );
      final other = ShiftTypeDraft.fromShiftType(_type)
          .copyWith(holidayPlusCentsPerHour: -1);
      expect(
        other.validate()[ShiftTypeField.holidayPlus]?.issue,
        ShiftTypeIssue.holidayPlusInvalid,
      );
    });

    test('a valid draft has no problems', () {
      final draft = ShiftTypeDraft.fromShiftType(
        _type.copyWith(
          location: 'UCI',
          nightPlusCentsPerHour: 150,
          holidayPlusCentsPerHour: 200,
        ),
      );
      expect(draft.validate(), isEmpty);
    });
  });
}
